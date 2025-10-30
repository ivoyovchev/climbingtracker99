import SwiftUI
import SwiftData

struct GoalsCircleView: View {
    let goals: Goals
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = size * 0.4
            
            ZStack {
                BackgroundCircle(size: size)
                MainGoalsView(goals: goals, size: size, center: center, radius: radius)
                ExerciseGoalsView(goals: goals, size: size, center: center, radius: radius)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct BackgroundCircle: View {
    let size: CGFloat
    
    var body: some View {
        Circle()
            .stroke(Color.gray.opacity(0.2), lineWidth: 20)
            .frame(width: size * 0.8, height: size * 0.8)
    }
}

struct MainGoalsView: View {
    let goals: Goals
    let size: CGFloat
    let center: CGPoint
    let radius: CGFloat
    
    var body: some View {
        Group {
            // Training frequency goal
            GoalCircle(
                progress: Double(goals.targetTrainingsPerWeek) / 7.0,
                title: "Training",
                subtitle: "\(goals.targetTrainingsPerWeek)/week",
                color: .blue,
                position: CGPoint(x: center.x - radius * 0.5, y: center.y - radius * 0.5),
                size: size * 0.3
            )
            
            // Weight goal
            if let startingWeight = goals.startingWeight, goals.targetWeight > 0 {
                let progress = (goals.targetWeight - startingWeight) / (goals.targetWeight - startingWeight)
                GoalCircle(
                    progress: progress,
                    title: "Weight",
                    subtitle: String(format: "%.1f kg", goals.targetWeight),
                    color: .green,
                    position: CGPoint(x: center.x + radius * 0.5, y: center.y - radius * 0.5),
                    size: size * 0.3
                )
            }
        }
    }
}

struct ExerciseGoalsView: View {
    let goals: Goals
    let size: CGFloat
    let center: CGPoint
    let radius: CGFloat
    
    var body: some View {
        ForEach(Array(goals.exerciseGoals.enumerated()), id: \.element.id) { index, goal in
            let angle = Double(index) * (2 * .pi / Double(goals.exerciseGoals.count))
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            
            let progress = calculateProgress(for: goal)
            
            GoalCircle(
                progress: progress,
                title: goal.exerciseType.rawValue,
                subtitle: String(format: "%.0f%%", progress * 100),
                color: .orange,
                position: CGPoint(x: x, y: y),
                size: size * 0.25
            )
        }
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
}

struct GoalCircle: View {
    let progress: Double
    let title: String
    let subtitle: String
    let color: Color
    let position: CGPoint
    let size: CGFloat
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 8)
                    .frame(width: size, height: size)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .position(position)
    }
} 