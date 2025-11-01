import SwiftUI
import AudioToolbox

struct CoreView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var recordedExercise: RecordedExercise
    
    @State private var numberOfSets: Int = 3
    @State private var trainingTime: Int = 45 // seconds
    @State private var restTime: Int = 30 // seconds
    @State private var isActive = false
    @State private var currentSet: Int = 0
    @State private var isInTraining = false
    @State private var isInRest = false
    @State private var timeRemaining: TimeInterval = 45
    @State private var timer: Timer?
    @State private var startTime: Date?
    @State private var totalDuration: TimeInterval = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !isActive {
                    // Setup Phase
                    Form {
                        Section("Workout Settings") {
                            Stepper("Number of Sets: \(numberOfSets)", value: $numberOfSets, in: 1...20)
                            Stepper("Training Time: \(trainingTime)s", value: $trainingTime, in: 10...300, step: 5)
                            Stepper("Rest Time: \(restTime)s", value: $restTime, in: 10...300, step: 5)
                        }
                    }
                } else {
                    // Active Workout Phase
                    activeWorkoutView
                }
            }
            .navigationTitle("Core Training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        stopWorkout()
                        dismiss()
                    }
                }
                
                if !isActive {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Start") {
                            startWorkout()
                        }
                        .fontWeight(.semibold)
                    }
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Stop") {
                            stopWorkout()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Active Workout View
    
    private var activeWorkoutView: some View {
        VStack(spacing: 40) {
            // Set counter
            Text("Set \(currentSet + 1) of \(numberOfSets)")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Main timer display
            VStack(spacing: 20) {
                if isInTraining {
                    Text("TRAINING")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    
                    Text(formatTime(timeRemaining))
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    
                    Text("Keep going!")
                        .font(.title3)
                        .foregroundColor(.secondary)
                } else if isInRest {
                    Text("REST")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    
                    Text(formatTime(timeRemaining))
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    
                    Text("Next set starts automatically")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress indicator
            if numberOfSets > 1 {
                ProgressView(value: Double(currentSet), total: Double(numberOfSets))
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 8)
                    .padding(.horizontal, 40)
            }
            
            // Total time
            Text("Total Time: \(formatTime(totalDuration))")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Functions
    
    private func startWorkout() {
        isActive = true
        currentSet = 0
        startTime = Date()
        totalDuration = 0
        startTrainingPhase()
        startTotalTimer()
    }
    
    private func startTrainingPhase() {
        isInTraining = true
        isInRest = false
        timeRemaining = TimeInterval(trainingTime)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            timeRemaining -= 1
            
            if timeRemaining <= 0 {
                timer?.invalidate()
                playSound()
                // Training phase complete, move to rest
                if currentSet < numberOfSets - 1 {
                    startRestPhase()
                } else {
                    finishWorkout()
                }
            } else if timeRemaining <= 3 {
                playSound()
            }
        }
    }
    
    private func startRestPhase() {
        isInTraining = false
        isInRest = true
        timeRemaining = TimeInterval(restTime)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            timeRemaining -= 1
            
            if timeRemaining <= 0 {
                timer?.invalidate()
                playSound()
                // Rest complete, move to next set
                currentSet += 1
                startTrainingPhase()
            } else if timeRemaining <= 3 {
                playSound()
            }
        }
    }
    
    private func startTotalTimer() {
        // Total duration timer (runs separately)
        let totalTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let start = startTime {
                totalDuration = Date().timeIntervalSince(start)
            }
        }
        RunLoop.main.add(totalTimer, forMode: .common)
    }
    
    private func finishWorkout() {
        stopWorkout()
        
        // Save workout data
        recordedExercise.duration = Int(totalDuration)
        recordedExercise.sets = numberOfSets
        recordedExercise.restDuration = restTime
        // Store training time per set in a way that can be retrieved
        // We'll use notes to store the full details
        recordedExercise.updateNotes("Core: \(numberOfSets) sets × \(trainingTime)s work / \(restTime)s rest")
        
        dismiss()
    }
    
    private func stopWorkout() {
        timer?.invalidate()
        timer = nil
        isActive = false
        isInTraining = false
        isInRest = false
    }
    
    private func playSound() {
        AudioServicesPlaySystemSound(1016) // System sound
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

