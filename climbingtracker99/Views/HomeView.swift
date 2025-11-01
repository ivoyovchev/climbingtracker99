import SwiftUI
import SwiftData
import WidgetKit
import Charts

enum TimeRange: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
}

struct GoalsSectionView: View {
    let goals: Goals
    let trainingProgress: Double
    let runsThisWeek: Int
    let distanceThisWeek: Double
    let currentWeight: Double?
    @Binding var showingGoalsSheet: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Goals")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    showingGoalsSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            GoalsRowView(goals: goals, trainingProgress: trainingProgress, runsThisWeek: runsThisWeek, distanceThisWeek: distanceThisWeek, currentWeight: currentWeight)
        }
    }
}

struct StatsSectionView: View {
    let trainings: [Training]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Stats")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            StatsRowView(trainings: trainings)
        }
    }
}

struct ExerciseAnalysisSectionView: View {
    let trainings: [Training]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Exercise Analysis")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ExerciseAnalysisView(trainings: trainings)
                .frame(height: 200)
        }
    }
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Training.date, order: .reverse) private var trainings: [Training]
    @Query(sort: \RunningSession.startTime, order: .reverse) private var runningSessions: [RunningSession]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    @Query private var goals: [Goals]
    
    @State private var showingGoalsSheet = false
    @State private var animateStats = false
    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedDate: Date = Date()
    @State private var showingRecordTraining = false
    @State private var showingLogTraining = false
    @State private var showingStartRun = false
    
    private var currentWeight: Double? {
        weightEntries.first?.weight
    }
    
    private var trainingsInSelectedRange: [Training] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeRange {
        case .week:
            // Get the start of the current week (Monday)
            let weekday = calendar.component(.weekday, from: now)
            let daysToSubtract = (weekday + 5) % 7 // Convert to Monday-based week (1 = Sunday, 2 = Monday, etc.)
            let startOfWeek = calendar.date(byAdding: .day, value: -daysToSubtract, to: now)!
            
            // Get the end of the current week (Sunday)
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
            
            return trainings.filter { training in
                training.date >= startOfWeek && training.date <= endOfWeek
            }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            return trainings.filter { $0.date >= monthAgo }
        case .year:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
            return trainings.filter { $0.date >= yearAgo }
        }
    }
    
    private var userGoals: Goals {
        if let existingGoals = goals.first {
            return existingGoals
        }
        let newGoals = Goals()
        modelContext.insert(newGoals)
        return newGoals
    }
    
    private var trainingProgress: Double {
        guard userGoals.targetTrainingsPerWeek > 0 else { return 0 }
        return Double(trainingsInSelectedRange.count) / Double(userGoals.targetTrainingsPerWeek)
    }
    
    private var runsThisWeek: Int {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let daysToSubtract = (weekday + 5) % 7
        let startOfWeek = calendar.date(byAdding: .day, value: -daysToSubtract, to: now)!
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
        
        return runningSessions.filter { run in
            run.startTime >= startOfWeek && run.startTime <= endOfWeek
        }.count
    }
    
    private var distanceThisWeek: Double {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let daysToSubtract = (weekday + 5) % 7
        let startOfWeek = calendar.date(byAdding: .day, value: -daysToSubtract, to: now)!
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
        
        return runningSessions
            .filter { run in
                run.startTime >= startOfWeek && run.startTime <= endOfWeek
            }
            .reduce(0.0) { $0 + $1.distanceInKm }
    }
    
    // Check for and recover any partial run data from crash
    private func checkForUnrecoveredRun() {
        guard UserDefaults.standard.bool(forKey: "hasUnrecoveredRun"),
              let runBackup = UserDefaults.standard.dictionary(forKey: "runningSessionBackup") else {
            return
        }
        
        // Show alert to user about recovered run
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Try to recover the run data
            if let startTimeInterval = runBackup["startTime"] as? TimeInterval,
               let distance = runBackup["distance"] as? Double,
               let duration = runBackup["duration"] as? TimeInterval,
               let averagePace = runBackup["averagePace"] as? Double,
               let calories = runBackup["calories"] as? Int,
               let elevationGain = runBackup["elevationGain"] as? Double,
               let elevationLoss = runBackup["elevationLoss"] as? Double {
                
                let startTime = Date(timeIntervalSince1970: startTimeInterval)
                
                // Create a running session from recovered data
                let session = RunningSession(
                    startTime: startTime,
                    endTime: startTime.addingTimeInterval(duration),
                    duration: duration,
                    distance: distance,
                    averagePace: averagePace,
                    calories: calories,
                    elevationGain: elevationGain,
                    elevationLoss: elevationLoss,
                    maxSpeed: 0,
                    averageSpeed: duration > 0 ? distance / duration : 0
                )
                
                session.notes = "Note: This run was recovered after the app crashed or was closed unexpectedly. Some GPS data may be missing."
                
                // Save recovered session
                do {
                    modelContext.insert(session)
                    try modelContext.save()
                    print("Recovered run saved successfully")
                    
                    // Clear backup flags
                    UserDefaults.standard.removeObject(forKey: "runningSessionBackup")
                    UserDefaults.standard.removeObject(forKey: "hasUnrecoveredRun")
                } catch {
                    print("Error saving recovered run: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func calculateWeightProgress(current: Double, starting: Double, target: Double) -> Double {
        if current > target {
            return 1.0 - ((current - target) / (starting - target))
        } else {
            return (current - starting) / (target - starting)
        }
    }
    
    private var trainingActionsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Start Training Button (Strava Orange)
                ActionCard(
                    icon: "record.circle.fill",
                    title: "Start Training",
                    gradient: LinearGradient(
                        colors: [Color(red: 1.0, green: 0.32, blue: 0.13), Color(red: 0.88, green: 0.20, blue: 0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    iconColor: .white,
                    action: { showingRecordTraining = true }
                )
                
                // Log Training Button (Deep Blue)
                ActionCard(
                    icon: "pencil.and.list.clipboard",
                    title: "Log Training",
                    gradient: LinearGradient(
                        colors: [Color(red: 0.16, green: 0.47, blue: 0.71), Color(red: 0.11, green: 0.35, blue: 0.57)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    iconColor: .white,
                    action: { showingLogTraining = true }
                )
                
                // Start a Run Button (Turquoise/Teal)
                ActionCard(
                    icon: "figure.run",
                    title: "Start Run",
                    gradient: LinearGradient(
                        colors: [Color(red: 0.18, green: 0.71, blue: 0.58), Color(red: 0.12, green: 0.58, blue: 0.47)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    iconColor: .white,
                    action: { showingStartRun = true }
                )
            }
            .padding(.horizontal)
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 20) {
            trainingActionsSection
            
            GoalsSectionView(goals: userGoals, trainingProgress: trainingProgress, runsThisWeek: runsThisWeek, distanceThisWeek: distanceThisWeek, currentWeight: currentWeight, showingGoalsSheet: $showingGoalsSheet)
                .frame(maxWidth: .infinity, alignment: .center)
            TrainingTrendsView(trainings: trainings, weeklyTarget: userGoals.targetTrainingsPerWeek)
        }
        .padding(.vertical)
    }
    
    var body: some View {
        ScrollView {
            mainContent
                .padding(.bottom, 120) // Extra padding to ensure calendar isn't hidden by tab bar
        }
        .sheet(isPresented: $showingGoalsSheet) {
            GoalsEditView(goals: userGoals)
        }
        .sheet(isPresented: $showingLogTraining) {
            TrainingEditView()
        }
        .fullScreenCover(isPresented: $showingRecordTraining) {
            RecordTrainingView()
        }
        .fullScreenCover(isPresented: $showingStartRun) {
            RunningView()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                animateStats = true
            }
            
            // Check for unrecovered run data
            checkForUnrecoveredRun()
        }
        .onChange(of: trainings) { oldValue, newValue in
            updateWidgetData()
        }
        .onChange(of: weightEntries) { oldValue, newValue in
            updateWidgetData()
        }
        .onChange(of: goals) { oldValue, newValue in
            updateWidgetData()
        }
    }
    
    private func updateWidgetData() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.tornado-studios.climbingtracker99") else {
            print("Failed to get container URL")
            return
        }
        
        // Ensure the container directory exists
        do {
            try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        } catch {
            print("Failed to create container directory: \(error.localizedDescription)")
            return
        }
        
        let fileURL = containerURL.appendingPathComponent("widgetData.json")
        
        // Calculate trainings in last 7 days
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let recentTrainings = trainings.filter { $0.date >= sevenDaysAgo }.count
        
        // Process exercise goals
        var exerciseGoalsData: [[String: Any]] = []
        for goal in userGoals.exerciseGoals {
            var progress: Double = 0
            var details: String = ""
            
            if goal.exerciseType == .hangboarding {
                let currentDuration = goal.getCurrentValue("duration") ?? 0
                let targetDuration = goal.getTargetValue("duration") ?? 1
                progress = currentDuration / targetDuration
                
                var detailsArray: [String] = []
                if let gripTypeString = goal.getParameterValue("gripType") as String?,
                   let gripType = GripType(rawValue: gripTypeString) {
                    detailsArray.append(gripType.rawValue)
                }
                if let edgeSize = goal.getParameterValue("edgeSize") as Int? {
                    detailsArray.append("\(edgeSize)mm")
                }
                if let duration = goal.getTargetValue("duration") {
                    detailsArray.append("\(Int(duration))s")
                }
                if let weight = goal.getTargetValue("addedWeight"), weight > 0 {
                    detailsArray.append("+\(weight)kg")
                }
                details = detailsArray.joined(separator: " • ")
            } else if goal.exerciseType == .repeaters {
                let currentReps = goal.getCurrentValue("repetitions") ?? 0
                let targetReps = goal.getTargetValue("repetitions") ?? 1
                progress = currentReps / targetReps
                
                var detailsArray: [String] = []
                if let duration = goal.getTargetValue("duration") {
                    detailsArray.append("\(Int(duration))s")
                }
                if let reps = goal.getTargetValue("repetitions") {
                    detailsArray.append("\(Int(reps)) reps")
                }
                if let sets = goal.getTargetValue("sets") {
                    detailsArray.append("\(Int(sets)) sets")
                }
                if let weight = goal.getTargetValue("addedWeight"), weight > 0 {
                    detailsArray.append("+\(weight)kg")
                }
                details = detailsArray.joined(separator: " • ")
            }
            
            exerciseGoalsData.append([
                "type": goal.exerciseType.rawValue,
                "progress": progress,
                "details": details
            ])
        }
        
        let data = [
            "trainingsLast7Days": recentTrainings,
            "targetTrainingsPerWeek": userGoals.targetTrainingsPerWeek,
            "currentWeight": currentWeight ?? 0.0,
            "targetWeight": userGoals.targetWeight,
            "startingWeight": userGoals.startingWeight ?? 0.0,
            "exerciseGoals": exerciseGoalsData
        ] as [String : Any]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            try jsonData.write(to: fileURL, options: .atomicWrite)
            
            // Force a widget update
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Failed to update widget data: \(error.localizedDescription)")
        }
    }
}

// MARK: - Modern Action Card Component

struct ActionCard: View {
    let icon: String
    let title: String
    let gradient: LinearGradient
    let iconColor: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                // Icon with circular background
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .blur(radius: 1)
                    
                    // Inner circle
                    Circle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 56, height: 56)
                    
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(iconColor)
                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                }
                
                // Title
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 10)
            .background(
                ZStack {
                    // Main gradient
                    RoundedRectangle(cornerRadius: 20)
                        .fill(gradient)
                    
                    // Subtle inner highlight
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.1), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .opacity(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
} 