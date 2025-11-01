import SwiftUI

struct BenchmarkWorkoutButton: View {
    @Binding var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    @State private var showingBenchmarkView = false
    
    var body: some View {
        Button {
            showingBenchmarkView = true
        } label: {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("Start Benchmark Testing")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .fullScreenCover(isPresented: $showingBenchmarkView) {
            BenchmarkView(recordedExercise: $recordedExercise)
                .onDisappear {
                    // If benchmarks were recorded, mark as done
                    if !recordedExercise.benchmarkResultsData.isEmpty {
                        onComplete()
                    }
                }
        }
    }
}

