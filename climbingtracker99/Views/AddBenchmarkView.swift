import SwiftUI
import SwiftData

struct AddPlannedBenchmarkView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let date: Date
    @State private var selectedBenchmarkTypes: Set<BenchmarkType> = []
    @State private var estimatedTime: Date = PlannedBenchmark.defaultTime
    @State private var notes: String = ""
    @State private var repeatWeekly: Bool = false
    @State private var numberOfWeeks: Int = 4
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Benchmark Details")) {
                    Text("Select Benchmarks to Test")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(BenchmarkType.allCases, id: \.self) { type in
                        Toggle(isOn: Binding(
                            get: { selectedBenchmarkTypes.contains(type) },
                            set: { isSelected in
                                if isSelected {
                                    selectedBenchmarkTypes.insert(type)
                                } else {
                                    selectedBenchmarkTypes.remove(type)
                                }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 12) {
                                    Image(systemName: type.iconName)
                                        .font(.title3)
                                        .foregroundColor(.orange)
                                    Text(type.displayName)
                                        .font(.body)
                                }
                                Text(type.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if !selectedBenchmarkTypes.isEmpty {
                        Divider()
                        
                        DatePicker("Estimated Time", selection: $estimatedTime, displayedComponents: .hourAndMinute)
                    }
                }
                
                Section(header: Text("Repeat")) {
                    Toggle("Repeat Every Week", isOn: $repeatWeekly)
                    
                    if repeatWeekly {
                        Stepper("For \(numberOfWeeks) weeks", value: $numberOfWeeks, in: 2...52)
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button("Save Benchmarks") {
                        saveBenchmarks()
                    }
                    .disabled(selectedBenchmarkTypes.isEmpty)
                }
            }
            .navigationTitle("Add Benchmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveBenchmarks() {
        guard !selectedBenchmarkTypes.isEmpty else { return }
        
        let calendar = Calendar.current
        let numberOfPlans = repeatWeekly ? numberOfWeeks : 1
        var createdBenchmarks: [PlannedBenchmark] = []
        
        for week in 0..<numberOfPlans {
            let planDate = calendar.date(byAdding: .weekOfYear, value: week, to: date) ?? date
            
            // Create a separate PlannedBenchmark for each selected benchmark type
            for benchmarkType in selectedBenchmarkTypes {
                let benchmark = PlannedBenchmark(
                    date: planDate,
                    benchmarkType: benchmarkType,
                    estimatedTime: estimatedTime,
                    notes: notes.isEmpty ? nil : notes
                )
                modelContext.insert(benchmark)
                createdBenchmarks.append(benchmark)
            }
        }
        
        Task {
            _ = await NotificationManager.shared.requestAuthorization()
            for benchmark in createdBenchmarks {
                NotificationManager.shared.scheduleBenchmarkNotification(for: benchmark)
            }
        }
        
        dismiss()
    }
}

