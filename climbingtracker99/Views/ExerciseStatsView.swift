import SwiftUI
import Charts

struct ExerciseStatsView: View {
    let trainings: [Training]
    
    private var exerciseCounts: [(type: ExerciseType, count: Int)] {
        let allExercises = trainings.flatMap { $0.recordedExercises }
        let counts = Dictionary(grouping: allExercises, by: { $0.exercise.type })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        return counts.map { (type: $0.key, count: $0.value) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Exercise Records")
                .font(.headline)
                .padding(.horizontal)
            
            Chart {
                ForEach(exerciseCounts, id: \.type) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Exercise", item.type.rawValue)
                    )
                    .foregroundStyle(by: .value("Exercise", item.type.rawValue))
                }
            }
            .chartXAxis {
                AxisMarks(position: .top)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 150)
            .padding()
        }
    }
}

struct ExerciseStatsCard: View {
    let exerciseType: ExerciseType
    let trainings: [Training]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(exerciseType.rawValue)
                .font(.headline)
            
            switch exerciseType {
            case .hangboarding:
                HangboardingStats(trainings: trainings)
            case .repeaters:
                RepeatersStats(trainings: trainings)
            case .limitBouldering:
                LimitBoulderingStats(trainings: trainings)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .frame(width: 300)
    }
}

struct HangboardingStats: View {
    let trainings: [Training]
    
    var body: some View {
        VStack(alignment: .leading) {
            ForEach(GripType.allCases, id: \.self) { grip in
                let maxWeight = trainings.flatMap { $0.recordedExercises }
                    .filter { $0.exercise.type == .hangboarding && $0.gripType == grip }
                    .compactMap { $0.addedWeight }
                    .max()
                
                if let maxWeight = maxWeight {
                    HStack {
                        Text(grip.rawValue)
                            .font(.subheadline)
                        Spacer()
                        Text("+\(maxWeight)kg")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

struct RepeatersStats: View {
    let trainings: [Training]
    
    var body: some View {
        VStack(alignment: .leading) {
            let maxSets = trainings.flatMap { $0.recordedExercises }
                .filter { $0.exercise.type == .repeaters }
                .compactMap { $0.sets }
                .max()
            
            if let maxSets = maxSets {
                HStack {
                    Text("Max Sets")
                        .font(.subheadline)
                    Spacer()
                    Text("\(maxSets)")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct LimitBoulderingStats: View {
    let trainings: [Training]
    
    var body: some View {
        VStack(alignment: .leading) {
            let maxGrade = trainings.flatMap { $0.recordedExercises }
                .filter { $0.exercise.type == .limitBouldering }
                .compactMap { $0.grade }
                .max()
            
            if let maxGrade = maxGrade {
                HStack {
                    Text("Max Grade")
                        .font(.subheadline)
                    Spacer()
                    Text(maxGrade)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
    }
} 