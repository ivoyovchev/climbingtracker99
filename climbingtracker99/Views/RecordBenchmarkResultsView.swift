import SwiftUI
import SwiftData

struct RecordBenchmarkResultsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let benchmark: PlannedBenchmark
    
    @State private var resultValue1: Double = 0.0
    @State private var resultValue2: Double = 0.0
    @State private var resultNotes: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Benchmark: \(benchmark.benchmarkType.displayName)")) {
                    Text(benchmark.benchmarkType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Results")) {
                    if benchmark.benchmarkType.requiresTwoHands {
                        // For Max Edge Pull 20mm - needs left and right hand
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Left Hand")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Stepper(
                                "\(String(format: "%.1f", resultValue1)) kg",
                                value: $resultValue1,
                                in: 0...200,
                                step: 0.5
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Right Hand")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Stepper(
                                "\(String(format: "%.1f", resultValue2)) kg",
                                value: $resultValue2,
                                in: 0...200,
                                step: 0.5
                            )
                        }
                    } else {
                        // Single value input
                        switch benchmark.benchmarkType {
                        case .maxPullups, .maxCampusMoves30mm:
                            // Integer values (reps/moves)
                            Stepper(
                                "\(Int(resultValue1)) \(benchmark.benchmarkType.unit)",
                                value: Binding(
                                    get: { resultValue1 },
                                    set: { resultValue1 = max(0, $0) }
                                ),
                                in: 0...1000,
                                step: 1
                            )
                            
                        case .maxPullupWith3Reps, .maxGripHang30mm, .maxEdgePull20mm:
                            // Weight in kg
                            Stepper(
                                "\(String(format: "%.1f", resultValue1)) \(benchmark.benchmarkType.unit)",
                                value: $resultValue1,
                                in: 0...200,
                                step: 0.5
                            )
                            
                        case .maxLockoff1HandLeft, .maxLockoff1HandRight, .maxLockoff2Hands,
                             .maxHangTime10mm, .maxHangTime15mm, .maxHangTime20mm, .maxHangTime30mm,
                             .maxRepeaters10mm, .maxRepeaters15mm, .maxRepeaters20mm:
                            // Time in seconds
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Time")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                HStack {
                                    TextField("Seconds", value: $resultValue1, format: .number)
                                        .keyboardType(.decimalPad)
                                    Text("seconds")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextField("Optional notes about this benchmark", text: $resultNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button("Save Results") {
                        saveResults()
                    }
                    .disabled(resultValue1 == 0 && resultValue2 == 0)
                }
            }
            .navigationTitle("Record Results")
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
    
    private func saveResults() {
        benchmark.completed = true
        benchmark.resultValue1 = resultValue1
        if benchmark.benchmarkType.requiresTwoHands || resultValue2 > 0 {
            benchmark.resultValue2 = resultValue2 > 0 ? resultValue2 : nil
        }
        benchmark.resultNotes = resultNotes.isEmpty ? nil : resultNotes
        benchmark.completedDate = Date()
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save benchmark results: \(error)")
        }
    }
}

