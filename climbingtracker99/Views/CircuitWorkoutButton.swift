import SwiftUI

struct CircuitWorkoutButton: View {
    @Binding var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    @State private var showingCircuitView = false
    
    var body: some View {
        Button {
            showingCircuitView = true
        } label: {
            HStack {
                Image(systemName: "timer")
                Text("Start Circuit Workout")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .fullScreenCover(isPresented: $showingCircuitView) {
            CircuitView(recordedExercise: $recordedExercise)
                .onDisappear {
                    // If workout was completed, mark as done
                    if recordedExercise.duration != nil && recordedExercise.duration! > 0 {
                        onComplete()
                    }
                }
        }
    }
}

