import SwiftUI
import SwiftData

struct BenchmarkView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Binding var recordedExercise: RecordedExercise
    
    @State private var selectedBenchmarks: Set<BenchmarkType> = []
    @State private var benchmarkResults: [BenchmarkType: (value1: Double, value2: Double?)] = [:]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Benchmarks to Test")) {
                    ForEach(BenchmarkType.allCases, id: \.self) { type in
                        Toggle(isOn: Binding(
                            get: { selectedBenchmarks.contains(type) },
                            set: { isSelected in
                                if isSelected {
                                    selectedBenchmarks.insert(type)
                                } else {
                                    selectedBenchmarks.remove(type)
                                    benchmarkResults.removeValue(forKey: type)
                                }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: type.iconName)
                                    Text(type.displayName)
                                }
                                Text(type.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                if !selectedBenchmarks.isEmpty {
                    Section(header: Text("Record Results")) {
                        ForEach(Array(selectedBenchmarks), id: \.self) { type in
                            BenchmarkResultInput(benchmarkType: type, result: Binding(
                                get: { benchmarkResults[type] ?? (0, nil) },
                                set: { benchmarkResults[type] = $0 }
                            ))
                        }
                    }
                    
                    Section {
                        Button("Save Benchmark Results") {
                            saveResults()
                        }
                        .disabled(!allResultsEntered)
                    }
                }
            }
            .navigationTitle("Benchmark Testing")
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
    
    private var allResultsEntered: Bool {
        for type in selectedBenchmarks {
            let result = benchmarkResults[type] ?? (0, nil)
            if result.value1 == 0 {
                return false
            }
            if type.requiresTwoHands && (result.value2 == nil || result.value2 == 0) {
                return false
            }
        }
        return !selectedBenchmarks.isEmpty
    }
    
    private func saveResults() {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withTime]
        
        var resultsArray: [[String: Any]] = []
        
        for type in selectedBenchmarks {
            if let result = benchmarkResults[type], result.value1 > 0 {
                var resultDict: [String: Any] = [
                    "benchmarkType": type.rawValue,
                    "value1": result.value1,
                    "date": dateFormatter.string(from: Date())
                ]
                
                if let value2 = result.value2 {
                    resultDict["value2"] = value2
                }
                
                resultsArray.append(resultDict)
                
                // Also save to PlannedBenchmark if there's a matching planned benchmark
                saveToPlannedBenchmark(type: type, value1: result.value1, value2: result.value2)
            }
        }
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: resultsArray),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            recordedExercise.benchmarkResultsData = jsonString
        }
        
        dismiss()
    }
    
    private func saveToPlannedBenchmark(type: BenchmarkType, value1: Double, value2: Double?) {
        // Find matching planned benchmarks for today that match this type
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        // Fetch benchmarks manually since predicate with enum comparison might be tricky
        let descriptor = FetchDescriptor<PlannedBenchmark>()
        
        guard let allBenchmarks = try? modelContext.fetch(descriptor) else { return }
        
        let matchingBenchmarks = allBenchmarks.filter { benchmark in
            benchmark.benchmarkType == type &&
            benchmark.date >= today &&
            benchmark.date < tomorrow
        }
        
        if !matchingBenchmarks.isEmpty {
            for benchmark in matchingBenchmarks where !benchmark.completed {
                benchmark.completed = true
                benchmark.resultValue1 = value1
                benchmark.resultValue2 = value2
                benchmark.completedDate = Date()
                benchmark.resultNotes = "Recorded via Benchmark Training"
            }
        } else {
            // Create a new PlannedBenchmark if no planned one exists
            let newBenchmark = PlannedBenchmark(
                date: Date(),
                benchmarkType: type,
                estimatedTime: Date(),
                notes: "Recorded via Benchmark Training"
            )
            newBenchmark.completed = true
            newBenchmark.resultValue1 = value1
            newBenchmark.resultValue2 = value2
            newBenchmark.completedDate = Date()
            newBenchmark.resultNotes = "Recorded via Benchmark Training"
            modelContext.insert(newBenchmark)
        }
        
        try? modelContext.save()
    }
}

struct BenchmarkResultInput: View {
    let benchmarkType: BenchmarkType
    @Binding var result: (value1: Double, value2: Double?)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(benchmarkType.displayName)
                .font(.headline)
            
            if benchmarkType.requiresTwoHands {
                // Two values for left/right hand
                VStack(alignment: .leading, spacing: 8) {
                    Text("Left Hand")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Stepper(
                        "\(String(format: "%.1f", result.value1)) kg",
                        value: Binding(
                            get: { result.value1 },
                            set: { result.value1 = $0; result.value2 = result.value2 }
                        ),
                        in: 0...200,
                        step: 0.5
                    )
                    
                    Text("Right Hand")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Stepper(
                        "\(String(format: "%.1f", result.value2 ?? 0)) kg",
                        value: Binding(
                            get: { result.value2 ?? 0 },
                            set: { result.value2 = $0 }
                        ),
                        in: 0...200,
                        step: 0.5
                    )
                }
            } else {
                // Single value input
                switch benchmarkType {
                case .maxPullups, .maxCampusMoves30mm:
                    // Integer values (reps/moves)
                    Stepper(
                        "\(Int(result.value1)) \(benchmarkType.unit)",
                        value: Binding(
                            get: { result.value1 },
                            set: { result.value1 = max(0, $0) }
                        ),
                        in: 0...1000,
                        step: 1
                    )
                    
                case .maxPullupWith3Reps, .maxGripHang30mm:
                    // Weight in kg
                    Stepper(
                        "\(String(format: "%.1f", result.value1)) \(benchmarkType.unit)",
                        value: Binding(
                            get: { result.value1 },
                            set: { result.value1 = $0; result.value2 = nil }
                        ),
                        in: 0...200,
                        step: 0.5
                    )
                    
                case .maxLockoff1HandLeft, .maxLockoff1HandRight, .maxLockoff2Hands,
                     .maxHangTime10mm, .maxHangTime15mm, .maxHangTime20mm, .maxHangTime30mm,
                     .maxRepeaters10mm, .maxRepeaters15mm, .maxRepeaters20mm:
                    // Time in seconds
                    HStack {
                        Text("Time")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        TextField("Seconds", value: Binding(
                            get: { result.value1 },
                            set: { result.value1 = max(0, $0); result.value2 = nil }
                        ), format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 100)
                        Text("seconds")
                            .foregroundColor(.secondary)
                    }
                    
                case .maxEdgePull20mm:
                    // Already handled by requiresTwoHands
                    EmptyView()
                }
            }
        }
        .padding(.vertical, 4)
    }
}

