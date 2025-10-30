import SwiftUI
import SwiftData

struct GoalsRowView: View {
    let goals: Goals
    let trainingProgress: Double
    
    var body: some View {
        let items: [(Double, String, String, Color, String)] = {
            var data: [(Double, String, String, Color, String)] = []
            data.append((trainingProgress, "Training", "\(goals.targetTrainingsPerWeek)/week", .blue, "Weekly target"))
            if let startingWeight = goals.startingWeight, goals.targetWeight > 0 {
                let progress = (goals.targetWeight - startingWeight) / (goals.targetWeight - startingWeight)
                data.append((progress, "Weight", String(format: "%.1f kg", goals.targetWeight), .green, "Target weight"))
            }
            for goal in goals.exerciseGoals {
                let progress = calculateProgress(for: goal)
                let details = getExerciseDetails(for: goal)
                data.append((progress, goal.exerciseType.rawValue, String(format: "%.0f%%", progress * 100), .orange, details))
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
                    details: item.4
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
                Text(String(format: "%.0f%%", max(0, min(1, progress)) * 100))
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(color)
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
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .cornerRadius(12)
    }
} 