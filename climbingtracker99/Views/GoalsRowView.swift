import SwiftUI
import SwiftData

struct GoalsRowView: View {
    let goals: Goals
    let trainingProgress: Double
    let runsThisWeek: Int
    let distanceThisWeek: Double // in kilometers
    let currentWeight: Double? // Current weight from weight entries
    
    var runningProgress: Double {
        let target = goals.targetRunsPerWeek ?? 3
        guard target > 0 else { return 0 }
        return Double(runsThisWeek) / Double(target)
    }
    
    var distanceProgress: Double {
        let target = goals.targetDistancePerWeek ?? 20.0
        guard target > 0 else { return 0 }
        return distanceThisWeek / target
    }
    
    var body: some View {
        let items: [(Double, String, String, Color, String, String?)] = {
            var data: [(Double, String, String, Color, String, String?)] = []
            data.append((trainingProgress, "Training", "\(goals.targetTrainingsPerWeek)/week", .blue, "Weekly target", nil))
            
            // Running goals
            let targetRuns = goals.targetRunsPerWeek ?? 3
            let targetDistance = goals.targetDistancePerWeek ?? 20.0
            data.append((runningProgress, "Runs", "\(runsThisWeek)/\(targetRuns)", .green, "Per week", nil))
            data.append((distanceProgress, "Distance", String(format: "%.1f/%.0f km", distanceThisWeek, targetDistance), .purple, "Per week", nil))
            
            if let startingWeight = goals.startingWeight, 
               let currentWeight = currentWeight,
               goals.targetWeight > 0 {
                // Calculate weight progress based on whether we're losing or gaining weight
                let weightProgress: Double
                
                if startingWeight > goals.targetWeight {
                    // Losing weight (starting > target)
                    if currentWeight > startingWeight {
                        // Above starting weight - 0% progress
                        weightProgress = 0.0
                    } else if currentWeight < goals.targetWeight {
                        // Below target weight - 100% progress
                        weightProgress = 1.0
                    } else {
                        // Between starting and target
                        let totalRange = startingWeight - goals.targetWeight
                        let currentRange = startingWeight - currentWeight
                        weightProgress = currentRange / totalRange
                    }
                } else {
                    // Gaining weight (starting < target)
                    if currentWeight < startingWeight {
                        // Below starting weight - 0% progress
                        weightProgress = 0.0
                    } else if currentWeight > goals.targetWeight {
                        // Above target weight - 100% progress
                        weightProgress = 1.0
                    } else {
                        // Between starting and target
                        let totalRange = goals.targetWeight - startingWeight
                        let currentRange = currentWeight - startingWeight
                        weightProgress = currentRange / totalRange
                    }
                }
                
                // Calculate remaining weight (positive if need to lose more, negative if need to gain more)
                let remaining = currentWeight - goals.targetWeight
                let subtitle: String
                let centerText: String
                if abs(remaining) < 0.1 {
                    // Reached goal (within 0.1 kg)
                    subtitle = "Goal reached!"
                    centerText = "✓"
                } else if remaining > 0 {
                    // Need to lose more (current > target)
                    subtitle = String(format: "-%.1f kg", remaining)
                    centerText = String(format: "-%.1f", remaining)
                } else {
                    // Need to gain more (current < target)
                    subtitle = String(format: "+%.1f kg", abs(remaining))
                    centerText = String(format: "+%.1f", abs(remaining))
                }
                
                data.append((weightProgress, "Weight", subtitle, .orange, "Target: \(String(format: "%.1f", goals.targetWeight)) kg", centerText))
            }
            for goal in goals.exerciseGoals {
                let progress = calculateProgress(for: goal)
                let details = getExerciseDetails(for: goal)
                data.append((progress, goal.exerciseType.rawValue, String(format: "%.0f%%", progress * 100), .red, details, nil))
            }
            return data
        }()
        
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                GoalCard(
                    progress: item.0,
                    title: item.1,
                    subtitle: item.2,
                    color: item.3,
                    details: item.4,
                    centerText: item.5
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal)
    }
    
    private func calculateProgress(for goal: ExerciseGoal) -> Double {
        if goal.exerciseType == .hangboarding {
            let currentDuration = goal.getCurrentValue("duration") ?? 0
            let targetDuration = goal.getTargetValue("duration") ?? 1
            return currentDuration / targetDuration
        } else if goal.exerciseType == .repeaters {
            let currentReps = goal.getCurrentValue("repetitions") ?? 0
            let targetReps = goal.getTargetValue("repetitions") ?? 1
            return currentReps / targetReps
        }
        return 0
    }
    
    private func getExerciseDetails(for goal: ExerciseGoal) -> String {
        var details: [String] = []
        
        if goal.exerciseType == .hangboarding {
            if let gripTypeString = goal.getParameterValue("gripType") as String?,
               let gripType = GripType(rawValue: gripTypeString) {
                details.append("\(gripType.rawValue)")
            }
            if let edgeSize = goal.getParameterValue("edgeSize") as Int? {
                details.append("\(edgeSize)mm")
            }
            if let duration = goal.getTargetValue("duration") {
                details.append("\(Int(duration))s")
            }
            if let weight = goal.getTargetValue("addedWeight"), weight > 0 {
                details.append("+\(weight)kg")
            }
        } else if goal.exerciseType == .repeaters {
            if let duration = goal.getTargetValue("duration") {
                details.append("\(Int(duration))s")
            }
            if let reps = goal.getTargetValue("repetitions") {
                details.append("\(Int(reps)) reps")
            }
            if let sets = goal.getTargetValue("sets") {
                details.append("\(Int(sets)) sets")
            }
            if let weight = goal.getTargetValue("addedWeight"), weight > 0 {
                details.append("+\(weight)kg")
            }
        }
        
        return details.joined(separator: " • ")
    }
}

struct GoalCard: View {
    let progress: Double
    let title: String
    let subtitle: String
    let color: Color
    let details: String
    let centerText: String? // Optional custom text for center (e.g., weight in kg)
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 8)
                    .frame(width: 64, height: 64)
                Circle()
                    .trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))
                if let centerText = centerText {
                    VStack(spacing: 0) {
                        Text(centerText)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(color)
                        Text("kg")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(color.opacity(0.7))
                    }
                } else {
                    Text(String(format: "%.0f%%", max(0, min(1, progress)) * 100))
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(color)
                }
            }
            
            VStack(alignment: .center, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                Text(details)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
} 