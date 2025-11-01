import SwiftUI

struct CampusingWorkoutButton: View {
    @Binding var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    @State private var showingCampusingView = false
    
    var body: some View {
        Button {
            showingCampusingView = true
        } label: {
            HStack {
                Image(systemName: "timer")
                Text("Start Campusing")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .fullScreenCover(isPresented: $showingCampusingView) {
            CampusingView(recordedExercise: $recordedExercise)
                .onDisappear {
                    // If workout was completed, mark as done
                    if recordedExercise.duration != nil && recordedExercise.duration! > 0 {
                        onComplete()
                    }
                }
        }
    }
}

