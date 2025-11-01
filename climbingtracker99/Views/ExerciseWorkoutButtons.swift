import SwiftUI

// MARK: - Workout Button Wrappers for Full-Screen Timers

struct FlexibilityWorkoutButton: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    @State private var showingTimerView = false
    
    var body: some View {
        Button {
            showingTimerView = true
        } label: {
            HStack {
                Image(systemName: "timer")
                Text("Start Flexibility")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .fullScreenCover(isPresented: $showingTimerView) {
            FlexibilityTimerViewWrapper(recordedExercise: recordedExercise, onComplete: onComplete, isPresented: $showingTimerView)
        }
    }
}

struct PullupsWorkoutButton: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    @State private var showingTimerView = false
    
    var body: some View {
        Button {
            showingTimerView = true
        } label: {
            HStack {
                Image(systemName: "timer")
                Text("Start Pull-ups")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .fullScreenCover(isPresented: $showingTimerView) {
            PullupsTimerViewWrapper(recordedExercise: recordedExercise, onComplete: onComplete, isPresented: $showingTimerView)
        }
    }
}

struct NxNWorkoutButton: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    @State private var showingTimerView = false
    
    var body: some View {
        Button {
            showingTimerView = true
        } label: {
            HStack {
                Image(systemName: "timer")
                Text("Start NxN")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .fullScreenCover(isPresented: $showingTimerView) {
            NxNTimerViewWrapper(recordedExercise: recordedExercise, onComplete: onComplete, isPresented: $showingTimerView)
        }
    }
}

struct BoardClimbingWorkoutButton: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    @State private var showingTimerView = false
    
    var body: some View {
        Button {
            showingTimerView = true
        } label: {
            HStack {
                Image(systemName: "timer")
                Text("Start Board Climbing")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .fullScreenCover(isPresented: $showingTimerView) {
            BoardClimbingTimerViewWrapper(recordedExercise: recordedExercise, onComplete: onComplete, isPresented: $showingTimerView)
        }
    }
}

struct ShoulderLiftsWorkoutButton: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    @State private var showingTimerView = false
    
    var body: some View {
        Button {
            showingTimerView = true
        } label: {
            HStack {
                Image(systemName: "timer")
                Text("Start Shoulder Lifts")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.cyan)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .fullScreenCover(isPresented: $showingTimerView) {
            ShoulderLiftsTimerViewWrapper(recordedExercise: recordedExercise, onComplete: onComplete, isPresented: $showingTimerView)
        }
    }
}

struct RepeatersWorkoutButton: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    @State private var showingTimerView = false
    
    var body: some View {
        Button {
            showingTimerView = true
        } label: {
            HStack {
                Image(systemName: "timer")
                Text("Start Repeaters")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.indigo)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .fullScreenCover(isPresented: $showingTimerView) {
            RepeatersTimerViewWrapper(recordedExercise: recordedExercise, onComplete: onComplete, isPresented: $showingTimerView)
        }
    }
}

struct EdgePickupsWorkoutButton: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    @State private var showingTimerView = false
    
    var body: some View {
        Button {
            showingTimerView = true
        } label: {
            HStack {
                Image(systemName: "timer")
                Text("Start Edge Pickups")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.teal)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .fullScreenCover(isPresented: $showingTimerView) {
            EdgePickupsTimerViewWrapper(recordedExercise: recordedExercise, onComplete: onComplete, isPresented: $showingTimerView)
        }
    }
}

struct LimitBoulderingWorkoutButton: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    @State private var showingTimerView = false
    
    var body: some View {
        Button {
            showingTimerView = true
        } label: {
            HStack {
                Image(systemName: "timer")
                Text("Start Limit Bouldering")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.pink)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .fullScreenCover(isPresented: $showingTimerView) {
            LimitBoulderingTimerViewWrapper(recordedExercise: recordedExercise, onComplete: onComplete, isPresented: $showingTimerView)
        }
    }
}

struct MaxHangsWorkoutButton: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    @State private var showingTimerView = false
    
    var body: some View {
        Button {
            showingTimerView = true
        } label: {
            HStack {
                Image(systemName: "timer")
                Text("Start Max Hangs")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.yellow)
            .foregroundColor(.black)
            .cornerRadius(12)
        }
        .fullScreenCover(isPresented: $showingTimerView) {
            MaxHangsTimerViewWrapper(recordedExercise: recordedExercise, onComplete: onComplete, isPresented: $showingTimerView)
        }
    }
}

struct BoulderCampusWorkoutButton: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    @State private var showingTimerView = false
    
    var body: some View {
        Button {
            showingTimerView = true
        } label: {
            HStack {
                Image(systemName: "timer")
                Text("Start Boulder Campus")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.mint)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .fullScreenCover(isPresented: $showingTimerView) {
            BoulderCampusTimerViewWrapper(recordedExercise: recordedExercise, onComplete: onComplete, isPresented: $showingTimerView)
        }
    }
}

struct DeadliftsWorkoutButton: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    @State private var showingTimerView = false
    
    var body: some View {
        Button {
            showingTimerView = true
        } label: {
            HStack {
                Image(systemName: "timer")
                Text("Start Deadlifts")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.brown)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .fullScreenCover(isPresented: $showingTimerView) {
            DeadliftsTimerViewWrapper(recordedExercise: recordedExercise, onComplete: onComplete, isPresented: $showingTimerView)
        }
    }
}

// MARK: - Wrapper Views to Bridge ObservedObject to Binding

struct FlexibilityTimerViewWrapper: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            FlexibilityTimerView(recordedExercise: recordedExercise, onComplete: {
                isPresented = false
                onComplete()
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct PullupsTimerViewWrapper: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            PullupsTimerView(recordedExercise: recordedExercise, onComplete: {
                isPresented = false
                onComplete()
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct NxNTimerViewWrapper: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            NxNTimerView(recordedExercise: recordedExercise, onComplete: {
                isPresented = false
                onComplete()
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct BoardClimbingTimerViewWrapper: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            BoardClimbingTimerView(recordedExercise: recordedExercise, onComplete: {
                isPresented = false
                onComplete()
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct ShoulderLiftsTimerViewWrapper: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ShoulderLiftsTimerView(recordedExercise: recordedExercise, onComplete: {
                isPresented = false
                onComplete()
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct RepeatersTimerViewWrapper: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            RepeatersTimerView(recordedExercise: recordedExercise, onComplete: {
                isPresented = false
                onComplete()
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct EdgePickupsTimerViewWrapper: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            EdgePickupsTimerView(recordedExercise: recordedExercise, onComplete: {
                isPresented = false
                onComplete()
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct LimitBoulderingTimerViewWrapper: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            LimitBoulderingTimerView(recordedExercise: recordedExercise, onComplete: {
                isPresented = false
                onComplete()
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct MaxHangsTimerViewWrapper: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            MaxHangsTimerView(recordedExercise: recordedExercise, onComplete: {
                isPresented = false
                onComplete()
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct BoulderCampusTimerViewWrapper: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            BoulderCampusTimerView(recordedExercise: recordedExercise, onComplete: {
                isPresented = false
                onComplete()
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct DeadliftsTimerViewWrapper: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            DeadliftsTimerView(recordedExercise: recordedExercise, onComplete: {
                isPresented = false
                onComplete()
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

