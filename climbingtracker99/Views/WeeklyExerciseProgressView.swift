import SwiftUI
import SwiftData
import Charts

struct WeeklyExerciseProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Training.date, order: .reverse) private var trainings: [Training]
    
    private var currentWeekTrainings: [Training] {
        let calendar = Calendar.current
        let now = Date()
        
        // Get the start of the current week (Monday)
        let weekday = calendar.component(.weekday, from: now)
        let daysToSubtract = (weekday + 5) % 7 // Convert to Monday-based week
        let startOfWeek = calendar.date(byAdding: .day, value: -daysToSubtract, to: now)!
        
        // Get the end of the current week (Sunday)
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
        
        return trainings.filter { training in
            training.date >= startOfWeek && training.date <= endOfWeek
        }
    }
    
    private var exercisesThisWeek: [(exercise: RecordedExercise, date: Date)] {
        currentWeekTrainings.flatMap { training in
            training.recordedExercises.map { exercise in
                (exercise: exercise, date: training.date)
            }
        }
    }
    
    private var exercisesByType: [(type: ExerciseType, exercises: [RecordedExercise])] {
        let grouped = Dictionary(grouping: exercisesThisWeek) { $0.exercise.exercise.type }
        return grouped.map { (type: $0.key, exercises: $0.value.map { $0.exercise }) }
            .sorted { $0.exercises.count > $1.exercises.count }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("This Week's Exercises")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            if exercisesThisWeek.isEmpty {
                Text("No exercises recorded this week")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(exercisesByType, id: \.type) { group in
                            ExerciseTypeSection(type: group.type, exercises: group.exercises)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct ExerciseTypeSection: View {
    let type: ExerciseType
    let exercises: [RecordedExercise]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(type.rawValue)
                    .font(.headline)
                Spacer()
                Text("\(exercises.count) times")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            ForEach(exercises, id: \.exercise.id) { recordedExercise in
                ExerciseDetailRow(exercise: recordedExercise)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct ExerciseDetailRow: View {
    let exercise: RecordedExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch exercise.exercise.type {
            case .hangboarding:
                HangboardingRow(exercise: exercise)
            case .repeaters:
                RepeatersRow(exercise: exercise)
            case .limitBouldering:
                LimitBoulderingRow(exercise: exercise)
            case .nxn:
                NxNRow(exercise: exercise)
            case .boulderCampus:
                BoulderCampusRow(exercise: exercise)
            case .deadlifts:
                DeadliftsRow(exercise: exercise)
            case .shoulderLifts:
                ShoulderLiftsRow(exercise: exercise)
            case .pullups:
                PullupsRow(exercise: exercise)
            case .boardClimbing:
                BoardClimbingRow(exercise: exercise)
            case .edgePickups:
                EdgePickupsRow(exercise: exercise)
            case .flexibility:
                FlexibilityRow(exercise: exercise)
            case .running:
                RunningRow(exercise: exercise)
            case .warmup:
                WarmupRow(exercise: exercise)
            }
        }
        .padding(.vertical, 4)
    }
}

// Exercise-specific row views
struct HangboardingRow: View {
    let exercise: RecordedExercise
    
    var body: some View {
        HStack {
            if let gripType = exercise.gripType {
                Text(gripType.rawValue)
            }
            if let edgeSize = exercise.edgeSize {
                Text("\(edgeSize)mm")
            }
            if let duration = exercise.duration {
                Text("\(duration)s")
            }
            if let weight = exercise.addedWeight {
                Text("+\(weight)kg")
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
}

struct RepeatersRow: View {
    let exercise: RecordedExercise
    
    var body: some View {
        HStack {
            if let duration = exercise.duration {
                Text("\(duration)s")
            }
            if let reps = exercise.repetitions {
                Text("\(reps) reps")
            }
            if let sets = exercise.sets {
                Text("\(sets) sets")
            }
            if let weight = exercise.addedWeight {
                Text("+\(weight)kg")
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
}

struct LimitBoulderingRow: View {
    let exercise: RecordedExercise
    
    var body: some View {
        HStack {
            if let grade = exercise.grade {
                Text(grade)
            }
            if let routes = exercise.sets {
                Text("\(routes) routes")
            }
            if let attempts = exercise.repetitions {
                Text("\(attempts) attempts")
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
}

struct NxNRow: View {
    let exercise: RecordedExercise
    
    var body: some View {
        HStack {
            if let grade = exercise.grade {
                Text(grade)
            }
            if let routes = exercise.sets {
                Text("\(routes) routes")
            }
            if let sets = exercise.repetitions {
                Text("\(sets) sets")
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
}

struct BoulderCampusRow: View {
    let exercise: RecordedExercise
    
    var body: some View {
        HStack {
            if let moves = exercise.repetitions {
                Text("\(moves) moves")
            }
            if let sets = exercise.sets {
                Text("\(sets) sets")
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
}

struct DeadliftsRow: View {
    let exercise: RecordedExercise
    
    var body: some View {
        HStack {
            if let weight = exercise.addedWeight {
                Text("\(weight)kg")
            }
            if let reps = exercise.repetitions {
                Text("\(reps) reps")
            }
            if let sets = exercise.sets {
                Text("\(sets) sets")
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
}

struct ShoulderLiftsRow: View {
    let exercise: RecordedExercise
    
    var body: some View {
        HStack {
            if let weight = exercise.addedWeight {
                Text("\(weight)kg")
            }
            if let reps = exercise.repetitions {
                Text("\(reps) reps")
            }
            if let sets = exercise.sets {
                Text("\(sets) sets")
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
}

struct PullupsRow: View {
    let exercise: RecordedExercise
    
    var body: some View {
        HStack {
            if let weight = exercise.addedWeight {
                Text("\(weight)kg")
            }
            if let reps = exercise.repetitions {
                Text("\(reps) reps")
            }
            if let sets = exercise.sets {
                Text("\(sets) sets")
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
}

struct BoardClimbingRow: View {
    let exercise: RecordedExercise
    
    var body: some View {
        HStack {
            if let boardType = exercise.boardType {
                Text(boardType.rawValue)
            }
            if let grade = exercise.grade {
                Text(grade)
            }
            if let climbs = exercise.sets {
                Text("\(climbs) climbs")
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
}

struct EdgePickupsRow: View {
    let exercise: RecordedExercise
    
    var body: some View {
        HStack {
            if let edgeSize = exercise.edgeSize {
                Text("\(edgeSize)mm")
            }
            if let duration = exercise.duration {
                Text("\(duration)s")
            }
            if let sets = exercise.sets {
                Text("\(sets) sets")
            }
            if let weight = exercise.addedWeight {
                Text("+\(weight)kg")
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
}

struct MaxHangsRow: View {
    let exercise: RecordedExercise
    
    var body: some View {
        HStack {
            if let edgeSize = exercise.edgeSize {
                Text("\(edgeSize)mm")
            }
            if let duration = exercise.duration {
                Text("\(duration)s")
            }
            if let sets = exercise.sets {
                Text("\(sets) sets")
            }
            if let weight = exercise.addedWeight {
                Text("\(weight)kg")
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
}

struct FlexibilityRow: View {
    let exercise: RecordedExercise
    
    var body: some View {
        HStack {
            if exercise.hamstrings {
                Text("Hamstrings")
            }
            if exercise.hips {
                Text("Hips")
            }
            if exercise.forearms {
                Text("Forearms")
            }
            if exercise.legs {
                Text("Legs")
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
}

struct RunningRow: View {
    let exercise: RecordedExercise
    
    var body: some View {
        HStack {
            if let hours = exercise.hours,
               let minutes = exercise.minutes {
                Text("\(hours)h \(minutes)m")
            }
            if let distance = exercise.distance {
                Text("\(String(format: "%.2f", distance))km")
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
}

struct WarmupRow: View {
    let exercise: RecordedExercise
    
    var body: some View {
        HStack {
            if !exercise.selectedDetailOptions.isEmpty {
                Text(exercise.selectedDetailOptions.joined(separator: ", "))
            } else if let duration = exercise.recordedDuration {
                Text("\(duration)s")
            } else if let duration = exercise.duration {
                Text("\(duration) min")
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
}

#Preview {
    WeeklyExerciseProgressView()
        .modelContainer(for: [Training.self, Exercise.self])
} 