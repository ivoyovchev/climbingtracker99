import SwiftUI

struct CoreWorkoutButton: View {
    @Binding var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    @State private var showingCoreView = false
    
    var body: some View {
        Button {
            showingCoreView = true
        } label: {
            HStack {
                Image(systemName: "timer")
                Text("Start Core Workout")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .fullScreenCover(isPresented: $showingCoreView) {
            CoreView(recordedExercise: $recordedExercise)
                .onDisappear {
                    // If workout was completed, mark as done
                    if recordedExercise.duration != nil && recordedExercise.duration! > 0 {
                        onComplete()
                    }
                }
        }
    }
}

