import SwiftUI
import Charts

struct ExerciseAnalysisView: View {
    let trainings: [Training]
    
    private var exerciseCounts: [ExerciseType: Int] {
        var counts: [ExerciseType: Int] = [:]
        for training in trainings {
            for exercise in training.recordedExercises {
                counts[exercise.exercise.type, default: 0] += 1
            }
        }
        return counts
    }
    
    private var sortedExercises: [(ExerciseType, Int)] {
        exerciseCounts.sorted { $0.value > $1.value }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(sortedExercises, id: \.0) { exercise, count in
                        ExerciseCard(
                            exerciseType: exercise,
                            count: count
                        )
                    }
                }
                .padding(.horizontal)
            }
            ExerciseParameterTrendsView(trainings: trainings)
                .padding(.horizontal)
        }
    }
}

struct ExerciseCard: View {
    let exerciseType: ExerciseType
    let count: Int
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Image(exerciseType.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
            
            Text("\(count)")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(exerciseType.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 100, height: 100)
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(15)
    }
} 

private struct ExerciseParameterTrendsView: View {
    let trainings: [Training]
    @State private var selectedExercise: ExerciseType = .hangboarding
    @State private var selectedParameter: String = "duration"
    
    private var parameterOptions: [String] {
        switch selectedExercise {
        case .hangboarding: return ["duration", "addedWeight", "edgeSize"]
        case .repeaters: return ["duration", "repetitions", "sets", "addedWeight"]
        case .limitBouldering: return ["attempts"]
        case .nxn: return ["sets"]
        case .boulderCampus: return ["moves", "sets", "restDuration"]
        case .deadlifts: return ["weight", "repetitions", "sets"]
        case .shoulderLifts: return ["weight", "repetitions", "sets"]
        case .pullups: return ["addedWeight", "repetitions", "sets"]
        case .boardClimbing: return ["routes"]
        case .edgePickups: return ["duration", "sets", "addedWeight", "edgeSize"]
        case .flexibility: return []
        case .running: return ["distance", "minutes"]
        case .warmup: return ["recordedDuration", "duration"]
        }
    }
    
    private func value(for rec: RecordedExercise, key: String) -> Double? {
        switch key {
        case "duration": return rec.duration.flatMap { Double($0) }
        case "repetitions": return rec.repetitions.flatMap { Double($0) }
        case "sets": return rec.sets.flatMap { Double($0) }
        case "addedWeight": return rec.addedWeight.flatMap { Double($0) }
        case "restDuration": return rec.restDuration.flatMap { Double($0) }
        case "routes": return rec.routes.flatMap { Double($0) }
        case "attempts": return rec.attempts.flatMap { Double($0) }
        case "moves": return rec.moves.flatMap { Double($0) }
        case "weight": return rec.weight.flatMap { Double($0) }
        case "edgeSize": return rec.edgeSize.flatMap { Double($0) }
        case "distance": return rec.distance
        case "minutes":
            let h = rec.hours ?? 0
            let m = rec.minutes ?? 0
            return Double(h * 60 + m)
        case "recordedDuration": return rec.recordedDuration.flatMap { Double($0) }
        default: return nil
        }
    }
    
    private var dataPoints: [(date: Date, value: Double)] {
        var points: [(Date, Double)] = []
        for t in trainings.sorted(by: { $0.date < $1.date }) {
            for rec in t.recordedExercises where rec.exercise.type == selectedExercise {
                if let v = value(for: rec, key: selectedParameter) {
                    points.append((t.date, v))
                }
            }
        }
        return points
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Picker("Exercise", selection: $selectedExercise) {
                    ForEach(ExerciseType.allCases, id: \.self) { et in
                        Text(et.rawValue).tag(et)
                    }
                }
                .pickerStyle(.menu)
                
                Picker("Parameter", selection: $selectedParameter) {
                    ForEach(parameterOptions, id: \.self) { key in
                        Text(key.capitalized).tag(key)
                    }
                }
                .pickerStyle(.menu)
            }
            
            if dataPoints.isEmpty {
                Text("No data for selection")
                    .foregroundColor(.secondary)
                    .font(.footnote)
            } else {
                Chart {
                    ForEach(Array(dataPoints.enumerated()), id: \.offset) { _, point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                    }
                }
                .frame(height: 220)
            }
        }
    }
}