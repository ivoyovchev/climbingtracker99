import SwiftUI
import AudioToolbox

enum CircuitMode {
    case freeClimbing
    case timeBased
}

struct CircuitInterval: Identifiable {
    var climbTime: TimeInterval // in seconds
    var restTime: TimeInterval // in seconds
    var id = UUID()
}

struct CircuitView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var recordedExercise: RecordedExercise
    
    @State private var mode: CircuitMode = .freeClimbing
    @State private var isActive = false
    
    // Free Climbing Mode
    @State private var numberOfSets: Int = 3
    @State private var difficulty: String = "5.10"
    @State private var movesPerSet: Int = 10
    @State private var restTime: Int = 60 // seconds
    @State private var currentSet: Int = 0
    @State private var isInRest = false
    @State private var isInCountdown = false
    @State private var timeRemaining: TimeInterval = 15
    @State private var movesCompleted: Int = 0
    
    // Time Based Mode
    @State private var intervals: [CircuitInterval] = [
        CircuitInterval(climbTime: 30, restTime: 10),
        CircuitInterval(climbTime: 45, restTime: 15),
        CircuitInterval(climbTime: 60, restTime: 30),
        CircuitInterval(climbTime: 120, restTime: 60)
    ]
    @State private var currentIntervalIndex: Int = 0
    @State private var isInClimbPhase = true
    @State private var intervalTimeRemaining: TimeInterval = 30
    
    // Timer
    @State private var timer: Timer?
    @State private var startTime: Date?
    @State private var totalDuration: TimeInterval = 0
    
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !isActive {
                    // Setup Phase
                    setupView
                } else {
                    // Active Workout Phase
                    activeWorkoutView
                }
            }
            .navigationTitle("Circuit Training")
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
                }
            }
        }
    }
    
    // MARK: - Setup View
    
    private var setupView: some View {
        Form {
            Section("Mode") {
                Picker("Mode", selection: $mode) {
                    Text("Free Climbing").tag(CircuitMode.freeClimbing)
                    Text("Time Based").tag(CircuitMode.timeBased)
                }
                .pickerStyle(.segmented)
            }
            
            if mode == .freeClimbing {
                freeClimbingSetup
            } else {
                timeBasedSetup
            }
        }
    }
    
    private var freeClimbingSetup: some View {
        Group {
            Section("Workout Settings") {
                Stepper("Number of Sets: \(numberOfSets)", value: $numberOfSets, in: 1...20)
                
                HStack {
                    Text("Route Difficulty")
                    Spacer()
                    TextField("5.10", text: $difficulty)
                        .keyboardType(.default)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                
                Stepper("Moves per Set: \(movesPerSet)", value: $movesPerSet, in: 1...50)
                
                Stepper("Rest Time: \(restTime)s", value: $restTime, in: 10...300, step: 5)
            }
        }
    }
    
    private var timeBasedSetup: some View {
        Group {
            Section("Intervals") {
                ForEach(intervals.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Interval \(index + 1)")
                                .font(.headline)
                            Spacer()
                            Button {
                                intervals.remove(at: index)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                        
                        HStack {
                            Text("Climb")
                            Spacer()
                            Stepper("\(Int(intervals[index].climbTime))s", value: Binding(
                                get: { intervals[index].climbTime },
                                set: { newValue in
                                    intervals[index].climbTime = newValue
                                }
                            ), in: 5...300, step: 5)
                        }
                        
                        HStack {
                            Text("Rest")
                            Spacer()
                            Stepper("\(Int(intervals[index].restTime))s", value: Binding(
                                get: { intervals[index].restTime },
                                set: { newValue in
                                    intervals[index].restTime = newValue
                                }
                            ), in: 5...300, step: 5)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Button {
                    intervals.append(CircuitInterval(climbTime: 30, restTime: 10))
                } label: {
                    Label("Add Interval", systemImage: "plus.circle")
                }
            }
        }
    }
    
    // MARK: - Active Workout View
    
    private var activeWorkoutView: some View {
        VStack(spacing: 30) {
            if mode == .freeClimbing {
                freeClimbingWorkout
            } else {
                timeBasedWorkout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var freeClimbingWorkout: some View {
        VStack(spacing: 30) {
            // Set counter
            Text("Set \(currentSet + 1) of \(numberOfSets)")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Main timer/countdown
            VStack(spacing: 10) {
                if isInCountdown {
                    Text("Get Ready")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Text("\(Int(timeRemaining))")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    
                    Text("START CLIMBING")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .padding(.top)
                } else if isInRest {
                    Text("Rest")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Text(formatTime(timeRemaining))
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    
                    Text("Next set starts automatically")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    // Active climbing
                    Text("Climbing")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text("Moves: \(movesCompleted)/\(movesPerSet)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    
                    // Move counter buttons
                    HStack(spacing: 20) {
                        Button {
                            if movesCompleted > 0 {
                                movesCompleted -= 1
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.red)
                        }
                        .disabled(movesCompleted == 0)
                        
                        Button {
                            if movesCompleted < movesPerSet {
                                movesCompleted += 1
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.green)
                        }
                        .disabled(movesCompleted >= movesPerSet)
                    }
                    .padding()
                    
                    Text(formatTime(totalDuration))
                        .font(.title)
                        .foregroundColor(.secondary)
                    
                    Button {
                        completeSet()
                    } label: {
                        Text("Set Done")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal)
                }
            }
            
            // Difficulty display
            Text("Difficulty: \(difficulty)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var timeBasedWorkout: some View {
        VStack(spacing: 30) {
            // Interval counter
            Text("Interval \(currentIntervalIndex + 1) of \(intervals.count)")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Phase indicator
            VStack(spacing: 10) {
                Text(isInClimbPhase ? "CLIMB" : "REST")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(isInClimbPhase ? .green : .blue)
                
                Text(formatTime(intervalTimeRemaining))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(isInClimbPhase ? .green : .blue)
                
                Text(isInClimbPhase ? "Climbing Phase" : "Rest Phase")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // Progress indicator
            ProgressView(value: 1.0 - (intervalTimeRemaining / (isInClimbPhase ? intervals[currentIntervalIndex].climbTime : intervals[currentIntervalIndex].restTime)))
                .progressViewStyle(LinearProgressViewStyle())
                .frame(height: 8)
                .padding(.horizontal)
            
            // Total time
            Text("Total Time: \(formatTime(totalDuration))")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - Functions
    
    private func startWorkout() {
        guard !intervals.isEmpty || mode == .freeClimbing else { return }
        
        isActive = true
        startTime = Date()
        totalDuration = 0
        
        if mode == .freeClimbing {
            currentSet = 0
            movesCompleted = 0
            startCountdown()
        } else {
            currentIntervalIndex = 0
            isInClimbPhase = true
            intervalTimeRemaining = intervals[0].climbTime
            startIntervalTimer()
        }
        
        startTotalTimer()
    }
    
    private func startCountdown() {
        isInCountdown = true
        timeRemaining = 15
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            timeRemaining -= 1
            
            if timeRemaining <= 0 {
                timer?.invalidate()
                playSound()
                startClimbing()
            } else if timeRemaining <= 3 {
                playSound()
            }
        }
    }
    
    private func startClimbing() {
        isInCountdown = false
        isInRest = false
        movesCompleted = 0
        startTotalTimer()
    }
    
    private func completeSet() {
        currentSet += 1
        
        // Save moves for this set
        if recordedExercise.sets == nil {
            recordedExercise.sets = movesCompleted
        } else {
            recordedExercise.sets! += movesCompleted
        }
        
        if currentSet >= numberOfSets {
            finishWorkout()
        } else {
            startRest()
        }
    }
    
    private func startRest() {
        isInRest = true
        timeRemaining = TimeInterval(restTime)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            timeRemaining -= 1
            
            if timeRemaining <= 0 {
                timer?.invalidate()
                playSound()
                startCountdown()
            } else if timeRemaining <= 3 {
                playSound()
            }
        }
    }
    
    private func startIntervalTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            intervalTimeRemaining -= 0.1
            
            if intervalTimeRemaining <= 0 {
                // Phase complete, switch to next phase
                playSound()
                
                if isInClimbPhase {
                    // Move to rest phase
                    isInClimbPhase = false
                    intervalTimeRemaining = intervals[currentIntervalIndex].restTime
                } else {
                    // Rest complete, move to next interval
                    currentIntervalIndex += 1
                    
                    if currentIntervalIndex >= intervals.count {
                        finishWorkout()
                    } else {
                        isInClimbPhase = true
                        intervalTimeRemaining = intervals[currentIntervalIndex].climbTime
                    }
                }
            } else if intervalTimeRemaining <= 3 && intervalTimeRemaining.truncatingRemainder(dividingBy: 1.0) < 0.1 {
                // Play sound for last 3 seconds
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
        
        // Save workout data to recordedExercise
        recordedExercise.duration = Int(totalDuration)
        
        if mode == .freeClimbing {
            recordedExercise.grade = difficulty
            recordedExercise.hours = Int(totalDuration) / 3600
            recordedExercise.minutes = (Int(totalDuration) % 3600) / 60
            // Sets already saved incrementally in completeSet()
            recordedExercise.updateNotes("Circuit: \(numberOfSets) sets × \(movesPerSet) moves on \(difficulty)")
        } else {
            let intervalSummary = intervals.map { "\(Int($0.climbTime))s climb / \(Int($0.restTime))s rest" }.joined(separator: ", ")
            recordedExercise.updateNotes("Time Based Circuit: \(intervals.count) intervals - \(intervalSummary)")
        }
        
        dismiss()
    }
    
    private func stopWorkout() {
        timer?.invalidate()
        timer = nil
        isActive = false
    }
    
    private func playSound() {
        // System sound for feedback
        AudioServicesPlaySystemSound(1016) // System sound
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

