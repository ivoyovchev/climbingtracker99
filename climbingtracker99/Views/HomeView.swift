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
            
            GoalsRowView(goals: goals, trainingProgress: trainingProgress)
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
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    @Query private var goals: [Goals]
    
    @State private var showingGoalsSheet = false
    @State private var animateStats = false
    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedDate: Date = Date()
    
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
    
    private func calculateWeightProgress(current: Double, starting: Double, target: Double) -> Double {
        if current > target {
            return 1.0 - ((current - target) / (starting - target))
        } else {
            return (current - starting) / (target - starting)
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 20) {
            GoalsSectionView(goals: userGoals, trainingProgress: trainingProgress, showingGoalsSheet: $showingGoalsSheet)
                .frame(maxWidth: .infinity, alignment: .center)
            TrainingTrendsView(trainings: trainings, weeklyTarget: userGoals.targetTrainingsPerWeek)
        }
        .padding(.vertical)
    }
    
    var body: some View {
        ScrollView {
            mainContent
        }
        .sheet(isPresented: $showingGoalsSheet) {
            GoalsEditView(goals: userGoals)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                animateStats = true
            }
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
        
        // Calculate weight progress for widget
        let weightProgress = calculateWeightProgress(
            current: currentWeight ?? 0,
            starting: userGoals.startingWeight ?? 0,
            target: userGoals.targetWeight
        )
        
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