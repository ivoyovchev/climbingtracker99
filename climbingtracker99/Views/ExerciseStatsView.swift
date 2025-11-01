import SwiftUI
import Charts

struct ExerciseStatsView: View {
    let trainings: [Training]
    
    private struct ExerciseKey: Hashable {
        let type: ExerciseType
        let focus: TrainingFocus
    }
    
    private var exerciseCounts: [(key: ExerciseKey, count: Int)] {
        let allExercises = trainings.flatMap { $0.recordedExercises }
        let counts = Dictionary(grouping: allExercises) { exercise in
            ExerciseKey(type: exercise.exercise.type, focus: exercise.exercise.focus ?? .strength)
        }
        .mapValues { $0.count }
        .sorted { $0.value > $1.value }
        
        return counts.map { (key: $0.key, count: $0.value) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Exercise Records")
                .font(.headline)
                .padding(.horizontal)
            
            Chart {
                ForEach(exerciseCounts, id: \.key) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Exercise", "\(item.key.type.rawValue) - \(item.key.focus.rawValue)")
                    )
                    .foregroundStyle(by: .value("Focus", item.key.focus.rawValue))
                }
            }
            .chartXAxis {
                AxisMarks(position: .top)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 200)
            .padding()
        }
    }
}

struct ExerciseStatsCard: View {
    let exerciseType: ExerciseType
    let focus: TrainingFocus
    let trainings: [Training]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(exerciseType.rawValue)
                    .font(.headline)
                Spacer()
                Text(focus.rawValue)
                    .font(.subheadline)
                    .foregroundColor(focus.color)
            }
            
            switch exerciseType {
            case .hangboarding:
                HangboardingStats(trainings: trainings, focus: focus)
            case .repeaters:
                RepeatersStats(trainings: trainings, focus: focus)
            case .limitBouldering:
                LimitBoulderingStats(trainings: trainings, focus: focus)
            case .nxn:
                NxNStats(trainings: trainings, focus: focus)
            case .boulderCampus:
                BoulderCampusStats(trainings: trainings, focus: focus)
            case .deadlifts:
                DeadliftsStats(trainings: trainings, focus: focus)
            case .shoulderLifts:
                ShoulderLiftsStats(trainings: trainings, focus: focus)
            case .pullups:
                PullupsStats(trainings: trainings, focus: focus)
            case .boardClimbing:
                BoardClimbingStats(trainings: trainings, focus: focus)
            case .edgePickups:
                EdgePickupsStats(trainings: trainings, focus: focus)
            case .flexibility:
                FlexibilityStats(trainings: trainings, focus: focus)
            case .running:
                RunningStats(trainings: trainings, focus: focus)
            case .warmup:
                WarmupStats(trainings: trainings, focus: focus)
            case .circuit, .core, .campusing:
                // Basic stats for new exercise types
                BasicExerciseStats(trainings: trainings, exerciseType: exerciseType, focus: focus)
            case .benchmark:
                // Benchmarks have their own progress tracking system
                BasicExerciseStats(trainings: trainings, exerciseType: exerciseType, focus: focus)
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
    let focus: TrainingFocus
    
    var body: some View {
        VStack(alignment: .leading) {
            ForEach(GripType.allCases, id: \.self) { grip in
                let maxWeight = trainings.flatMap { $0.recordedExercises }
                    .filter { 
                        $0.exercise.type == .hangboarding && 
                        $0.exercise.focus == focus && 
                        $0.gripType == grip 
                    }
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
    let focus: TrainingFocus
    
    var body: some View {
        VStack(alignment: .leading) {
            let maxSets = trainings.flatMap { $0.recordedExercises }
                .filter { 
                    $0.exercise.type == .repeaters && 
                    $0.exercise.focus == focus 
                }
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
    let focus: TrainingFocus
    
    var body: some View {
        VStack(alignment: .leading) {
            let maxGrade = trainings.flatMap { $0.recordedExercises }
                .filter { 
                    $0.exercise.type == .limitBouldering && 
                    $0.exercise.focus == focus 
                }
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

struct NxNStats: View {
    let trainings: [Training]
    let focus: TrainingFocus
    
    var body: some View {
        VStack(alignment: .leading) {
            let maxGrade = trainings.flatMap { $0.recordedExercises }
                .filter { 
                    $0.exercise.type == .nxn && 
                    $0.exercise.focus == focus 
                }
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

struct BoulderCampusStats: View {
    let trainings: [Training]
    let focus: TrainingFocus
    
    var body: some View {
        VStack(alignment: .leading) {
            let maxMoves = trainings.flatMap { $0.recordedExercises }
                .filter { 
                    $0.exercise.type == .boulderCampus && 
                    $0.exercise.focus == focus 
                }
                .compactMap { $0.moves }
                .max()
            
            if let maxMoves = maxMoves {
                HStack {
                    Text("Max Moves")
                        .font(.subheadline)
                    Spacer()
                    Text("\(maxMoves)")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct DeadliftsStats: View {
    let trainings: [Training]
    let focus: TrainingFocus
    
    var body: some View {
        VStack(alignment: .leading) {
            let maxWeight = trainings.flatMap { $0.recordedExercises }
                .filter { 
                    $0.exercise.type == .deadlifts && 
                    $0.exercise.focus == focus 
                }
                .compactMap { $0.weight }
                .max()
            
            if let maxWeight = maxWeight {
                HStack {
                    Text("Max Weight")
                        .font(.subheadline)
                    Spacer()
                    Text("\(maxWeight)kg")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct ShoulderLiftsStats: View {
    let trainings: [Training]
    let focus: TrainingFocus
    
    var body: some View {
        VStack(alignment: .leading) {
            let maxWeight = trainings.flatMap { $0.recordedExercises }
                .filter { 
                    $0.exercise.type == .shoulderLifts && 
                    $0.exercise.focus == focus 
                }
                .compactMap { $0.weight }
                .max()
            
            if let maxWeight = maxWeight {
                HStack {
                    Text("Max Weight")
                        .font(.subheadline)
                    Spacer()
                    Text("\(maxWeight)kg")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct PullupsStats: View {
    let trainings: [Training]
    let focus: TrainingFocus
    
    var body: some View {
        VStack(alignment: .leading) {
            let maxWeight = trainings.flatMap { $0.recordedExercises }
                .filter { 
                    $0.exercise.type == .pullups && 
                    $0.exercise.focus == focus 
                }
                .compactMap { $0.addedWeight }
                .max()
            
            if let maxWeight = maxWeight {
                HStack {
                    Text("Max Added Weight")
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

struct BoardClimbingStats: View {
    let trainings: [Training]
    let focus: TrainingFocus
    
    var body: some View {
        VStack(alignment: .leading) {
            let maxGrade = trainings.flatMap { $0.recordedExercises }
                .filter { 
                    $0.exercise.type == .boardClimbing && 
                    $0.exercise.focus == focus 
                }
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

struct EdgePickupsStats: View {
    let trainings: [Training]
    let focus: TrainingFocus
    
    var body: some View {
        VStack(alignment: .leading) {
            let minEdgeSize = trainings.flatMap { $0.recordedExercises }
                .filter { 
                    $0.exercise.type == .edgePickups && 
                    $0.exercise.focus == focus 
                }
                .compactMap { $0.edgeSize }
                .min()
            
            if let minEdgeSize = minEdgeSize {
                HStack {
                    Text("Min Edge Size")
                        .font(.subheadline)
                    Spacer()
                    Text("\(minEdgeSize)mm")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct MaxHangsStats: View {
    let trainings: [Training]
    let focus: TrainingFocus
    
    var body: some View {
        VStack(alignment: .leading) {
            let minEdgeSize = trainings.flatMap { $0.recordedExercises }
                .filter { 
                    $0.exercise.type == .hangboarding && 
                    $0.exercise.focus == focus 
                }
                .compactMap { $0.edgeSize }
                .min()
            
            if let minEdgeSize = minEdgeSize {
                HStack {
                    Text("Min Edge Size")
                        .font(.subheadline)
                    Spacer()
                    Text("\(minEdgeSize)mm")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct FlexibilityStats: View {
    let trainings: [Training]
    let focus: TrainingFocus
    
    var body: some View {
        VStack(alignment: .leading) {
            let flexibilityAreas = trainings.flatMap { $0.recordedExercises }
                .filter { 
                    $0.exercise.type == .flexibility && 
                    $0.exercise.focus == focus 
                }
                .reduce(into: Set<String>()) { result, exercise in
                    if exercise.hamstrings { result.insert("Hamstrings") }
                    if exercise.hips { result.insert("Hips") }
                    if exercise.forearms { result.insert("Forearms") }
                    if exercise.legs { result.insert("Legs") }
                }
            
            if !flexibilityAreas.isEmpty {
                Text("Areas Worked:")
                    .font(.subheadline)
                ForEach(flexibilityAreas.sorted(), id: \.self) { area in
                    Text(area)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct RunningStats: View {
    let trainings: [Training]
    let focus: TrainingFocus
    
    var body: some View {
        VStack(alignment: .leading) {
            let maxDistance = trainings.flatMap { $0.recordedExercises }
                .filter { 
                    $0.exercise.type == .running && 
                    $0.exercise.focus == focus 
                }
                .compactMap { $0.distance }
                .max()
            
            let totalDuration = trainings.flatMap { $0.recordedExercises }
                .filter { 
                    $0.exercise.type == .running && 
                    $0.exercise.focus == focus 
                }
                .reduce(0) { total, exercise in
                    let hours = exercise.hours ?? 0
                    let minutes = exercise.minutes ?? 0
                    return total + (hours * 60 + minutes)
                }
            
            if let maxDistance = maxDistance {
                HStack {
                    Text("Max Distance")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.2f km", maxDistance))
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            if totalDuration > 0 {
                HStack {
                    Text("Total Duration")
                        .font(.subheadline)
                    Spacer()
                    Text("\(totalDuration / 60)h \(totalDuration % 60)m")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct WarmupStats: View {
    let trainings: [Training]
    let focus: TrainingFocus
    
    var body: some View {
        VStack(alignment: .leading) {
            let warmupExercises = trainings.flatMap { $0.recordedExercises }
                .filter { 
                    $0.exercise.type == .warmup && 
                    $0.exercise.focus == focus 
                }
            
            let durations = warmupExercises.compactMap { exercise -> Int? in
                if let recorded = exercise.recordedDuration {
                    return recorded
                } else if let duration = exercise.duration {
                    return duration * 60
                }
                return nil
            }
            
            let avgDuration = durations.isEmpty ? 0.0 : Double(durations.reduce(0, +)) / Double(durations.count)
            
            let allDetails = warmupExercises.flatMap { $0.selectedDetailOptions }
            let uniqueDetails = Set(allDetails)
            
            if !uniqueDetails.isEmpty {
                HStack {
                    Text("Detail Areas")
                        .font(.subheadline)
                    Spacer()
                    Text(uniqueDetails.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .lineLimit(2)
                }
            }
            
            if avgDuration > 0 {
                HStack {
                    Text("Avg Duration")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(avgDuration))s")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct BasicExerciseStats: View {
    let trainings: [Training]
    let exerciseType: ExerciseType
    let focus: TrainingFocus
    
    var body: some View {
        VStack(alignment: .leading) {
            let exercises = trainings.flatMap { $0.recordedExercises }
                .filter { 
                    $0.exercise.type == exerciseType && 
                    $0.exercise.focus == focus 
                }
            
            if !exercises.isEmpty {
                Text("Total Sessions: \(exercises.count)")
                    .font(.subheadline)
                
                let totalSets = exercises.compactMap({ $0.sets }).reduce(0, +)
                if totalSets > 0 {
                    HStack {
                        Text("Total Sets")
                            .font(.subheadline)
                        Spacer()
                        Text("\(totalSets)")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
                
                let totalDuration = exercises.compactMap({ $0.duration }).reduce(0, +)
                if totalDuration > 0 {
                    HStack {
                        Text("Total Duration")
                            .font(.subheadline)
                        Spacer()
                        Text("\(totalDuration)s")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
} 