//
//  RecordTrainingView.swift
//  climbingtracker99
//
//  Live training recording view with timers
//

import SwiftUI
import SwiftData
import AudioToolbox

struct RecordTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [Exercise]
    
    @State private var location: TrainingLocation = .indoor
    @State private var focus: TrainingFocus = .strength
    @State private var recordingStartTime: Date = Date()
    @State private var activeExercises: [RecordedExercise] = []
    @State private var completedExercises: [RecordedExercise] = []
    @State private var selectedExercise: Exercise?
    @State private var showingExerciseSelection = false
    @State private var notes: String = ""
    @State private var timer: Timer?
    @State private var currentTime = Date()
    @State private var showingCancelConfirmation = false
    
    private var availableExercises: [Exercise] {
        let activeExerciseModelIds = activeExercises.map { $0.exercise.persistentModelID }
        let filtered = exercises.filter { !activeExerciseModelIds.contains($0.persistentModelID) }
        // Remove duplicates by exercise type - only keep first occurrence of each type
        var seenTypes: Set<ExerciseType> = []
        return filtered.filter { exercise in
            if seenTypes.contains(exercise.type) {
                return false
            } else {
                seenTypes.insert(exercise.type)
                return true
            }
        }
    }
    
    private var totalElapsedTime: TimeInterval {
        currentTime.timeIntervalSince(recordingStartTime)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with workout timer and action buttons
                VStack(spacing: 12) {
                    // Main timer - centered and prominent
                    VStack(spacing: 4) {
                        Text("Recording Workout")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(formatTime(totalElapsedTime))
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    
                    // Top action buttons
                    HStack(spacing: 20) {
                        // Location and Focus pickers
                        HStack(spacing: 12) {
                            Picker("", selection: $location) {
                                ForEach(TrainingLocation.allCases, id: \.self) { loc in
                                    Text(loc.rawValue).tag(loc)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 100)
                            
                            Picker("", selection: $focus) {
                                ForEach(TrainingFocus.allCases, id: \.self) { f in
                                    Text(f.rawValue).tag(f)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 100)
                        }
                        
                        Spacer()
                        
                        // Add Exercise button
                        Button(action: { showingExerciseSelection = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(availableExercises.isEmpty ? .gray : .blue)
                        }
                        .disabled(availableExercises.isEmpty)
                        
                        // Complete Workout button
                        if !activeExercises.isEmpty || !completedExercises.isEmpty {
                            Button(action: completeWorkout) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .background(Color(.systemBackground))
                
                Divider()
                
                // Active exercises (currently recording)
                if !activeExercises.isEmpty {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(activeExercises) { recordedExercise in
                                ExerciseRecordingCard(
                                    recordedExercise: recordedExercise,
                                    onComplete: {
                                        completeExercise(recordedExercise)
                                    },
                                    onRemove: {
                                        removeActiveExercise(recordedExercise)
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
                
                // Completed exercises - compact and collapsible
                if !completedExercises.isEmpty {
                    Divider()
                    
                    DisclosureGroup {
                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(completedExercises) { recordedExercise in
                                    CompletedExerciseRow(recordedExercise: recordedExercise)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(maxHeight: 150)
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Completed (\(completedExercises.count))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .padding(.vertical, 4)
                }
                
                // Empty state message
                if activeExercises.isEmpty && completedExercises.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "figure.climbing")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No exercises started")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Tap the + button to add an exercise")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .navigationTitle("Record Training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // Only show confirmation if there's active recording
                        if !activeExercises.isEmpty || !completedExercises.isEmpty {
                            showingCancelConfirmation = true
                        } else {
                            dismiss()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
            }
            .alert("Cancel Recording?", isPresented: $showingCancelConfirmation) {
                Button("Cancel Recording", role: .destructive) {
                    dismiss()
                }
                Button("Continue Recording", role: .cancel) { }
            } message: {
                Text("Are you sure you want to cancel this recording? All progress will be lost.")
            }
            .sheet(isPresented: $showingExerciseSelection) {
                ExerciseSelectionSheet(
                    exercises: availableExercises,
                    onSelect: { exercise in
                        addExercise(exercise)
                        showingExerciseSelection = false
                    }
                )
            }
        }
        .onAppear {
            recordingStartTime = Date()
            currentTime = Date()
            // Start timer to update continuously
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                currentTime = Date()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func addExercise(_ exercise: Exercise) {
        let recordedExercise = RecordedExercise(exercise: exercise)
        // Copy default values from exercise
        recordedExercise.gripType = exercise.gripType
        recordedExercise.duration = exercise.duration
        recordedExercise.repetitions = exercise.repetitions
        recordedExercise.sets = exercise.sets
        recordedExercise.restDuration = exercise.restDuration
        recordedExercise.addedWeight = Int(exercise.addedWeight ?? 0)
        recordedExercise.weight = Int(exercise.weight ?? 0)
        recordedExercise.grade = exercise.grade
        recordedExercise.gradeTried = exercise.gradeTried
        recordedExercise.routes = exercise.routes
        recordedExercise.attempts = exercise.attempts
        recordedExercise.restBetweenRoutes = exercise.restBetweenRoutes
        recordedExercise.sessionDuration = exercise.sessionDuration
        recordedExercise.moves = exercise.moves
        recordedExercise.boardType = exercise.boardType
        recordedExercise.edgeSize = exercise.edgeSize
        recordedExercise.hamstrings = exercise.hamstrings
        recordedExercise.hips = exercise.hips
        recordedExercise.forearms = exercise.forearms
        recordedExercise.legs = exercise.legs
        
        activeExercises.append(recordedExercise)
    }
    
    private func completeExercise(_ recordedExercise: RecordedExercise) {
        if let index = activeExercises.firstIndex(where: { $0.id == recordedExercise.id }) {
            activeExercises[index].isCompleted = true
            if let endTime = activeExercises[index].recordedEndTime,
               let startTime = activeExercises[index].recordedStartTime {
                let duration = Int(endTime.timeIntervalSince(startTime)) - activeExercises[index].pausedDuration
                activeExercises[index].recordedDuration = max(0, duration)
            }
            
            let completed = activeExercises.remove(at: index)
            completedExercises.append(completed)
        }
    }
    
    private func removeActiveExercise(_ recordedExercise: RecordedExercise) {
        activeExercises.removeAll { $0.id == recordedExercise.id }
    }
    
    private func completeWorkout() {
        // Complete any remaining active exercises
        for exercise in activeExercises {
            exercise.isCompleted = true
            if let endTime = exercise.recordedEndTime,
               let startTime = exercise.recordedStartTime {
                let duration = Int(endTime.timeIntervalSince(startTime)) - exercise.pausedDuration
                exercise.recordedDuration = max(0, duration)
            }
            completedExercises.append(exercise)
        }
        activeExercises.removeAll()
        
        // Create training session
        let training = Training(
            date: recordingStartTime,
            duration: Int(totalElapsedTime / 60),
            location: location,
            focus: focus,
            recordedExercises: completedExercises,
            notes: notes,
            media: [],
            isRecorded: true,
            recordingStartTime: recordingStartTime
        )
        training.recordingEndTime = Date()
        training.totalRecordedDuration = Int(totalElapsedTime)
        
        modelContext.insert(training)
        
        // Insert all recorded exercises
        for exercise in completedExercises {
            modelContext.insert(exercise)
        }
        
        dismiss()
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

struct ExerciseSelectionSheet: View {
    let exercises: [Exercise]
    let onSelect: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(exercises) { exercise in
                        Button(action: {
                            onSelect(exercise)
                        }) {
                            VStack(spacing: 8) {
                                Image(exercise.type.imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                Text(exercise.type.rawValue)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(radius: 2)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ExerciseRecordingCard: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    let onRemove: () -> Void
    
    @State private var timer: Timer?
    @State private var elapsedTime: TimeInterval = 0
    @State private var isRunning: Bool = false
    @State private var isPaused: Bool = false
    @State private var pausedStartTime: Date?
    @State private var showingDetails = false
    
    private var exercise: Exercise {
        recordedExercise.exercise
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(exercise.type.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 45)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.type.rawValue)
                        .font(.headline)
                    
                    if exercise.type.supportsDetailOptions {
                        Button(action: { showingDetails.toggle() }) {
                            HStack(spacing: 4) {
                                if recordedExercise.selectedDetailOptions.isEmpty {
                                    Text("Add Details")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                } else {
                                    Text(recordedExercise.selectedDetailOptions.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            
            // Exercise-specific controls
            if exercise.type == .flexibility {
                FlexibilityTimerView(recordedExercise: recordedExercise, onComplete: onComplete)
            } else if exercise.type == .pullups {
                PullupsTimerView(recordedExercise: recordedExercise, onComplete: onComplete)
            } else if exercise.type == .nxn {
                NxNTimerView(recordedExercise: recordedExercise, onComplete: onComplete)
            } else if exercise.type == .boardClimbing {
                BoardClimbingTimerView(recordedExercise: recordedExercise, onComplete: onComplete)
            } else if exercise.type == .shoulderLifts {
                ShoulderLiftsTimerView(recordedExercise: recordedExercise, onComplete: onComplete)
            } else if exercise.type == .repeaters {
                RepeatersTimerView(recordedExercise: recordedExercise, onComplete: onComplete)
            } else if exercise.type == .edgePickups {
                EdgePickupsTimerView(recordedExercise: recordedExercise, onComplete: onComplete)
            } else if exercise.type == .limitBouldering {
                LimitBoulderingTimerView(recordedExercise: recordedExercise, onComplete: onComplete)
            } else if exercise.type == .hangboarding {
                MaxHangsTimerView(recordedExercise: recordedExercise, onComplete: onComplete)
            } else if exercise.type == .boulderCampus {
                BoulderCampusTimerView(recordedExercise: recordedExercise, onComplete: onComplete)
            } else if exercise.type == .deadlifts {
                DeadliftsTimerView(recordedExercise: recordedExercise, onComplete: onComplete)
            } else {
                // Standard timer display for other exercises
                VStack(spacing: 8) {
                    Text(formatTime(elapsedTime))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(isRunning ? .green : .secondary)
                    
                    // Control buttons
                    HStack(spacing: 16) {
                        if !isRunning && elapsedTime == 0 {
                            Button(action: startTimer) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Start")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        } else if isRunning {
                            Button(action: pauseTimer) {
                                HStack {
                                    Image(systemName: "pause.fill")
                                    Text("Pause")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        } else if isPaused {
                            Button(action: resumeTimer) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Resume")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                        
                        Button(action: {
                            stopTimer()
                            onComplete()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Complete")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(elapsedTime == 0 && !isRunning)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Details sheet
            if showingDetails {
                ExerciseDetailOptionsView(
                    exercise: exercise,
                    recordedExercise: recordedExercise
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .onAppear {
            if recordedExercise.recordedStartTime != nil {
                // Resume from existing start
                if let startTime = recordedExercise.recordedStartTime {
                    elapsedTime = Date().timeIntervalSince(startTime) - Double(recordedExercise.pausedDuration)
                    if !recordedExercise.isCompleted {
                        startTimer()
                    }
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startTimer() {
        recordedExercise.recordedStartTime = Date()
        isRunning = true
        isPaused = false
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let startTime = recordedExercise.recordedStartTime {
                elapsedTime = Date().timeIntervalSince(startTime) - Double(recordedExercise.pausedDuration)
            }
        }
    }
    
    private func pauseTimer() {
        timer?.invalidate()
        isRunning = false
        isPaused = true
        pausedStartTime = Date()
    }
    
    private func resumeTimer() {
        if let pauseTime = pausedStartTime {
            let pauseDuration = Int(Date().timeIntervalSince(pauseTime))
            recordedExercise.pausedDuration += pauseDuration
            pausedStartTime = nil
        }
        isRunning = true
        isPaused = false
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let startTime = recordedExercise.recordedStartTime {
                elapsedTime = Date().timeIntervalSince(startTime) - Double(recordedExercise.pausedDuration)
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        recordedExercise.recordedEndTime = Date()
        if let startTime = recordedExercise.recordedStartTime {
            let duration = Int(Date().timeIntervalSince(startTime)) - recordedExercise.pausedDuration
            recordedExercise.recordedDuration = max(0, duration)
        }
        isRunning = false
        isPaused = false
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Flexibility Timer View

struct FlexibilityTimerView: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    // Flexibility body parts with individual timers
    enum FlexibilityArea: String, CaseIterable {
        case legs = "Legs"
        case back = "Back"
        case chest = "Chest"
        case neck = "Neck"
        case shoulders = "Shoulders"
        
        var icon: String {
            switch self {
            case .legs: return "figure.walk"
            case .back: return "figure.arms.open"
            case .chest: return "figure.stand"
            case .neck: return "figure.core.training"
            case .shoulders: return "figure.flexibility"
            }
        }
    }
    
    struct AreaTimer: Identifiable {
        let id: String
        let area: FlexibilityArea
        var startTime: Date?
        var elapsedTime: TimeInterval = 0
        var isRunning: Bool = false
        var timer: Timer?
    }
    
    @State private var areaTimers: [AreaTimer] = FlexibilityArea.allCases.map { area in
        AreaTimer(id: area.rawValue, area: area)
    }
    @State private var updateTimer: Timer?
    @State private var currentUpdateTime = Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select areas to stretch")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Grid of body part timer buttons
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach($areaTimers) { $areaTimer in
                    FlexibilityAreaButton(areaTimer: $areaTimer)
                }
            }
            
            // Total time display - calculate with running timers
            let totalTime = areaTimers.reduce(0.0) { total, timer in
                var time = timer.elapsedTime
                if timer.isRunning, let startTime = timer.startTime {
                    time += currentUpdateTime.timeIntervalSince(startTime)
                }
                return total + time
            }
            if totalTime > 0 {
                HStack {
                    Text("Total Flexibility Time:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatTime(totalTime))
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                .padding(.top, 8)
            }
            
            // Complete button
            Button(action: {
                stopAllTimers()
                // Update recorded exercise with flexibility data
                let legTimer = areaTimers.first(where: { $0.area == .legs })
                recordedExercise.hamstrings = (legTimer?.elapsedTime ?? 0) > 0
                recordedExercise.legs = (legTimer?.elapsedTime ?? 0) > 0
                recordedExercise.selectedDetailOptions = areaTimers.filter { $0.elapsedTime > 0 }.map { $0.area.rawValue }
                // Set total duration
                let totalDuration = Int(areaTimers.reduce(0.0) { $0 + $1.elapsedTime })
                recordedExercise.recordedDuration = totalDuration
                recordedExercise.isCompleted = true
                recordedExercise.recordedStartTime = areaTimers.compactMap { $0.startTime }.min() ?? Date()
                recordedExercise.recordedEndTime = Date()
                onComplete()
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Complete Flexibility")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            // Start update timer to refresh total time display
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                currentUpdateTime = Date()
            }
        }
        .onDisappear {
            stopAllTimers()
            updateTimer?.invalidate()
        }
    }
    
    private func stopAllTimers() {
        for index in areaTimers.indices {
            if areaTimers[index].isRunning {
                areaTimers[index].timer?.invalidate()
                if let startTime = areaTimers[index].startTime {
                    areaTimers[index].elapsedTime += Date().timeIntervalSince(startTime)
                }
                areaTimers[index].isRunning = false
                areaTimers[index].startTime = nil
            }
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

struct FlexibilityAreaButton: View {
    @Binding var areaTimer: FlexibilityTimerView.AreaTimer
    @State private var currentTime = Date()
    
    var body: some View {
        Button(action: {
            toggleTimer()
        }) {
            VStack(spacing: 8) {
                Image(systemName: areaTimer.area.icon)
                    .font(.system(size: 32))
                    .foregroundColor(areaTimer.isRunning ? .white : .blue)
                
                Text(areaTimer.area.rawValue)
                    .font(.subheadline)
                    .foregroundColor(areaTimer.isRunning ? .white : .primary)
                
                if areaTimer.isRunning {
                    Text(formatTime(areaTimer.elapsedTime + (currentTime.timeIntervalSince(areaTimer.startTime ?? Date()))))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                } else if areaTimer.elapsedTime > 0 {
                    Text(formatTime(areaTimer.elapsedTime))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(areaTimer.isRunning ? Color.green : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(areaTimer.isRunning ? Color.green : Color(.separator), lineWidth: 2)
            )
        }
        .onAppear {
            if areaTimer.isRunning {
                startUpdateTimer()
            }
        }
        .onChange(of: areaTimer.isRunning) { _, isRunning in
            if isRunning {
                startUpdateTimer()
            } else {
                stopUpdateTimer()
            }
        }
    }
    
    @State private var updateTimer: Timer?
    
    private func toggleTimer() {
        if areaTimer.isRunning {
            // Stop timer
            areaTimer.timer?.invalidate()
            if let startTime = areaTimer.startTime {
                areaTimer.elapsedTime += Date().timeIntervalSince(startTime)
            }
            areaTimer.isRunning = false
            areaTimer.startTime = nil
            stopUpdateTimer()
        } else {
            // Start timer
            areaTimer.startTime = Date()
            areaTimer.isRunning = true
            areaTimer.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                currentTime = Date()
            }
            startUpdateTimer()
        }
    }
    
    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            currentTime = Date()
        }
    }
    
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Pullups Timer View

struct PullupSet: Codable, Identifiable {
    let id: UUID
    var reps: Int
    var weight: Int // added weight in kg
    var restDuration: Int // rest time in seconds
    
    init(id: UUID = UUID(), reps: Int, weight: Int, restDuration: Int = 0) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.restDuration = restDuration
    }
}

struct PullupsTimerView: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    @State private var completedSets: [PullupSet] = []
    @State private var currentSetReps: Int = 5
    @State private var currentSetWeight: Int = 0
    @State private var showingAddSet = false
    @State private var restStartTime: Date?
    @State private var restElapsedTime: TimeInterval = 0
    @State private var isResting = false
    @State private var currentTime = Date()
    @State private var updateTimer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Instructions
            Text("Complete each set, then add it")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Completed sets list
            if !completedSets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completed Sets (\(completedSets.count))")
                        .font(.headline)
                    
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(completedSets) { set in
                                HStack {
                                    Text("Set \(completedSets.firstIndex(where: { $0.id == set.id })! + 1)")
                                        .font(.subheadline)
                                        .bold()
                                    Spacer()
                                    Text("\(set.reps) reps")
                                        .font(.subheadline)
                                    if set.weight > 0 {
                                        Text("+\(set.weight)kg")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
                                    if set.restDuration > 0 {
                                        Text("• Rest: \(formatTime(TimeInterval(set.restDuration)))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }
            
            // Rest timer (if resting between sets)
            if isResting {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                        Text("Resting...")
                            .font(.headline)
                            .foregroundColor(.orange)
                        Spacer()
                        Text(formatTime(restElapsedTime))
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    
                    Button(action: stopRest) {
                        Text("Stop Rest")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
            
            // Add Set button / form
            if !showingAddSet {
                Button(action: {
                    // If resting, capture the rest time before showing form
                    if isResting {
                        stopRest() // This captures restElapsedTime before resetting
                    }
                    showingAddSet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(isResting ? "Start Next Set (Rest: \(formatTime(restElapsedTime)))" : "Add Set")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            } else {
                VStack(spacing: 12) {
                    HStack {
                        Text("Repetitions:")
                            .font(.subheadline)
                        Spacer()
                        Stepper(value: $currentSetReps, in: 1...50) {
                            Text("\(currentSetReps)")
                                .font(.headline)
                                .frame(minWidth: 40)
                        }
                    }
                    
                    HStack {
                        Text("Added Weight:")
                            .font(.subheadline)
                        Spacer()
                        Stepper(value: $currentSetWeight, in: 0...100) {
                            Text(currentSetWeight == 0 ? "Bodyweight" : "+\(currentSetWeight)kg")
                                .font(.headline)
                                .frame(minWidth: 100, alignment: .trailing)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            showingAddSet = false
                            if isResting {
                                stopRest()
                            }
                        }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: addSet) {
                            Text("Save Set")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Summary
            if !completedSets.isEmpty {
                let totalReps = completedSets.reduce(0) { $0 + $1.reps }
                let avgWeight = completedSets.isEmpty ? 0 : completedSets.reduce(0) { $0 + $1.weight } / completedSets.count
                let totalRest = completedSets.reduce(0) { $0 + $1.restDuration }
                
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Reps:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(totalReps)")
                                .font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Avg Weight:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(avgWeight == 0 ? "Bodyweight" : "+\(avgWeight)kg")
                                .font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Total Rest:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatTime(TimeInterval(totalRest)))
                                .font(.headline)
                        }
                    }
                }
                .padding(.top, 8)
            }
            
            // Complete button
            if !completedSets.isEmpty {
                Button(action: {
                    saveSetsData()
                    recordedExercise.sets = completedSets.count
                    recordedExercise.repetitions = completedSets.reduce(0) { $0 + $1.reps }
                    recordedExercise.addedWeight = completedSets.isEmpty ? 0 : completedSets.reduce(0) { $0 + $1.weight } / completedSets.count
                    recordedExercise.restDuration = completedSets.reduce(0) { $0 + $1.restDuration } / max(completedSets.count - 1, 1)
                    recordedExercise.isCompleted = true
                    recordedExercise.recordedStartTime = Date()
                    recordedExercise.recordedEndTime = Date()
                    stopRest()
                    onComplete()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete Pull-ups")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            loadSetsData()
            currentTime = Date()
            // Start update timer to refresh rest time display
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                currentTime = Date()
                if isResting, let start = restStartTime {
                    restElapsedTime = currentTime.timeIntervalSince(start)
                }
            }
        }
        .onDisappear {
            updateTimer?.invalidate()
        }
    }
    
    private func addSet() {
        // The rest duration was already captured when "Add Set" button was clicked (stopRest was called)
        // If this is the first set, rest duration is 0
        let restDuration = completedSets.isEmpty ? 0 : Int(restElapsedTime)
        let newSet = PullupSet(reps: currentSetReps, weight: currentSetWeight, restDuration: restDuration)
        completedSets.append(newSet)
        showingAddSet = false
        
        // Automatically start rest timer after saving set (for rest before next set)
        startRest()
        
        // Keep current values for next set (user can adjust if needed)
    }
    
    private func startRest() {
        isResting = true
        restStartTime = Date()
        restElapsedTime = 0
        // Update timer is already running from onAppear
    }
    
    private func stopRest() {
        // Capture current rest time before resetting
        if isResting, let start = restStartTime {
            restElapsedTime = Date().timeIntervalSince(start)
        }
        isResting = false
        restStartTime = nil
        // Note: restElapsedTime is kept so it can be used when adding the set
    }
    
    private func saveSetsData() {
        if let jsonData = try? JSONEncoder().encode(completedSets),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            recordedExercise.pullupSetsData = jsonString
        }
    }
    
    private func loadSetsData() {
        guard !recordedExercise.pullupSetsData.isEmpty,
              let data = recordedExercise.pullupSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([PullupSet].self, from: data) else {
            return
        }
        completedSets = sets
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Shoulder Lifts Timer View

struct ShoulderLiftSet: Codable, Identifiable {
    let id: UUID
    var reps: Int
    var weight: Int // weight in kg
    var restDuration: Int // rest time in seconds
    
    init(id: UUID = UUID(), reps: Int, weight: Int, restDuration: Int = 0) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.restDuration = restDuration
    }
}

struct ShoulderLiftsTimerView: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    @State private var completedSets: [ShoulderLiftSet] = []
    @State private var currentSetReps: Int = 20
    @State private var currentSetWeight: Int = 10
    @State private var showingAddSet = false
    @State private var restStartTime: Date?
    @State private var restElapsedTime: TimeInterval = 0
    @State private var isResting = false
    @State private var currentTime = Date()
    @State private var updateTimer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Instructions
            Text("Complete each set, then add it")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Completed sets list
            if !completedSets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completed Sets (\(completedSets.count))")
                        .font(.headline)
                    
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(completedSets) { set in
                                HStack {
                                    Text("Set \(completedSets.firstIndex(where: { $0.id == set.id })! + 1)")
                                        .font(.subheadline)
                                        .bold()
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(set.reps) reps")
                                            .font(.subheadline)
                                        Text("\(set.weight)kg")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                        if set.restDuration > 0 {
                                            Text("• Rest: \(formatTime(TimeInterval(set.restDuration)))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }
            
            // Rest timer (if resting between sets)
            if isResting {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                        Text("Resting...")
                            .font(.headline)
                            .foregroundColor(.orange)
                        Spacer()
                        Text(formatTime(restElapsedTime))
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    
                    Button(action: stopRest) {
                        Text("Stop Rest")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
            
            // Add Set button / form
            if !showingAddSet {
                Button(action: {
                    // If resting, capture the rest time before showing form
                    if isResting {
                        stopRest() // This captures restElapsedTime before resetting
                    }
                    showingAddSet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(isResting ? "Start Next Set (Rest: \(formatTime(restElapsedTime)))" : "Add Set")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            } else {
                VStack(spacing: 12) {
                    HStack {
                        Text("Repetitions:")
                            .font(.subheadline)
                        Spacer()
                        Stepper(value: $currentSetReps, in: 1...100) {
                            Text("\(currentSetReps)")
                                .font(.headline)
                                .frame(minWidth: 40)
                        }
                    }
                    
                    HStack {
                        Text("Weight (kg):")
                            .font(.subheadline)
                        Spacer()
                        Stepper(value: $currentSetWeight, in: 0...200) {
                            Text("\(currentSetWeight)kg")
                                .font(.headline)
                                .frame(minWidth: 100, alignment: .trailing)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            showingAddSet = false
                            if isResting {
                                stopRest()
                            }
                        }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: addSet) {
                            Text("Save Set")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Summary
            if !completedSets.isEmpty {
                let totalReps = completedSets.reduce(0) { $0 + $1.reps }
                let avgWeight = completedSets.isEmpty ? 0 : completedSets.reduce(0) { $0 + $1.weight } / completedSets.count
                let totalRest = completedSets.reduce(0) { $0 + $1.restDuration }
                
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Reps:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(totalReps)")
                                .font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Avg Weight:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(avgWeight)kg")
                                .font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Total Rest:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatTime(TimeInterval(totalRest)))
                                .font(.headline)
                        }
                    }
                }
                .padding(.top, 8)
            }
            
            // Complete button
            if !completedSets.isEmpty {
                Button(action: {
                    saveSetsData()
                    recordedExercise.sets = completedSets.count
                    recordedExercise.repetitions = completedSets.reduce(0) { $0 + $1.reps }
                    recordedExercise.weight = completedSets.isEmpty ? 0 : completedSets.reduce(0) { $0 + $1.weight } / completedSets.count
                    recordedExercise.restDuration = completedSets.reduce(0) { $0 + $1.restDuration } / max(completedSets.count - 1, 1)
                    recordedExercise.isCompleted = true
                    recordedExercise.recordedStartTime = Date()
                    recordedExercise.recordedEndTime = Date()
                    stopRest()
                    onComplete()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete Shoulder Lifts")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            loadSetsData()
            currentTime = Date()
            // Initialize with exercise defaults if available
            if let reps = recordedExercise.repetitions {
                currentSetReps = reps
            }
            if let weight = recordedExercise.weight {
                currentSetWeight = weight
            }
            // Start update timer to refresh rest time display
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                currentTime = Date()
                if isResting, let start = restStartTime {
                    restElapsedTime = currentTime.timeIntervalSince(start)
                }
            }
        }
        .onDisappear {
            updateTimer?.invalidate()
        }
    }
    
    private func addSet() {
        // The rest duration was already captured when "Add Set" button was clicked (stopRest was called)
        // If this is the first set, rest duration is 0
        let restDuration = completedSets.isEmpty ? 0 : Int(restElapsedTime)
        let newSet = ShoulderLiftSet(reps: currentSetReps, weight: currentSetWeight, restDuration: restDuration)
        completedSets.append(newSet)
        showingAddSet = false
        
        // Automatically start rest timer after saving set (for rest before next set)
        startRest()
        
        // Keep current values for next set (user can adjust if needed)
    }
    
    private func startRest() {
        isResting = true
        restStartTime = Date()
        restElapsedTime = 0
        // Update timer is already running from onAppear
    }
    
    private func stopRest() {
        // Capture current rest time before resetting
        if isResting, let start = restStartTime {
            restElapsedTime = Date().timeIntervalSince(start)
        }
        isResting = false
        restStartTime = nil
        // Note: restElapsedTime is kept so it can be used when adding the set
    }
    
    private func saveSetsData() {
        if let jsonData = try? JSONEncoder().encode(completedSets),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            recordedExercise.shoulderLiftsSetsData = jsonString
        }
    }
    
    private func loadSetsData() {
        guard !recordedExercise.shoulderLiftsSetsData.isEmpty,
              let data = recordedExercise.shoulderLiftsSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([ShoulderLiftSet].self, from: data) else {
            return
        }
        completedSets = sets
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Repeaters Timer View

struct RepeaterSet: Codable, Identifiable {
    let id: UUID
    var edgeSize: Int // edge size in mm (10, 15, 20, 30)
    var hangTime: Int // hang duration in seconds (usually 7)
    var restTime: Int // rest between hangs in seconds (usually 3)
    var repeats: Int // number of repeat hang/rest cycles (usually 6)
    var addedWeight: Int // added weight in kg (0 for bodyweight)
    var completed: Bool // whether set was completed
    var restBetweenSets: Int // rest time after this set in seconds
    
    init(id: UUID = UUID(), edgeSize: Int, hangTime: Int, restTime: Int, repeats: Int, addedWeight: Int = 0, completed: Bool = false, restBetweenSets: Int = 0) {
        self.id = id
        self.edgeSize = edgeSize
        self.hangTime = hangTime
        self.restTime = restTime
        self.repeats = repeats
        self.addedWeight = addedWeight
        self.completed = completed
        self.restBetweenSets = restBetweenSets
    }
}

struct RepeatersTimerView: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    // Configuration
    @State private var edgeSize: Int = 20 // mm
    @State private var hangTime: Int = 7 // seconds
    @State private var restTime: Int = 3 // seconds
    @State private var repeatsPerSet: Int = 6
    @State private var numberOfSets: Int = 4
    @State private var restBetweenSets: Int = 300 // 5 minutes in seconds
    @State private var addedWeight: Int = 0 // added weight in kg
    
    // Workout state
    @State private var currentSet: Int = 0 // 0-based, current set index
    @State private var currentRepeat: Int = 0 // 0-based, current repeat in set
    @State private var completedSets: [RepeaterSet] = []
    
    // Timer state
    @State private var isRunning: Bool = false
    @State private var isPaused: Bool = false
    @State private var pausedPhaseRemainingTime: TimeInterval = 0
    @State private var phase: RepeaterPhase = .idle
    @State private var phaseRemainingTime: TimeInterval = 0
    @State private var phaseStartTime: Date?
    @State private var updateTimer: Timer?
    @State private var currentTime = Date()
    
    enum RepeaterPhase {
        case idle
        case hang
        case restBetweenHangs
        case restBetweenSets
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Configuration (only show if not started)
            if !isRunning && currentSet == 0 && completedSets.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Configure Workout")
                        .font(.headline)
                    
                    // Edge Size
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Edge Size (mm)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $edgeSize) {
                            Text("10mm").tag(10)
                            Text("15mm").tag(15)
                            Text("20mm").tag(20)
                            Text("30mm").tag(30)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Hang Time
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hang Time (seconds)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: $hangTime, in: 1...30) {
                            Text("\(hangTime)s")
                                .font(.headline)
                                .frame(minWidth: 60, alignment: .trailing)
                        }
                    }
                    
                    // Rest Time between hangs
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rest Between Hangs (seconds)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: $restTime, in: 1...30) {
                            Text("\(restTime)s")
                                .font(.headline)
                                .frame(minWidth: 60, alignment: .trailing)
                        }
                    }
                    
                    // Repeats per set
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Repeats Per Set")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: $repeatsPerSet, in: 1...20) {
                            Text("\(repeatsPerSet)")
                                .font(.headline)
                                .frame(minWidth: 60, alignment: .trailing)
                        }
                    }
                    
                    // Number of sets
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Number of Sets")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: $numberOfSets, in: 1...10) {
                            Text("\(numberOfSets)")
                                .font(.headline)
                                .frame(minWidth: 60, alignment: .trailing)
                        }
                    }
                    
                    // Rest between sets
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rest Between Sets (minutes)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: Binding(
                            get: { restBetweenSets / 60 },
                            set: { restBetweenSets = $0 * 60 }
                        ), in: 1...10) {
                            Text("\(restBetweenSets / 60) min")
                                .font(.headline)
                                .frame(minWidth: 80, alignment: .trailing)
                        }
                    }
                    
                    // Added Weight
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Added Weight (kg)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: $addedWeight, in: 0...100) {
                            Text(addedWeight == 0 ? "Bodyweight" : "+\(addedWeight)kg")
                                .font(.headline)
                                .frame(minWidth: 100, alignment: .trailing)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Active workout display
            if isRunning || isPaused {
                VStack(spacing: 16) {
                    // Set progress
                    Text("Set \(currentSet + 1) of \(numberOfSets)")
                        .font(.headline)
                    
                    // Repeat progress
                    if phase == .hang || phase == .restBetweenHangs {
                        Text("Repeat \(currentRepeat + 1) of \(repeatsPerSet)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Phase indicator and countdown
                    VStack(spacing: 12) {
                        switch phase {
                        case .hang:
                            VStack(spacing: 8) {
                                Text("HANG")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.red)
                                
                                Text(formatCountdown(phaseRemainingTime))
                                    .font(.system(size: 64, weight: .bold, design: .monospaced))
                                    .foregroundColor(.red)
                                
                                Text("Hold on to \(edgeSize)mm edge")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(16)
                            
                        case .restBetweenHangs:
                            VStack(spacing: 8) {
                                Text("REST")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.blue)
                                
                                Text(formatCountdown(phaseRemainingTime))
                                    .font(.system(size: 64, weight: .bold, design: .monospaced))
                                    .foregroundColor(.blue)
                                
                                Text("Recover between hangs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(16)
                            
                        case .restBetweenSets:
                            VStack(spacing: 8) {
                                Text("REST BETWEEN SETS")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.orange)
                                
                                Text(formatTime(phaseRemainingTime))
                                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                                    .foregroundColor(.orange)
                                
                                Text("Long rest before next set")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(16)
                            
                        case .idle:
                            EmptyView()
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Control buttons
            if !isRunning && !isPaused && completedSets.isEmpty {
                Button(action: startWorkout) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Start Repeaters")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            } else if isRunning {
                Button(action: pauseWorkout) {
                    HStack {
                        Image(systemName: "pause.circle.fill")
                        Text("Pause")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            } else if isPaused {
                HStack(spacing: 12) {
                    Button(action: resumeWorkout) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Resume")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    Button(action: stopWorkout) {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                            Text("Stop")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
            }
            
            // Completed sets list
            if !completedSets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completed Sets (\(completedSets.count))")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(completedSets) { set in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Set \(completedSets.firstIndex(where: { $0.id == set.id })! + 1)")
                                            .font(.subheadline)
                                            .bold()
                                        
                                        Text("\(set.edgeSize)mm edge • \(set.hangTime)s hang • \(set.restTime)s rest")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text("\(set.repeats) repeats")
                                            .font(.caption)
                                        
                                        if set.addedWeight > 0 {
                                            Text("+\(set.addedWeight)kg")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                        
                                        if set.restBetweenSets > 0 {
                                            Text("Rest: \(formatTime(TimeInterval(set.restBetweenSets)))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if set.completed {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }
            
            // Complete button
            if !completedSets.isEmpty && completedSets.count == numberOfSets && !isRunning {
                Button(action: {
                    saveSetsData()
                    recordedExercise.sets = numberOfSets
                    recordedExercise.edgeSize = edgeSize
                    recordedExercise.duration = hangTime
                    recordedExercise.restDuration = restTime
                    recordedExercise.repetitions = repeatsPerSet
                    recordedExercise.isCompleted = true
                    recordedExercise.recordedStartTime = Date()
                    recordedExercise.recordedEndTime = Date()
                    onComplete()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete Repeaters")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            loadSetsData()
            currentTime = Date()
            // Initialize from exercise defaults if available
            if let edge = recordedExercise.edgeSize {
                edgeSize = edge
            }
            if let duration = recordedExercise.duration {
                hangTime = duration
            }
            if let rest = recordedExercise.restDuration {
                restTime = rest
            }
            if let reps = recordedExercise.repetitions {
                repeatsPerSet = reps
            }
            if let sets = recordedExercise.sets {
                numberOfSets = sets
            }
            if let weight = recordedExercise.addedWeight {
                addedWeight = weight
            }
        }
        .onDisappear {
            updateTimer?.invalidate()
        }
    }
    
    private func startWorkout() {
        isRunning = true
        currentSet = 0
        currentRepeat = 0
        phase = .hang
        phaseStartTime = Date()
        phaseRemainingTime = TimeInterval(hangTime)
        
        // Play start sound
        playSound(.start)
        
        // Start update timer
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            currentTime = Date()
            updatePhase()
        }
    }
    
    private func pauseWorkout() {
        updateTimer?.invalidate()
        // Save current remaining time
        pausedPhaseRemainingTime = phaseRemainingTime
        isRunning = false
        isPaused = true
    }
    
    private func resumeWorkout() {
        // Restore remaining time and restart timer
        // Calculate a new start time: now - (phaseDuration - remainingTime)
        phaseRemainingTime = pausedPhaseRemainingTime
        let phaseDuration = getPhaseDuration()
        let elapsedSoFar = phaseDuration - pausedPhaseRemainingTime
        phaseStartTime = Date().addingTimeInterval(-elapsedSoFar)
        isRunning = true
        isPaused = false
        
        // Restart update timer
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            currentTime = Date()
            updatePhase()
        }
    }
    
    private func updatePhase() {
        guard isRunning, let start = phaseStartTime else { return }
        
        // For resume, we need to account for the paused time correctly
        let elapsed = currentTime.timeIntervalSince(start)
        phaseRemainingTime = max(0, getPhaseDuration() - elapsed)
        
        // Check if phase is complete
        if phaseRemainingTime <= 0 {
            completeCurrentPhase()
        }
    }
    
    private func getPhaseDuration() -> TimeInterval {
        switch phase {
        case .hang:
            return TimeInterval(hangTime)
        case .restBetweenHangs:
            return TimeInterval(restTime)
        case .restBetweenSets:
            return TimeInterval(restBetweenSets)
        case .idle:
            return 0
        }
    }
    
    private func completeCurrentPhase() {
        switch phase {
        case .hang:
            // Just finished a hang, move to rest between hangs
            playSound(.beep)
            currentRepeat += 1
            
            if currentRepeat >= repeatsPerSet {
                // Completed all repeats in this set
                completeSet()
            } else {
                // More repeats to go, rest between hangs
                phase = .restBetweenHangs
                phaseStartTime = Date()
                phaseRemainingTime = TimeInterval(restTime)
                playSound(.restStart)
            }
            
        case .restBetweenHangs:
            // Rest between hangs done, start next hang
            playSound(.hangStart)
            phase = .hang
            phaseStartTime = Date()
            phaseRemainingTime = TimeInterval(hangTime)
            
        case .restBetweenSets:
            // Rest between sets done, start next set
            playSound(.start)
            currentSet += 1
            currentRepeat = 0
            phase = .hang
            phaseStartTime = Date()
            phaseRemainingTime = TimeInterval(hangTime)
            
        case .idle:
            break
        }
    }
    
    private func completeSet() {
        // Save completed set
        let restDuration = phase == .restBetweenSets ? Int(phaseRemainingTime) : 0
        let newSet = RepeaterSet(
            edgeSize: edgeSize,
            hangTime: hangTime,
            restTime: restTime,
            repeats: repeatsPerSet,
            completed: true,
            restBetweenSets: restDuration
        )
        completedSets.append(newSet)
        saveSetsData()
        
        // Check if all sets are done
        if currentSet >= numberOfSets - 1 {
            // All sets completed
            stopWorkout()
        } else {
            // Start rest between sets
            phase = .restBetweenSets
            phaseStartTime = Date()
            phaseRemainingTime = TimeInterval(restBetweenSets)
            playSound(.restStart)
        }
    }
    
    private func stopWorkout() {
        updateTimer?.invalidate()
        isRunning = false
        isPaused = false
        phase = .idle
        currentSet = 0
        currentRepeat = 0
        // Don't play complete sound when stopping - only when finishing all sets
    }
    
    private func formatCountdown(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let seconds = totalSeconds % 60
        return String(format: "%d", seconds)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // Sound cues
    enum SoundType {
        case start
        case hangStart
        case restStart
        case beep
        case complete
    }
    
    private func playSound(_ type: SoundType) {
        // Use system sound for cues
        var soundID: SystemSoundID = 0
        
        switch type {
        case .start, .hangStart:
            // Start/hang sound - use system sound 1057 (phone key tone)
            soundID = 1057
        case .restStart:
            // Rest start sound - use system sound 1054 (short low beep)
            soundID = 1054
        case .beep:
            // Beep sound - use system sound 1055 (short high beep)
            soundID = 1055
        case .complete:
            // Complete sound - use system sound 1053 (success)
            soundID = 1053
        }
        
        AudioServicesPlaySystemSound(soundID)
    }
    
    private func saveSetsData() {
        if let jsonData = try? JSONEncoder().encode(completedSets),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            recordedExercise.repeatersSetsData = jsonString
        }
    }
    
    private func loadSetsData() {
        guard !recordedExercise.repeatersSetsData.isEmpty,
              let data = recordedExercise.repeatersSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([RepeaterSet].self, from: data) else {
            return
        }
        completedSets = sets
        if !sets.isEmpty {
            numberOfSets = sets.count
            if let firstSet = sets.first {
                edgeSize = firstSet.edgeSize
                hangTime = firstSet.hangTime
                restTime = firstSet.restTime
                repeatsPerSet = firstSet.repeats
                addedWeight = firstSet.addedWeight
            }
        }
    }
}

// MARK: - Edge Pickups Timer View

struct EdgePickupSet: Codable, Identifiable {
    let id: UUID
    var edgeSize: Int // edge size in mm (10, 15, 20, 30)
    var hangTime: Int // hang duration in seconds (usually 7)
    var restTime: Int // rest between hangs in seconds (usually 3)
    var repeats: Int // number of repeat hang/rest cycles (usually 6)
    var gripType: String // "Half Crimp", "Open", "3-Finger Drag"
    var addedWeight: Int // added weight in kg (0 for bodyweight)
    var completed: Bool // whether set was completed
    var restBetweenSets: Int // rest time after this set in seconds
    
    init(id: UUID = UUID(), edgeSize: Int, hangTime: Int, restTime: Int, repeats: Int, gripType: String, addedWeight: Int = 0, completed: Bool = false, restBetweenSets: Int = 0) {
        self.id = id
        self.edgeSize = edgeSize
        self.hangTime = hangTime
        self.restTime = restTime
        self.repeats = repeats
        self.gripType = gripType
        self.addedWeight = addedWeight
        self.completed = completed
        self.restBetweenSets = restBetweenSets
    }
}

struct EdgePickupsTimerView: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    // Configuration
    @State private var edgeSize: Int = 20 // mm
    @State private var hangTime: Int = 7 // seconds
    @State private var restTime: Int = 3 // seconds
    @State private var repeatsPerSet: Int = 6
    @State private var numberOfSets: Int = 4
    @State private var restBetweenSets: Int = 300 // 5 minutes in seconds
    @State private var addedWeight: Int = 0 // added weight in kg
    @State private var gripType: GripType = .halfCrimp
    
    // Workout state
    @State private var currentSet: Int = 0 // 0-based, current set index
    @State private var currentRepeat: Int = 0 // 0-based, current repeat in set
    @State private var completedSets: [EdgePickupSet] = []
    
    // Timer state
    @State private var isRunning: Bool = false
    @State private var isPaused: Bool = false
    @State private var pausedPhaseRemainingTime: TimeInterval = 0
    @State private var phase: RepeaterPhase = .idle
    @State private var phaseRemainingTime: TimeInterval = 0
    @State private var phaseStartTime: Date?
    @State private var updateTimer: Timer?
    @State private var currentTime = Date()
    
    enum RepeaterPhase {
        case idle
        case hang
        case restBetweenHangs
        case restBetweenSets
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Configuration (only show if not started)
            if !isRunning && currentSet == 0 && completedSets.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Configure Workout")
                        .font(.headline)
                    
                    // Edge Size
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Edge Size (mm)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $edgeSize) {
                            Text("10mm").tag(10)
                            Text("15mm").tag(15)
                            Text("20mm").tag(20)
                            Text("30mm").tag(30)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Grip Type
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Grip Type")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $gripType) {
                            ForEach(GripType.allCases, id: \.self) { grip in
                                Text(grip.rawValue).tag(grip)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Hang Time
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hang Time (seconds)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: $hangTime, in: 1...30) {
                            Text("\(hangTime)s")
                                .font(.headline)
                                .frame(minWidth: 60, alignment: .trailing)
                        }
                    }
                    
                    // Rest Time between hangs
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rest Between Hangs (seconds)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: $restTime, in: 1...30) {
                            Text("\(restTime)s")
                                .font(.headline)
                                .frame(minWidth: 60, alignment: .trailing)
                        }
                    }
                    
                    // Repeats per set
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Repeats Per Set")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: $repeatsPerSet, in: 1...20) {
                            Text("\(repeatsPerSet)")
                                .font(.headline)
                                .frame(minWidth: 60, alignment: .trailing)
                        }
                    }
                    
                    // Number of sets
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Number of Sets")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: $numberOfSets, in: 1...10) {
                            Text("\(numberOfSets)")
                                .font(.headline)
                                .frame(minWidth: 60, alignment: .trailing)
                        }
                    }
                    
                    // Rest between sets
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rest Between Sets (minutes)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: Binding(
                            get: { restBetweenSets / 60 },
                            set: { restBetweenSets = $0 * 60 }
                        ), in: 1...10) {
                            Text("\(restBetweenSets / 60) min")
                                .font(.headline)
                                .frame(minWidth: 80, alignment: .trailing)
                        }
                    }
                    
                    // Added Weight
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Added Weight (kg)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: $addedWeight, in: 0...100) {
                            Text(addedWeight == 0 ? "Bodyweight" : "+\(addedWeight)kg")
                                .font(.headline)
                                .frame(minWidth: 100, alignment: .trailing)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Active workout display (same as Repeaters)
            if isRunning || isPaused {
                VStack(spacing: 16) {
                    // Set progress
                    Text("Set \(currentSet + 1) of \(numberOfSets)")
                        .font(.headline)
                    
                    // Repeat progress
                    if phase == .hang || phase == .restBetweenHangs {
                        Text("Repeat \(currentRepeat + 1) of \(repeatsPerSet)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Grip type indicator
                    Text("\(gripType.rawValue) • \(edgeSize)mm")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Phase indicator and countdown
                    VStack(spacing: 12) {
                        switch phase {
                        case .hang:
                            VStack(spacing: 8) {
                                Text("HANG")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.red)
                                
                                Text(formatCountdown(phaseRemainingTime))
                                    .font(.system(size: 64, weight: .bold, design: .monospaced))
                                    .foregroundColor(.red)
                                
                                Text("Hold on to \(edgeSize)mm edge")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(16)
                            
                        case .restBetweenHangs:
                            VStack(spacing: 8) {
                                Text("REST")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.blue)
                                
                                Text(formatCountdown(phaseRemainingTime))
                                    .font(.system(size: 64, weight: .bold, design: .monospaced))
                                    .foregroundColor(.blue)
                                
                                Text("Recover between hangs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(16)
                            
                        case .restBetweenSets:
                            VStack(spacing: 8) {
                                Text("REST BETWEEN SETS")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.orange)
                                
                                Text(formatTime(phaseRemainingTime))
                                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                                    .foregroundColor(.orange)
                                
                                Text("Long rest before next set")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(16)
                            
                        case .idle:
                            EmptyView()
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Control buttons (same as Repeaters)
            if !isRunning && !isPaused && completedSets.isEmpty {
                Button(action: startWorkout) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Start Edge Pickups")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            } else if isRunning {
                Button(action: pauseWorkout) {
                    HStack {
                        Image(systemName: "pause.circle.fill")
                        Text("Pause")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            } else if isPaused {
                HStack(spacing: 12) {
                    Button(action: resumeWorkout) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Resume")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    Button(action: stopWorkout) {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                            Text("Stop")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
            }
            
            // Completed sets list
            if !completedSets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completed Sets (\(completedSets.count))")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(completedSets) { set in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Set \(completedSets.firstIndex(where: { $0.id == set.id })! + 1)")
                                            .font(.subheadline)
                                            .bold()
                                        
                                        Text("\(set.edgeSize)mm edge • \(set.gripType) • \(set.hangTime)s hang • \(set.restTime)s rest")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text("\(set.repeats) repeats")
                                            .font(.caption)
                                        
                                        if set.addedWeight > 0 {
                                            Text("+\(set.addedWeight)kg")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                        
                                        if set.restBetweenSets > 0 {
                                            Text("Rest: \(formatTime(TimeInterval(set.restBetweenSets)))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if set.completed {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }
            
            // Complete button
            if !completedSets.isEmpty && completedSets.count == numberOfSets && !isRunning {
                Button(action: {
                    saveSetsData()
                    recordedExercise.sets = numberOfSets
                    recordedExercise.edgeSize = edgeSize
                    recordedExercise.duration = hangTime
                    recordedExercise.restDuration = restTime
                    recordedExercise.repetitions = repeatsPerSet
                    recordedExercise.gripType = gripType
                    recordedExercise.addedWeight = addedWeight
                    recordedExercise.isCompleted = true
                    recordedExercise.recordedStartTime = Date()
                    recordedExercise.recordedEndTime = Date()
                    onComplete()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete Edge Pickups")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            loadSetsData()
            currentTime = Date()
            // Initialize from exercise defaults if available
            if let edge = recordedExercise.edgeSize {
                edgeSize = edge
            }
            if let duration = recordedExercise.duration {
                hangTime = duration
            }
            if let rest = recordedExercise.restDuration {
                restTime = rest
            }
            if let reps = recordedExercise.repetitions {
                repeatsPerSet = reps
            }
            if let sets = recordedExercise.sets {
                numberOfSets = sets
            }
            if let grip = recordedExercise.gripType {
                gripType = grip
            }
            if let weight = recordedExercise.addedWeight {
                addedWeight = weight
            }
        }
        .onDisappear {
            updateTimer?.invalidate()
        }
    }
    
    private func startWorkout() {
        isRunning = true
        currentSet = 0
        currentRepeat = 0
        phase = .hang
        phaseStartTime = Date()
        phaseRemainingTime = TimeInterval(hangTime)
        
        // Play start sound
        playSound(.start)
        
        // Start update timer
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            currentTime = Date()
            updatePhase()
        }
    }
    
    private func pauseWorkout() {
        updateTimer?.invalidate()
        // Save current remaining time
        pausedPhaseRemainingTime = phaseRemainingTime
        isRunning = false
        isPaused = true
    }
    
    private func resumeWorkout() {
        // Restore remaining time and restart timer
        // Calculate a new start time: now - (phaseDuration - remainingTime)
        phaseRemainingTime = pausedPhaseRemainingTime
        let phaseDuration = getPhaseDuration()
        let elapsedSoFar = phaseDuration - pausedPhaseRemainingTime
        phaseStartTime = Date().addingTimeInterval(-elapsedSoFar)
        isRunning = true
        isPaused = false
        
        // Restart update timer
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            currentTime = Date()
            updatePhase()
        }
    }
    
    private func updatePhase() {
        guard isRunning, let start = phaseStartTime else { return }
        
        // For resume, we need to account for the paused time correctly
        let elapsed = currentTime.timeIntervalSince(start)
        phaseRemainingTime = max(0, getPhaseDuration() - elapsed)
        
        // Check if phase is complete
        if phaseRemainingTime <= 0 {
            completeCurrentPhase()
        }
    }
    
    private func getPhaseDuration() -> TimeInterval {
        switch phase {
        case .hang:
            return TimeInterval(hangTime)
        case .restBetweenHangs:
            return TimeInterval(restTime)
        case .restBetweenSets:
            return TimeInterval(restBetweenSets)
        case .idle:
            return 0
        }
    }
    
    private func completeCurrentPhase() {
        switch phase {
        case .hang:
            // Just finished a hang, move to rest between hangs
            playSound(.beep)
            currentRepeat += 1
            
            if currentRepeat >= repeatsPerSet {
                // Completed all repeats in this set
                completeSet()
            } else {
                // More repeats to go, rest between hangs
                phase = .restBetweenHangs
                phaseStartTime = Date()
                phaseRemainingTime = TimeInterval(restTime)
                playSound(.restStart)
            }
            
        case .restBetweenHangs:
            // Rest between hangs done, start next hang
            playSound(.hangStart)
            phase = .hang
            phaseStartTime = Date()
            phaseRemainingTime = TimeInterval(hangTime)
            
        case .restBetweenSets:
            // Rest between sets done, start next set
            playSound(.start)
            currentSet += 1
            currentRepeat = 0
            phase = .hang
            phaseStartTime = Date()
            phaseRemainingTime = TimeInterval(hangTime)
            
        case .idle:
            break
        }
    }
    
    private func completeSet() {
        // Save completed set
        let restDuration = phase == .restBetweenSets ? Int(phaseRemainingTime) : 0
        let newSet = EdgePickupSet(
            edgeSize: edgeSize,
            hangTime: hangTime,
            restTime: restTime,
            repeats: repeatsPerSet,
            gripType: gripType.rawValue,
            addedWeight: addedWeight,
            completed: true,
            restBetweenSets: restDuration
        )
        completedSets.append(newSet)
        saveSetsData()
        
        // Check if all sets are done
        if currentSet >= numberOfSets - 1 {
            // All sets completed
            stopWorkout()
        } else {
            // Start rest between sets
            phase = .restBetweenSets
            phaseStartTime = Date()
            phaseRemainingTime = TimeInterval(restBetweenSets)
            playSound(.restStart)
        }
    }
    
    private func stopWorkout() {
        updateTimer?.invalidate()
        isRunning = false
        isPaused = false
        phase = .idle
        currentSet = 0
        currentRepeat = 0
        // Don't play complete sound when stopping - only when finishing all sets
    }
    
    private func formatCountdown(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let seconds = totalSeconds % 60
        return String(format: "%d", seconds)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // Sound cues
    enum SoundType {
        case start
        case hangStart
        case restStart
        case beep
        case complete
    }
    
    private func playSound(_ type: SoundType) {
        // Use system sound for cues
        var soundID: SystemSoundID = 0
        
        switch type {
        case .start, .hangStart:
            // Start/hang sound - use system sound 1057 (phone key tone)
            soundID = 1057
        case .restStart:
            // Rest start sound - use system sound 1054 (short low beep)
            soundID = 1054
        case .beep:
            // Beep sound - use system sound 1055 (short high beep)
            soundID = 1055
        case .complete:
            // Complete sound - use system sound 1053 (success)
            soundID = 1053
        }
        
        AudioServicesPlaySystemSound(soundID)
    }
    
    private func saveSetsData() {
        if let jsonData = try? JSONEncoder().encode(completedSets),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            recordedExercise.edgePickupsSetsData = jsonString
        }
    }
    
    private func loadSetsData() {
        guard !recordedExercise.edgePickupsSetsData.isEmpty,
              let data = recordedExercise.edgePickupsSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([EdgePickupSet].self, from: data) else {
            return
        }
        completedSets = sets
        if !sets.isEmpty {
            numberOfSets = sets.count
            if let firstSet = sets.first {
                edgeSize = firstSet.edgeSize
                hangTime = firstSet.hangTime
                restTime = firstSet.restTime
                repeatsPerSet = firstSet.repeats
                if let grip = GripType.allCases.first(where: { $0.rawValue == firstSet.gripType }) {
                    gripType = grip
                }
                addedWeight = firstSet.addedWeight
            }
        }
    }
}

// MARK: - Max Hangs Timer View

struct MaxHangSet: Codable, Identifiable {
    let id: UUID
    var edgeSize: Int // edge size in mm
    var duration: Int // hang duration in seconds
    var restDuration: Int // rest time after this set in seconds
    var addedWeight: Int // added weight in kg (0 for bodyweight)
    
    init(id: UUID = UUID(), edgeSize: Int, duration: Int, restDuration: Int = 0, addedWeight: Int = 0) {
        self.id = id
        self.edgeSize = edgeSize
        self.duration = duration
        self.restDuration = restDuration
        self.addedWeight = addedWeight
    }
}

struct MaxHangsTimerView: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    // Configuration
    @State private var edgeSize: Int = 20 // mm
    @State private var hangDuration: Int = 10 // seconds
    @State private var restDuration: Int = 120 // rest between sets in seconds (default 2 minutes)
    @State private var numberOfSets: Int = 3
    @State private var addedWeight: Int = 0 // added weight in kg
    
    // Workout state
    @State private var currentSet: Int = 0 // 0-based, current set index
    @State private var completedSets: [MaxHangSet] = []
    
    // Timer state
    @State private var isRunning: Bool = false
    @State private var isPaused: Bool = false
    @State private var pausedPhaseRemainingTime: TimeInterval = 0
    @State private var phase: MaxHangPhase = .idle
    @State private var phaseRemainingTime: TimeInterval = 0
    @State private var phaseStartTime: Date?
    @State private var updateTimer: Timer?
    @State private var currentTime = Date()
    
    enum MaxHangPhase {
        case idle
        case prep
        case hang
        case rest
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Configuration (only show if not started)
            if !isRunning && currentSet == 0 && completedSets.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Configure Workout")
                        .font(.headline)
                    
                    // Edge Size
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Edge Size (mm)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $edgeSize) {
                            Text("10mm").tag(10)
                            Text("15mm").tag(15)
                            Text("20mm").tag(20)
                            Text("30mm").tag(30)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Hang Duration
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hang Duration (seconds)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: $hangDuration, in: 1...60) {
                            Text("\(hangDuration)s")
                                .font(.headline)
                                .frame(minWidth: 60, alignment: .trailing)
                        }
                    }
                    
                    // Rest Duration between sets
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rest Between Sets (minutes)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: Binding(
                            get: { restDuration / 60 },
                            set: { restDuration = $0 * 60 }
                        ), in: 1...10) {
                            Text("\(restDuration / 60) min")
                                .font(.headline)
                                .frame(minWidth: 80, alignment: .trailing)
                        }
                    }
                    
                    // Number of sets
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Number of Sets")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: $numberOfSets, in: 1...10) {
                            Text("\(numberOfSets)")
                                .font(.headline)
                                .frame(minWidth: 60, alignment: .trailing)
                        }
                    }
                    
                    // Added Weight
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Added Weight (kg)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: $addedWeight, in: 0...100) {
                            Text(addedWeight == 0 ? "Bodyweight" : "+\(addedWeight)kg")
                                .font(.headline)
                                .frame(minWidth: 100, alignment: .trailing)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Active workout display
            if isRunning || isPaused {
                VStack(spacing: 16) {
                    // Set progress
                    Text("Set \(currentSet + 1) of \(numberOfSets)")
                        .font(.headline)
                    
                    // Phase indicator and countdown
                    VStack(spacing: 12) {
                        switch phase {
                        case .prep:
                            VStack(spacing: 8) {
                                Text("PREP")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.orange)
                                
                                Text(formatCountdown(phaseRemainingTime))
                                    .font(.system(size: 64, weight: .bold, design: .monospaced))
                                    .foregroundColor(.orange)
                                
                                Text("Get ready for the first hang")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(16)
                            
                        case .hang:
                            VStack(spacing: 8) {
                                Text("HANG")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.red)
                                
                                Text(formatCountdown(phaseRemainingTime))
                                    .font(.system(size: 64, weight: .bold, design: .monospaced))
                                    .foregroundColor(.red)
                                
                                Text("Hold on to \(edgeSize)mm edge")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(16)
                            
                        case .rest:
                            VStack(spacing: 8) {
                                Text("REST")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.blue)
                                
                                Text(formatCountdown(phaseRemainingTime))
                                    .font(.system(size: 64, weight: .bold, design: .monospaced))
                                    .foregroundColor(.blue)
                                
                                Text("Recover between sets")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(16)
                            
                        case .idle:
                            EmptyView()
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Control buttons
            if !isRunning && !isPaused && completedSets.isEmpty {
                Button(action: startWorkout) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Start Max Hangs")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            } else if isRunning {
                Button(action: pauseWorkout) {
                    HStack {
                        Image(systemName: "pause.circle.fill")
                        Text("Pause")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            } else if isPaused {
                HStack(spacing: 12) {
                    Button(action: resumeWorkout) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Resume")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    Button(action: stopWorkout) {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                            Text("Stop")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
            }
            
            // Completed sets list
            if !completedSets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completed Sets (\(completedSets.count))")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(completedSets) { set in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Set \(completedSets.firstIndex(where: { $0.id == set.id })! + 1)")
                                            .font(.subheadline)
                                            .bold()
                                        
                                        Text("\(set.edgeSize)mm edge • \(set.duration)s hang")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        if set.addedWeight > 0 {
                                            Text("+\(set.addedWeight)kg")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                        
                                        if set.restDuration > 0 {
                                            Text("Rest: \(formatTime(TimeInterval(set.restDuration)))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }
            
            // Complete button
            if !completedSets.isEmpty && completedSets.count == numberOfSets && !isRunning {
                Button(action: {
                    saveSetsData()
                    recordedExercise.sets = numberOfSets
                    recordedExercise.edgeSize = edgeSize
                    recordedExercise.duration = hangDuration
                    recordedExercise.restDuration = restDuration
                    recordedExercise.addedWeight = addedWeight
                    recordedExercise.isCompleted = true
                    recordedExercise.recordedStartTime = Date()
                    recordedExercise.recordedEndTime = Date()
                    onComplete()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete Max Hangs")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            loadSetsData()
            currentTime = Date()
            // Initialize from exercise defaults if available
            if let edge = recordedExercise.edgeSize {
                edgeSize = edge
            }
            if let duration = recordedExercise.duration {
                hangDuration = duration
            }
            if let rest = recordedExercise.restDuration {
                restDuration = rest
            }
            if let sets = recordedExercise.sets {
                numberOfSets = sets
            }
            if let weight = recordedExercise.addedWeight {
                addedWeight = Int(weight)
            }
        }
        .onDisappear {
            updateTimer?.invalidate()
        }
    }
    
    private func startWorkout() {
        isRunning = true
        currentSet = 0
        phase = .prep
        phaseStartTime = Date()
        phaseRemainingTime = 15.0 // 15 second prep timer
        
        // Play start sound
        playSound(.start)
        
        // Start update timer
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            currentTime = Date()
            updatePhase()
        }
    }
    
    private func pauseWorkout() {
        updateTimer?.invalidate()
        pausedPhaseRemainingTime = phaseRemainingTime
        isRunning = false
        isPaused = true
    }
    
    private func resumeWorkout() {
        phaseRemainingTime = pausedPhaseRemainingTime
        let phaseDuration = getPhaseDuration()
        let elapsedSoFar = phaseDuration - pausedPhaseRemainingTime
        phaseStartTime = Date().addingTimeInterval(-elapsedSoFar)
        isRunning = true
        isPaused = false
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            currentTime = Date()
            updatePhase()
        }
    }
    
    private func updatePhase() {
        guard isRunning, let start = phaseStartTime else { return }
        
        let elapsed = currentTime.timeIntervalSince(start)
        phaseRemainingTime = max(0, getPhaseDuration() - elapsed)
        
        if phaseRemainingTime <= 0 {
            completeCurrentPhase()
        }
    }
    
    private func getPhaseDuration() -> TimeInterval {
        switch phase {
        case .prep:
            return 15.0 // 15 second prep timer
        case .hang:
            return TimeInterval(hangDuration)
        case .rest:
            return TimeInterval(restDuration)
        case .idle:
            return 0
        }
    }
    
    private func completeCurrentPhase() {
        switch phase {
        case .prep:
            // Prep timer done, start first hang
            playSound(.hangStart)
            phase = .hang
            phaseStartTime = Date()
            phaseRemainingTime = TimeInterval(hangDuration)
            
        case .hang:
            // Just finished a hang, save it and move to rest
            playSound(.beep)
            completeSet()
            
        case .rest:
            // Rest between sets done, start next set (no prep needed for subsequent sets)
            playSound(.start)
            currentSet += 1
            if currentSet < numberOfSets {
                phase = .hang
                phaseStartTime = Date()
                phaseRemainingTime = TimeInterval(hangDuration)
            } else {
                // All sets completed
                stopWorkout()
            }
            
        case .idle:
            break
        }
    }
    
    private func completeSet() {
        // Save completed set
        let newSet = MaxHangSet(
            edgeSize: edgeSize,
            duration: hangDuration,
            restDuration: 0, // Will be set after rest phase
            addedWeight: addedWeight
        )
        completedSets.append(newSet)
        
        // Check if all sets are done
        if currentSet >= numberOfSets - 1 {
            // All sets completed
            stopWorkout()
        } else {
            // Start rest between sets
            phase = .rest
            phaseStartTime = Date()
            phaseRemainingTime = TimeInterval(restDuration)
            playSound(.restStart)
            
            // Update the last set's rest duration after rest completes
            // We'll update it in completeCurrentPhase when phase is .rest
        }
    }
    
    private func stopWorkout() {
        updateTimer?.invalidate()
        isRunning = false
        isPaused = false
        phase = .idle
        
        // Update rest durations for completed sets
        for i in 0..<completedSets.count {
            if i < completedSets.count - 1 {
                // Each set (except last) should have rest duration
                completedSets[i].restDuration = restDuration
            }
        }
        saveSetsData()
    }
    
    private func formatCountdown(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let seconds = totalSeconds % 60
        return String(format: "%d", seconds)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // Sound cues
    enum SoundType {
        case start
        case hangStart
        case restStart
        case beep
        case complete
    }
    
    private func playSound(_ type: SoundType) {
        var soundID: SystemSoundID = 0
        
        switch type {
        case .start:
            soundID = 1057
        case .hangStart:
            soundID = 1057
        case .restStart:
            soundID = 1054
        case .beep:
            soundID = 1055
        case .complete:
            soundID = 1053
        }
        
        AudioServicesPlaySystemSound(soundID)
    }
    
    private func saveSetsData() {
        if let jsonData = try? JSONEncoder().encode(completedSets),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            recordedExercise.maxHangsSetsData = jsonString
        }
    }
    
    private func loadSetsData() {
        guard !recordedExercise.maxHangsSetsData.isEmpty,
              let data = recordedExercise.maxHangsSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([MaxHangSet].self, from: data) else {
            return
        }
        completedSets = sets
        if !sets.isEmpty {
            currentSet = sets.count
        }
    }
}

// MARK: - Boulder Campus Timer View

struct BoulderCampusSet: Codable, Identifiable {
    let id: UUID
    var moves: Int
    var restDuration: Int // rest time in seconds
    
    init(id: UUID = UUID(), moves: Int, restDuration: Int = 0) {
        self.id = id
        self.moves = moves
        self.restDuration = restDuration
    }
}

struct BoulderCampusTimerView: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    // Configuration
    @State private var defaultMoves: Int = 15
    @State private var targetRestDuration: Int = 120 // default 2 minutes in seconds
    
    @State private var completedSets: [BoulderCampusSet] = []
    @State private var currentSetMoves: Int = 15
    @State private var showingAddSet = false
    @State private var restStartTime: Date?
    @State private var restElapsedTime: TimeInterval = 0
    @State private var isResting = false
    @State private var currentTime = Date()
    @State private var updateTimer: Timer?
    
    private var restRemainingTime: TimeInterval {
        let elapsed = restElapsedTime
        let target = TimeInterval(targetRestDuration)
        return max(0, target - elapsed)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Configuration (only show if no sets completed and not resting)
            if completedSets.isEmpty && !isResting && !showingAddSet {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Configure Workout")
                        .font(.headline)
                    
                    // Default Number of Moves
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Number of Moves")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: $defaultMoves, in: 1...50) {
                            Text("\(defaultMoves)")
                                .font(.headline)
                                .frame(minWidth: 60, alignment: .trailing)
                        }
                    }
                    
                    // Rest Duration between sets
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rest Between Sets (minutes)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: Binding(
                            get: { targetRestDuration / 60 },
                            set: { targetRestDuration = $0 * 60 }
                        ), in: 1...10) {
                            Text("\(targetRestDuration / 60) min")
                                .font(.headline)
                                .frame(minWidth: 80, alignment: .trailing)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Instructions
            Text("Complete each set, then add it")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Completed sets list
            if !completedSets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completed Sets (\(completedSets.count))")
                        .font(.headline)
                    
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(completedSets) { set in
                                HStack {
                                    Text("Set \(completedSets.firstIndex(where: { $0.id == set.id })! + 1)")
                                        .font(.subheadline)
                                        .bold()
                                    Spacer()
                                    Text("\(set.moves) moves")
                                        .font(.subheadline)
                                    if set.restDuration > 0 {
                                        Text("• Rest: \(formatTime(TimeInterval(set.restDuration)))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }
            
            // Rest timer (if resting between sets)
            if isResting {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(restRemainingTime <= 0 ? .orange : .blue)
                        Text("Resting...")
                            .font(.headline)
                            .foregroundColor(restRemainingTime <= 0 ? .orange : .blue)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatTime(restRemainingTime))
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundColor(restRemainingTime <= 0 ? .orange : .blue)
                            if restRemainingTime <= 0 {
                                Text("Target: \(formatRestDuration(targetRestDuration))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background((restRemainingTime <= 0 ? Color.orange : Color.blue).opacity(0.1))
                    .cornerRadius(12)
                    
                    HStack(spacing: 12) {
                        Button(action: stopRest) {
                            Text("Skip Rest")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        
                        if restRemainingTime > 0 {
                            Button(action: stopRest) {
                                Text("Rest Complete")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            
            // Add Set button / form
            if !showingAddSet {
                Button(action: {
                    // If resting, capture the rest time before showing form
                    if isResting {
                        stopRest() // This captures restElapsedTime before resetting
                    }
                    // Use default value from configuration
                    currentSetMoves = defaultMoves
                    showingAddSet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(isResting ? "Start Next Set" : "Add Set")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            } else {
                VStack(spacing: 12) {
                    HStack {
                        Text("Number of Moves:")
                            .font(.subheadline)
                        Spacer()
                        Stepper(value: $currentSetMoves, in: 1...50) {
                            Text("\(currentSetMoves)")
                                .font(.headline)
                                .frame(minWidth: 40)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            showingAddSet = false
                            if isResting {
                                stopRest()
                            }
                        }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: addSet) {
                            Text("Save Set")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Summary
            if !completedSets.isEmpty {
                let totalSets = completedSets.count
                let totalMoves = completedSets.reduce(0) { $0 + $1.moves }
                let avgMoves = completedSets.isEmpty ? 0 : totalMoves / completedSets.count
                let totalRest = completedSets.reduce(0) { $0 + $1.restDuration }
                
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Sets:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(totalSets)")
                                .font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Total Moves:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(totalMoves)")
                                .font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Avg Moves:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(avgMoves)")
                                .font(.headline)
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Rest:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatTime(TimeInterval(totalRest)))
                                .font(.headline)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.top, 8)
            }
            
            // Complete button
            if !completedSets.isEmpty {
                Button(action: {
                    saveSetsData()
                    recordedExercise.sets = completedSets.count
                    recordedExercise.moves = completedSets.reduce(0) { $0 + $1.moves }
                    recordedExercise.restDuration = completedSets.isEmpty ? 0 : completedSets.reduce(0) { $0 + $1.restDuration } / max(completedSets.count - 1, 1)
                    recordedExercise.isCompleted = true
                    recordedExercise.recordedStartTime = Date()
                    recordedExercise.recordedEndTime = Date()
                    stopRest()
                    onComplete()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete Boulder Campus")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            loadSetsData()
            currentTime = Date()
            // Initialize from exercise defaults if available
            if let moves = recordedExercise.moves {
                defaultMoves = moves
                currentSetMoves = moves
            }
            if let rest = recordedExercise.restDuration {
                targetRestDuration = rest
            }
            // Start update timer to refresh rest time display
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                currentTime = Date()
                if isResting, let start = restStartTime {
                    restElapsedTime = currentTime.timeIntervalSince(start)
                }
            }
        }
        .onDisappear {
            updateTimer?.invalidate()
        }
    }
    
    private func addSet() {
        // The rest duration was already captured when "Add Set" button was clicked (stopRest was called)
        // If this is the first set, rest duration is 0
        let restDuration = completedSets.isEmpty ? 0 : Int(restElapsedTime)
        let newSet = BoulderCampusSet(moves: currentSetMoves, restDuration: restDuration)
        completedSets.append(newSet)
        saveSetsData()
        showingAddSet = false
        
        // Automatically start rest timer after saving set (for rest before next set)
        startRest()
        
        // Keep current value for next set (user can adjust if needed)
    }
    
    private func startRest() {
        isResting = true
        restStartTime = Date()
        restElapsedTime = 0
        // Update timer is already running from onAppear
    }
    
    private func stopRest() {
        // Capture current rest time before resetting
        if isResting, let start = restStartTime {
            restElapsedTime = Date().timeIntervalSince(start)
        }
        isResting = false
        restStartTime = nil
        // Note: restElapsedTime is kept so it can be used when adding the set
    }
    
    private func saveSetsData() {
        if let jsonData = try? JSONEncoder().encode(completedSets),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            recordedExercise.boulderCampusSetsData = jsonString
        }
    }
    
    private func loadSetsData() {
        guard !recordedExercise.boulderCampusSetsData.isEmpty,
              let data = recordedExercise.boulderCampusSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([BoulderCampusSet].self, from: data) else {
            return
        }
        completedSets = sets
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatRestDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 && secs > 0 {
            return "\(minutes)m \(secs)s"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(secs)s"
        }
    }
}

// MARK: - Deadlifts Timer View

struct DeadliftSet: Codable, Identifiable {
    let id: UUID
    var reps: Int
    var weight: Int // weight in kg
    var restDuration: Int // rest time in seconds
    
    init(id: UUID = UUID(), reps: Int, weight: Int, restDuration: Int = 0) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.restDuration = restDuration
    }
}

struct DeadliftsTimerView: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    // Configuration
    @State private var defaultReps: Int = 5
    @State private var defaultWeight: Int = 50
    @State private var targetRestDuration: Int = 180 // default 3 minutes in seconds
    
    @State private var completedSets: [DeadliftSet] = []
    @State private var currentSetReps: Int = 5
    @State private var currentSetWeight: Int = 50
    @State private var showingAddSet = false
    @State private var restStartTime: Date?
    @State private var restElapsedTime: TimeInterval = 0
    @State private var isResting = false
    @State private var currentTime = Date()
    @State private var updateTimer: Timer?
    
    private var restRemainingTime: TimeInterval {
        let elapsed = restElapsedTime
        let target = TimeInterval(targetRestDuration)
        return max(0, target - elapsed)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Configuration (only show if no sets completed and not resting)
            if completedSets.isEmpty && !isResting && !showingAddSet {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Configure Workout")
                        .font(.headline)
                    
                    // Default Repetitions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Repetitions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: $defaultReps, in: 1...20) {
                            Text("\(defaultReps)")
                                .font(.headline)
                                .frame(minWidth: 60, alignment: .trailing)
                        }
                    }
                    
                    // Default Weight
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Weight (kg)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: $defaultWeight, in: 0...500) {
                            Text("\(defaultWeight)kg")
                                .font(.headline)
                                .frame(minWidth: 80, alignment: .trailing)
                        }
                    }
                    
                    // Rest Duration between sets
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rest Between Sets (minutes)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: Binding(
                            get: { targetRestDuration / 60 },
                            set: { targetRestDuration = $0 * 60 }
                        ), in: 1...10) {
                            Text("\(targetRestDuration / 60) min")
                                .font(.headline)
                                .frame(minWidth: 80, alignment: .trailing)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Instructions
            Text("Complete each set, then add it")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Completed sets list
            if !completedSets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completed Sets (\(completedSets.count))")
                        .font(.headline)
                    
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(completedSets) { set in
                                HStack {
                                    Text("Set \(completedSets.firstIndex(where: { $0.id == set.id })! + 1)")
                                        .font(.subheadline)
                                        .bold()
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(set.reps) reps")
                                            .font(.subheadline)
                                        Text("\(set.weight)kg")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                        if set.restDuration > 0 {
                                            Text("• Rest: \(formatTime(TimeInterval(set.restDuration)))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }
            
            // Rest timer (if resting between sets)
            if isResting {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(restRemainingTime <= 0 ? .orange : .blue)
                        Text("Resting...")
                            .font(.headline)
                            .foregroundColor(restRemainingTime <= 0 ? .orange : .blue)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatTime(restRemainingTime))
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundColor(restRemainingTime <= 0 ? .orange : .blue)
                            if restRemainingTime <= 0 {
                                Text("Target: \(formatRestDuration(targetRestDuration))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background((restRemainingTime <= 0 ? Color.orange : Color.blue).opacity(0.1))
                    .cornerRadius(12)
                    
                    HStack(spacing: 12) {
                        Button(action: stopRest) {
                            Text("Skip Rest")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        
                        if restRemainingTime > 0 {
                            Button(action: stopRest) {
                                Text("Rest Complete")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            
            // Add Set button / form
            if !showingAddSet {
                Button(action: {
                    // If resting, capture the rest time before showing form
                    if isResting {
                        stopRest() // This captures restElapsedTime before resetting
                    }
                    // Use default values from configuration
                    currentSetReps = defaultReps
                    currentSetWeight = defaultWeight
                    showingAddSet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(isResting ? "Start Next Set" : "Add Set")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            } else {
                VStack(spacing: 12) {
                    HStack {
                        Text("Repetitions:")
                            .font(.subheadline)
                        Spacer()
                        Stepper(value: $currentSetReps, in: 1...20) {
                            Text("\(currentSetReps)")
                                .font(.headline)
                                .frame(minWidth: 40)
                        }
                    }
                    
                    HStack {
                        Text("Weight (kg):")
                            .font(.subheadline)
                        Spacer()
                        Stepper(value: $currentSetWeight, in: 0...500) {
                            Text("\(currentSetWeight)kg")
                                .font(.headline)
                                .frame(minWidth: 100, alignment: .trailing)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            showingAddSet = false
                            if isResting {
                                stopRest()
                            }
                        }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: addSet) {
                            Text("Save Set")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Summary
            if !completedSets.isEmpty {
                let totalSets = completedSets.count
                let totalReps = completedSets.reduce(0) { $0 + $1.reps }
                let avgWeight = completedSets.isEmpty ? 0 : completedSets.reduce(0) { $0 + $1.weight } / completedSets.count
                let maxWeight = completedSets.max(by: { $0.weight < $1.weight })?.weight ?? 0
                let totalRest = completedSets.reduce(0) { $0 + $1.restDuration }
                
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Sets:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(totalSets)")
                                .font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Total Reps:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(totalReps)")
                                .font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Avg Weight:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(avgWeight)kg")
                                .font(.headline)
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Max Weight:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(maxWeight)kg")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Total Rest:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatTime(TimeInterval(totalRest)))
                                .font(.headline)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.top, 8)
            }
            
            // Complete button
            if !completedSets.isEmpty {
                Button(action: {
                    saveSetsData()
                    recordedExercise.sets = completedSets.count
                    recordedExercise.repetitions = completedSets.reduce(0) { $0 + $1.reps }
                    recordedExercise.weight = completedSets.isEmpty ? 0 : completedSets.reduce(0) { $0 + $1.weight } / completedSets.count
                    recordedExercise.restDuration = completedSets.isEmpty ? 0 : completedSets.reduce(0) { $0 + $1.restDuration } / max(completedSets.count - 1, 1)
                    recordedExercise.isCompleted = true
                    recordedExercise.recordedStartTime = Date()
                    recordedExercise.recordedEndTime = Date()
                    stopRest()
                    onComplete()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete Deadlifts")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            loadSetsData()
            currentTime = Date()
            // Initialize from exercise defaults if available
            if let reps = recordedExercise.repetitions {
                defaultReps = reps
                currentSetReps = reps
            }
            if let weight = recordedExercise.weight {
                defaultWeight = Int(weight)
                currentSetWeight = Int(weight)
            }
            if let rest = recordedExercise.restDuration {
                targetRestDuration = rest
            }
            // Start update timer to refresh rest time display
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                currentTime = Date()
                if isResting, let start = restStartTime {
                    restElapsedTime = currentTime.timeIntervalSince(start)
                }
            }
        }
        .onDisappear {
            updateTimer?.invalidate()
        }
    }
    
    private func addSet() {
        // The rest duration was already captured when "Add Set" button was clicked (stopRest was called)
        // If this is the first set, rest duration is 0
        let restDuration = completedSets.isEmpty ? 0 : Int(restElapsedTime)
        let newSet = DeadliftSet(reps: currentSetReps, weight: currentSetWeight, restDuration: restDuration)
        completedSets.append(newSet)
        saveSetsData()
        showingAddSet = false
        
        // Automatically start rest timer after saving set (for rest before next set)
        startRest()
        
        // Keep current values for next set (user can adjust if needed)
    }
    
    private func startRest() {
        isResting = true
        restStartTime = Date()
        restElapsedTime = 0
        // Update timer is already running from onAppear
    }
    
    private func stopRest() {
        // Capture current rest time before resetting
        if isResting, let start = restStartTime {
            restElapsedTime = Date().timeIntervalSince(start)
        }
        isResting = false
        restStartTime = nil
        // Note: restElapsedTime is kept so it can be used when adding the set
    }
    
    private func saveSetsData() {
        if let jsonData = try? JSONEncoder().encode(completedSets),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            recordedExercise.deadliftsSetsData = jsonString
        }
    }
    
    private func loadSetsData() {
        guard !recordedExercise.deadliftsSetsData.isEmpty,
              let data = recordedExercise.deadliftsSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([DeadliftSet].self, from: data) else {
            return
        }
        completedSets = sets
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatRestDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 && secs > 0 {
            return "\(minutes)m \(secs)s"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(secs)s"
        }
    }
}

// MARK: - Limit Bouldering Timer View

struct LimitBoulderingRoute: Codable, Identifiable {
    let id: UUID
    var boulderType: String // "Indoor", "Outdoor"
    var grade: String
    var tries: Int
    var sent: Bool
    var name: String? // Optional boulder name
    
    init(id: UUID = UUID(), boulderType: String, grade: String, tries: Int = 1, sent: Bool = false, name: String? = nil) {
        self.id = id
        self.boulderType = boulderType
        self.grade = grade
        self.tries = tries
        self.sent = sent
        self.name = name
    }
}

struct LimitBoulderingTimerView: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    @State private var completedRoutes: [LimitBoulderingRoute] = []
    @State private var showingAddRoute = false
    @State private var selectedBoulderType: TrainingLocation = .indoor
    @State private var selectedGrade: String = "V6"
    @State private var numberOfTries: Int = 1
    @State private var didSend: Bool = false
    @State private var boulderName: String = ""
    
    private let boulderGrades = ["V0", "V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9", "V10", "V11", "V12", "V13", "V14", "V15"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Add Route button
            Button(action: {
                showingAddRoute = true
                // Reset form
                selectedBoulderType = .indoor
                selectedGrade = "V6"
                numberOfTries = 1
                didSend = false
                boulderName = ""
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Route")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            // Completed routes list
            if !completedRoutes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completed Routes")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    ForEach(completedRoutes) { route in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                VStack(alignment: .leading, spacing: 2) {
                                    if let name = route.name, !name.isEmpty {
                                        Text(name)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                    }
                                    Text(route.boulderType)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                
                                HStack(spacing: 8) {
                                    Text(route.grade)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(6)
                                    
                                    Text("\(route.tries) try\(route.tries == 1 ? "" : "ies")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if route.sent {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text("Sent")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                if let index = completedRoutes.firstIndex(where: { $0.id == route.id }) {
                                    completedRoutes.remove(at: index)
                                    saveRoutesData()
                                }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
            
            // Summary
            if !completedRoutes.isEmpty {
                let totalRoutes = completedRoutes.count
                let sentCount = completedRoutes.filter { $0.sent }.count
                let totalTries = completedRoutes.reduce(0) { $0 + $1.tries }
                let avgTries = totalRoutes > 0 ? Double(totalTries) / Double(totalRoutes) : 0
                
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Routes:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(totalRoutes)")
                                .font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Sent:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(sentCount)/\(totalRoutes)")
                                .font(.headline)
                                .foregroundColor(sentCount > 0 ? .green : .primary)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Avg Tries:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", avgTries))
                                .font(.headline)
                        }
                    }
                }
                .padding(.top, 8)
            }
            
            // Spacer to push Complete button to bottom
            Spacer()
            
            // Complete button - always at the bottom
            if !completedRoutes.isEmpty {
                Button(action: {
                    saveRoutesData()
                    recordedExercise.routes = completedRoutes.count
                    
                    // Calculate average grade from sent routes
                    let sentRoutes = completedRoutes.filter { $0.sent }
                    if let firstSent = sentRoutes.first {
                        recordedExercise.grade = firstSent.grade
                    }
                    
                    // Total attempts
                    recordedExercise.attempts = completedRoutes.reduce(0) { $0 + $1.tries }
                    
                    recordedExercise.isCompleted = true
                    recordedExercise.recordedStartTime = Date()
                    recordedExercise.recordedEndTime = Date()
                    onComplete()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete Limit Bouldering")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.top, 16)
            }
            
            // Add Route Sheet
            if showingAddRoute {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Add Route")
                        .font(.headline)
                    
                    // Boulder Type Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Boulder Type")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $selectedBoulderType) {
                            ForEach(TrainingLocation.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Grade Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Grade")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $selectedGrade) {
                            ForEach(boulderGrades, id: \.self) { grade in
                                Text(grade).tag(grade)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    // Name (Optional)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name (Optional)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter boulder name", text: $boulderName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Number of Tries
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Number of Tries")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: $numberOfTries, in: 1...20) {
                            Text("\(numberOfTries)")
                                .font(.headline)
                                .frame(minWidth: 100, alignment: .trailing)
                        }
                    }
                    
                    // Did Send Toggle
                    Toggle(isOn: $didSend) {
                        Text("Sent")
                            .font(.subheadline)
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            showingAddRoute = false
                        }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: addRoute) {
                            Text("Add Route")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            loadRoutesData()
        }
    }
    
    private func addRoute() {
        let name = boulderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let newRoute = LimitBoulderingRoute(
            boulderType: selectedBoulderType.rawValue,
            grade: selectedGrade,
            tries: numberOfTries,
            sent: didSend,
            name: name.isEmpty ? nil : name
        )
        completedRoutes.append(newRoute)
        saveRoutesData()
        showingAddRoute = false
    }
    
    private func saveRoutesData() {
        if let jsonData = try? JSONEncoder().encode(completedRoutes),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            recordedExercise.limitBoulderingRoutesData = jsonString
        }
    }
    
    private func loadRoutesData() {
        guard !recordedExercise.limitBoulderingRoutesData.isEmpty,
              let data = recordedExercise.limitBoulderingRoutesData.data(using: .utf8),
              let routes = try? JSONDecoder().decode([LimitBoulderingRoute].self, from: data) else {
            return
        }
        completedRoutes = routes
    }
}

// MARK: - N x Ns Timer View

struct NxNSet: Codable, Identifiable {
    let id: UUID
    var problems: Int // number of problems in this set
    var completed: Bool // whether all problems were completed
    var restDuration: Int // rest time after this set (in seconds)
    var grades: [String] // grades for each problem (e.g., ["V5", "V6", "V5", "V7"])
    
    init(id: UUID = UUID(), problems: Int, completed: Bool = false, restDuration: Int = 0, grades: [String] = []) {
        self.id = id
        self.problems = problems
        self.completed = completed
        self.restDuration = restDuration
        self.grades = grades
    }
}

struct NxNTimerView: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    // Configuration
    @State private var problemsPerSet: Int = 4 // N problems
    @State private var numberOfSets: Int = 4
    @State private var restMinutes: Int = 2 // N minutes rest
    
    // Workout state
    @State private var currentSet: Int = 0 // 0-based, current set index
    @State private var isClimbingPhase: Bool = true
    @State private var completedSets: [NxNSet] = []
    
    // Timer state
    @State private var phaseStartTime: Date?
    @State private var phaseRemainingTime: TimeInterval = 0
    @State private var isRunning: Bool = false
    @State private var updateTimer: Timer?
    @State private var currentTime = Date()
    
    // Climbing phase uses a different approach - it's about completing problems, not time
    // For climbing, we show how many problems left to complete
    @State private var problemsCompleted: Int = 0
    @State private var showingGradeEntry = false
    @State private var problemGrades: [String] = []
    
    // Common boulder grades
    private let boulderGrades = ["V0", "V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9", "V10", "V11", "V12", "V13", "V14", "V15"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Configuration (only show if not started)
            if !isRunning && currentSet == 0 && completedSets.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Configure Workout")
                        .font(.headline)
                    
                    HStack {
                        Text("Problems per Set (N):")
                            .font(.subheadline)
                        Spacer()
                        Stepper(value: $problemsPerSet, in: 1...20) {
                            Text("\(problemsPerSet)")
                                .font(.headline)
                                .frame(minWidth: 40)
                        }
                    }
                    
                    HStack {
                        Text("Number of Sets:")
                            .font(.subheadline)
                        Spacer()
                        Stepper(value: $numberOfSets, in: 1...10) {
                            Text("\(numberOfSets)")
                                .font(.headline)
                                .frame(minWidth: 40)
                        }
                    }
                    
                    HStack {
                        Text("Rest Duration:")
                            .font(.subheadline)
                        Spacer()
                        Stepper(value: $restMinutes, in: 1...10) {
                            Text("\(restMinutes) min")
                                .font(.headline)
                                .frame(minWidth: 60)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Current phase display
            if isRunning {
                VStack(spacing: 12) {
                    // Phase indicator
                    HStack {
                        Text(isClimbingPhase ? "Climbing Phase" : "Rest Phase")
                            .font(.title2)
                            .bold()
                            .foregroundColor(isClimbingPhase ? .blue : .orange)
                        
                        Spacer()
                        
                        Text("Set \(currentSet + 1) / \(numberOfSets)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Climbing phase: simple completion button
                    if isClimbingPhase {
                        VStack(spacing: 16) {
                            Text("Complete \(problemsPerSet) problems")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                // Mark as complete (no grade entry during workout)
                                problemsCompleted = problemsPerSet
                                completeClimbingPhase(grades: [])
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Mark Complete - All \(problemsPerSet) Problems Done")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .font(.headline)
                            }
                            
                            Button(action: {
                                // Mark as incomplete (didn't finish all problems)
                                problemsCompleted = 0
                                completeClimbingPhase(grades: [])
                            }) {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Didn't Complete All Problems")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.2))
                                .foregroundColor(.red)
                                .cornerRadius(8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    } else {
                        // Rest phase: show countdown
                        VStack(spacing: 8) {
                            Text("Rest Time Remaining")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(formatTime(phaseRemainingTime))
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundColor(.orange)
                            
                            Button(action: skipRest) {
                                Text("Skip Rest")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.orange.opacity(0.3))
                                    .foregroundColor(.orange)
                                    .cornerRadius(8)
                            }
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Completed sets list
            if !completedSets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completed Sets (\(completedSets.count))")
                        .font(.headline)
                    
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(completedSets) { set in
                                HStack {
                                    Text("Set \(completedSets.firstIndex(where: { $0.id == set.id })! + 1)")
                                        .font(.subheadline)
                                        .bold()
                                    
                                    Spacer()
                                    
                                    if set.completed {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    
                                    Text("\(set.problems) problems")
                                        .font(.subheadline)
                                    
                                    if !set.grades.isEmpty {
                                        Text(set.grades.joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    if set.restDuration > 0 {
                                        Text("• Rest: \(formatTime(TimeInterval(set.restDuration)))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
            }
            
            // Start/Control buttons
            if !isRunning && completedSets.isEmpty {
                Button(action: startWorkout) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Start N x Ns Workout")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            } else if isRunning {
                Button(action: pauseWorkout) {
                    HStack {
                        Image(systemName: "pause.circle.fill")
                        Text("Pause")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            
            // Summary
            if !completedSets.isEmpty {
                let totalProblems = completedSets.reduce(0) { $0 + $1.problems }
                let completedCount = completedSets.filter { $0.completed }.count
                let totalRest = completedSets.reduce(0) { $0 + $1.restDuration }
                let allGrades = completedSets.flatMap { $0.grades }.filter { !$0.isEmpty }
                let uniqueGrades = Set(allGrades)
                
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Problems:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(totalProblems)")
                                .font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Sets Completed:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(completedCount)/\(completedSets.count)")
                                .font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Total Rest:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatTime(TimeInterval(totalRest)))
                                .font(.headline)
                        }
                    }
                    
                    if !allGrades.isEmpty {
                        Divider()
                            .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Grades Tracked:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if uniqueGrades.count <= 5 {
                                // Show all unique grades if few
                                Text(Array(uniqueGrades).sorted().joined(separator: ", "))
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            } else {
                                // Show count and sample if many
                                Text("\(uniqueGrades.count) unique grades: \(Array(uniqueGrades).sorted().prefix(3).joined(separator: ", "))...")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                            
                            Text("Total problems with grades: \(allGrades.count)/\(totalProblems)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 8)
            }
            
            // Complete button
            if !completedSets.isEmpty && completedSets.count == numberOfSets {
                Button(action: {
                    // Show grade entry sheet before completing
                    problemGrades = Array(repeating: "", count: problemsPerSet)
                    showingGradeEntry = true
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete N x Ns")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            loadSetsData()
            currentTime = Date()
        }
        .onDisappear {
            updateTimer?.invalidate()
        }
        .sheet(isPresented: $showingGradeEntry) {
            GradeEntrySheet(
                problemsPerSet: problemsPerSet,
                grades: $problemGrades,
                onSave: {
                    // Apply grades to all sets (since same problems are repeated)
                    for index in completedSets.indices {
                        completedSets[index].grades = problemGrades
                    }
                    saveSetsData()
                    recordedExercise.sets = numberOfSets
                    recordedExercise.routes = completedSets.reduce(0) { $0 + $1.problems }
                    recordedExercise.restBetweenRoutes = completedSets.isEmpty ? 0 : completedSets.reduce(0) { $0 + $1.restDuration } / max(completedSets.count - 1, 1)
                    recordedExercise.isCompleted = true
                    recordedExercise.recordedStartTime = Date()
                    recordedExercise.recordedEndTime = Date()
                    stopWorkout()
                    showingGradeEntry = false
                    onComplete()
                },
                onCancel: {
                    showingGradeEntry = false
                }
            )
        }
    }
    
    private func startWorkout() {
        isRunning = true
        currentSet = 0
        isClimbingPhase = true
        problemsCompleted = 0
        phaseStartTime = Date()
        
        // Start update timer
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            currentTime = Date()
            if !isClimbingPhase, let start = phaseStartTime {
                // Update rest countdown
                let elapsed = currentTime.timeIntervalSince(start)
                phaseRemainingTime = max(0, TimeInterval(restMinutes * 60) - elapsed)
                
                // Auto-advance when rest is complete
                if phaseRemainingTime <= 0 {
                    completeRestPhase()
                }
            }
        }
    }
    
    private func pauseWorkout() {
        updateTimer?.invalidate()
        isRunning = false
    }
    
    private func stopWorkout() {
        updateTimer?.invalidate()
        isRunning = false
    }
    
    private func completeClimbingPhase(grades: [String] = []) {
        let wasCompleted = problemsCompleted == problemsPerSet
        let newSet = NxNSet(problems: problemsPerSet, completed: wasCompleted, restDuration: 0, grades: grades)
        completedSets.append(newSet)
        
        // Move to rest phase (unless it's the last set)
        if currentSet < numberOfSets - 1 {
            isClimbingPhase = false
            phaseStartTime = Date()
            phaseRemainingTime = TimeInterval(restMinutes * 60)
        } else {
            // Last set - workout complete
            stopWorkout()
        }
    }
    
    private func completeRestPhase() {
        // Update the rest duration for the last completed set
        if let lastIndex = completedSets.indices.last {
            if let start = phaseStartTime {
                let restDuration = Int(Date().timeIntervalSince(start))
                completedSets[lastIndex].restDuration = restDuration
            }
        }
        
        // Move to next set's climbing phase
        currentSet += 1
        if currentSet < numberOfSets {
            isClimbingPhase = true
            problemsCompleted = 0
            phaseStartTime = Date()
            phaseRemainingTime = 0
        } else {
            stopWorkout()
        }
    }
    
    private func skipRest() {
        completeRestPhase()
    }
    
    private func saveSetsData() {
        if let jsonData = try? JSONEncoder().encode(completedSets),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            recordedExercise.nxnSetsData = jsonString
        }
    }
    
    private func loadSetsData() {
        guard !recordedExercise.nxnSetsData.isEmpty,
              let data = recordedExercise.nxnSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([NxNSet].self, from: data) else {
            return
        }
        completedSets = sets
        numberOfSets = sets.count
        if !sets.isEmpty {
            problemsPerSet = sets.first?.problems ?? 4
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Board Climbing Timer View

struct BoardClimbingRoute: Codable, Identifiable {
    let id: UUID
    var boardType: String // "MoonBoard", "KilterBoard", "FrankieBoard"
    var grade: String
    var tries: Int
    var sent: Bool
    
    init(id: UUID = UUID(), boardType: String, grade: String, tries: Int = 1, sent: Bool = false) {
        self.id = id
        self.boardType = boardType
        self.grade = grade
        self.tries = tries
        self.sent = sent
    }
}

struct BoardClimbingTimerView: View {
    @ObservedObject var recordedExercise: RecordedExercise
    let onComplete: () -> Void
    
    @State private var completedRoutes: [BoardClimbingRoute] = []
    @State private var showingAddRoute = false
    @State private var selectedBoardType: BoardType = .moonBoard
    @State private var selectedGrade: String = "V6"
    @State private var numberOfTries: Int = 1
    @State private var didSend: Bool = false
    
    private var currentBoardType: BoardType {
        recordedExercise.boardType ?? .moonBoard
    }
    
    private let boulderGrades = ["V0", "V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9", "V10", "V11", "V12", "V13", "V14", "V15"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Add Route button
            Button(action: {
                showingAddRoute = true
                // Reset form
                selectedBoardType = currentBoardType
                selectedGrade = "V6"
                numberOfTries = 1
                didSend = false
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Route")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            // Completed routes list
            if !completedRoutes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completed Routes")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    ForEach(completedRoutes) { route in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(route.boardType)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                HStack(spacing: 8) {
                                    Text(route.grade)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(6)
                                    
                                    Text("\(route.tries) try\(route.tries == 1 ? "" : "ies")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if route.sent {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text("Sent")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                if let index = completedRoutes.firstIndex(where: { $0.id == route.id }) {
                                    completedRoutes.remove(at: index)
                                    saveRoutesData()
                                }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
            
            // Summary
            if !completedRoutes.isEmpty {
                let totalRoutes = completedRoutes.count
                let sentCount = completedRoutes.filter { $0.sent }.count
                let totalTries = completedRoutes.reduce(0) { $0 + $1.tries }
                let avgTries = totalRoutes > 0 ? Double(totalTries) / Double(totalRoutes) : 0
                
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Routes:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(totalRoutes)")
                                .font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Sent:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(sentCount)/\(totalRoutes)")
                                .font(.headline)
                                .foregroundColor(sentCount > 0 ? .green : .primary)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Avg Tries:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", avgTries))
                                .font(.headline)
                        }
                    }
                }
                .padding(.top, 8)
            }
            
            // Add Route Sheet
            if showingAddRoute {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Add Route")
                        .font(.headline)
                    
                    // Board Type Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Board Type")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $selectedBoardType) {
                            ForEach(BoardType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Grade Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Grade")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $selectedGrade) {
                            ForEach(boulderGrades, id: \.self) { grade in
                                Text(grade).tag(grade)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    // Number of Tries
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Number of Tries")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Stepper(value: $numberOfTries, in: 1...20) {
                            Text("\(numberOfTries)")
                                .font(.headline)
                                .frame(minWidth: 100, alignment: .trailing)
                        }
                    }
                    
                    // Did Send Toggle
                    Toggle(isOn: $didSend) {
                        Text("Sent")
                            .font(.subheadline)
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            showingAddRoute = false
                        }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: addRoute) {
                            Text("Add Route")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Spacer to push Complete button to bottom
            Spacer()
            
            // Complete button - always at the bottom
            if !completedRoutes.isEmpty {
                Button(action: {
                    saveRoutesData()
                    recordedExercise.routes = completedRoutes.count
                    recordedExercise.boardType = BoardType.allCases.first { type in
                        completedRoutes.contains { $0.boardType == type.rawValue }
                    }
                    
                    // Calculate average grade (could be improved)
                    let sentRoutes = completedRoutes.filter { $0.sent }
                    if let firstSent = sentRoutes.first {
                        recordedExercise.grade = firstSent.grade
                    }
                    
                    // Total attempts
                    recordedExercise.attempts = completedRoutes.reduce(0) { $0 + $1.tries }
                    
                    recordedExercise.isCompleted = true
                    recordedExercise.recordedStartTime = Date()
                    recordedExercise.recordedEndTime = Date()
                    onComplete()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete Board Climbing")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.top, 16)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            loadRoutesData()
            selectedBoardType = currentBoardType
        }
    }
    
    private func addRoute() {
        let newRoute = BoardClimbingRoute(
            boardType: selectedBoardType.rawValue,
            grade: selectedGrade,
            tries: numberOfTries,
            sent: didSend
        )
        completedRoutes.append(newRoute)
        saveRoutesData()
        showingAddRoute = false
    }
    
    private func saveRoutesData() {
        if let jsonData = try? JSONEncoder().encode(completedRoutes),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            recordedExercise.boardClimbingRoutesData = jsonString
        }
    }
    
    private func loadRoutesData() {
        guard !recordedExercise.boardClimbingRoutesData.isEmpty,
              let data = recordedExercise.boardClimbingRoutesData.data(using: .utf8),
              let routes = try? JSONDecoder().decode([BoardClimbingRoute].self, from: data) else {
            return
        }
        completedRoutes = routes
    }
}

// MARK: - Grade Entry Sheet

struct GradeEntrySheet: View {
    let problemsPerSet: Int
    @Binding var grades: [String]
    let onSave: () -> Void
    let onCancel: () -> Void
    
    private let boulderGrades = ["V0", "V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9", "V10", "V11", "V12", "V13", "V14", "V15"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("Enter Grades for Each Problem"),
                    footer: Text("These grades will be applied to all sets, as you repeat the same problems each set.")
                ) {
                    ForEach(0..<problemsPerSet, id: \.self) { index in
                        HStack {
                            Text("Problem \(index + 1):")
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Picker("", selection: Binding(
                                get: { grades.indices.contains(index) ? grades[index] : "" },
                                set: { 
                                    if grades.indices.contains(index) {
                                        grades[index] = $0
                                    } else {
                                        while grades.count <= index {
                                            grades.append("")
                                        }
                                        grades[index] = $0
                                    }
                                }
                            )) {
                                Text("Select grade").tag("")
                                ForEach(boulderGrades, id: \.self) { grade in
                                    Text(grade).tag(grade)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
            }
            .navigationTitle("Enter Grades")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                }
            }
        }
    }
}

struct ExerciseDetailOptionsView: View {
    let exercise: Exercise
    @ObservedObject var recordedExercise: RecordedExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercise Details")
                .font(.headline)
            
            let options = exercise.type.detailOptions
            let selected = Set(recordedExercise.selectedDetailOptions)
            
            FlowLayout(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        if selected.contains(option) {
                            recordedExercise.selectedDetailOptions.removeAll { $0 == option }
                        } else {
                            recordedExercise.selectedDetailOptions.append(option)
                        }
                    }) {
                        Text(option)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selected.contains(option) ? Color.blue : Color(.systemGray5))
                            .foregroundColor(selected.contains(option) ? .white : .primary)
                            .cornerRadius(16)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct CompletedExerciseRow: View {
    let recordedExercise: RecordedExercise
    
    var body: some View {
        HStack {
            Image(recordedExercise.exercise.type.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(recordedExercise.exercise.type.rawValue)
                    .font(.subheadline)
                    .bold()
                
                if let duration = recordedExercise.recordedDuration {
                    Text("Duration: \(formatDuration(duration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !recordedExercise.selectedDetailOptions.isEmpty {
                    Text(recordedExercise.selectedDetailOptions.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// FlowLayout for wrapping buttons
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                      y: bounds.minY + result.frames[index].minY),
                          proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

