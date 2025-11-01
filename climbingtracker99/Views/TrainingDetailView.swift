import SwiftUI
import SwiftData
import AVKit

struct TrainingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let training: Training
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(training.date, style: .date)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text(training.date, style: .time)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Focus badge
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(training.focus.color)
                                    .frame(width: 10, height: 10)
                                Text(training.focus.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(training.focus.color)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(training.focus.color.opacity(0.15))
                            .cornerRadius(16)
                        }
                        
                        // Location and duration
                        HStack(spacing: 16) {
                            DetailStat(icon: training.location == .indoor ? "building.2.fill" : "tree.fill",
                                      title: training.location.rawValue,
                                      color: .blue)
                            
                            DetailStat(icon: "clock.fill",
                                      title: "\(training.duration) min",
                                      color: .green)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    
                    // Exercises Summary
                    if !training.recordedExercises.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Exercises Completed")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            ForEach(training.recordedExercises) { exercise in
                                ExerciseDetailCard(exercise: exercise)
                            }
                        }
                    }
                    
                    // Media section
                    if !training.media.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Media")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(training.media) { media in
                                        MediaCard(media: media)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Notes
                    if !training.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notes")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            Text(training.notes)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Training Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct DetailStat: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
        .cornerRadius(12)
    }
}

struct ExerciseDetailCard: View {
    let exercise: RecordedExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Exercise image
                Image(exercise.exercise.type.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.exercise.type.displayName)
                        .font(.headline)
                    
                    if let focus = exercise.exercise.focus {
                        Text(focus.rawValue)
                            .font(.caption)
                            .foregroundColor(focus.color)
                    }
                }
                
                Spacer()
            }
            
            // Exercise details based on type
            RecordedExerciseDetailsView(exercise: exercise)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct RecordedExerciseDetailsView: View {
    let exercise: RecordedExercise
    
    // Helper to format duration - convert seconds to minutes if > 60
    private func formatDuration(_ seconds: Int) -> String {
        if seconds >= 60 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds > 0 {
                return "\(minutes)m \(remainingSeconds)s"
            } else {
                return "\(minutes) min"
            }
        } else {
            return "\(seconds)s"
        }
    }
    
    // Campusing sets view - parses notes for set details
    @ViewBuilder
    private var campusingSetsView: some View {
        if let notes = exercise.notes, !notes.isEmpty {
            let setsDetail = String(notes.dropFirst("Campusing: ".count))
            let sets = Array(setsDetail.split(separator: ";"))
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Sets Breakdown")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                ForEach(sets.indices, id: \.self) { index in
                    Text(sets[index].trimmingCharacters(in: .whitespaces))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch exercise.exercise.type {
            case .hangboarding:
                if let grip = exercise.gripType,
                   let edgeSize = exercise.edgeSize,
                   let sets = exercise.sets {
                    DetailRow(label: "Grip", value: grip.rawValue)
                    DetailRow(label: "Edge Size", value: "\(edgeSize)mm")
                    if let duration = exercise.recordedDuration ?? exercise.duration {
                        DetailRow(label: "Duration", value: formatDuration(duration))
                    }
                    DetailRow(label: "Sets", value: "\(sets)")
                    if let weight = exercise.addedWeight, weight > 0 {
                        DetailRow(label: "Added Weight", value: "\(weight)kg")
                    }
                    
                    // Show detailed sets if maxHangsSetsData exists
                    if !exercise.maxHangsSetsData.isEmpty {
                        if let sets = parseMaxHangsSets() {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Sets Breakdown")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                                    HStack {
                                        Text("Set \(index + 1)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(set.duration)s × \(set.edgeSize)mm")
                                            .font(.caption)
                                        if set.addedWeight > 0 {
                                            Text("+\(set.addedWeight)kg")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                
            case .repeaters:
                if let duration = exercise.duration,
                   let reps = exercise.repetitions,
                   let sets = exercise.sets {
                    DetailRow(label: "Hang Time", value: formatDuration(duration))
                    DetailRow(label: "Repetitions", value: "\(reps)")
                    DetailRow(label: "Sets", value: "\(sets)")
                    if let weight = exercise.addedWeight, weight > 0 {
                        DetailRow(label: "Added Weight", value: "\(weight)kg")
                    }
                    
                    // Show detailed sets if repeatersSetsData exists
                    if !exercise.repeatersSetsData.isEmpty {
                        if let sets = parseRepeatersSets() {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Sets Breakdown")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                                    HStack {
                                        Text("Set \(index + 1)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(set.hangTime)s hang / \(set.restTime)s rest")
                                            .font(.caption)
                                        Text("× \(set.repeats) reps")
                                            .font(.caption)
                                        if set.addedWeight > 0 {
                                            Text("+\(set.addedWeight)kg")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                
            case .edgePickups:
                if let duration = exercise.duration,
                   let sets = exercise.sets {
                    DetailRow(label: "Hang Time", value: formatDuration(duration))
                    DetailRow(label: "Sets", value: "\(sets)")
                    if let edgeSize = exercise.edgeSize {
                        DetailRow(label: "Edge Size", value: "\(edgeSize)mm")
                    }
                    if let grip = exercise.gripType {
                        DetailRow(label: "Grip Type", value: grip.rawValue)
                    }
                    if let weight = exercise.addedWeight, weight > 0 {
                        DetailRow(label: "Added Weight", value: "\(weight)kg")
                    }
                    
                    // Show detailed sets if edgePickupsSetsData exists
                    if !exercise.edgePickupsSetsData.isEmpty {
                        if let sets = parseEdgePickupsSets() {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Sets Breakdown")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                                    HStack {
                                        Text("Set \(index + 1)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(set.hangTime)s / \(set.restTime)s × \(set.repeats)")
                                            .font(.caption)
                                        Text(set.gripType)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if set.addedWeight > 0 {
                                            Text("+\(set.addedWeight)kg")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                
            case .running:
                if let distance = exercise.distance {
                    DetailRow(label: "Distance", value: String(format: "%.2f km", distance))
                }
                if let hours = exercise.hours, let minutes = exercise.minutes {
                    DetailRow(label: "Duration", value: "\(hours)h \(minutes)m")
                }
                if let recordedDuration = exercise.recordedDuration {
                    DetailRow(label: "Recorded Duration", value: formatDuration(recordedDuration))
                }
                
            case .pullups:
                // Show detailed sets if pullupSetsData exists
                if !exercise.pullupSetsData.isEmpty {
                    if let sets = parsePullupSets() {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sets Breakdown")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                                HStack {
                                    Text("Set \(index + 1)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(set.reps) reps")
                                        .font(.caption)
                                    if set.weight > 0 {
                                        Text("+\(set.weight)kg")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if set.restDuration > 0 {
                                        Text("(\(set.restDuration)s rest)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                } else if let reps = exercise.repetitions, let sets = exercise.sets {
                    DetailRow(label: "Reps", value: "\(reps)")
                    DetailRow(label: "Sets", value: "\(sets)")
                    if let weight = exercise.addedWeight, weight > 0 {
                        DetailRow(label: "Added Weight", value: "\(weight)kg")
                    }
                }
                
            case .deadlifts:
                // Show detailed sets if deadliftsSetsData exists
                if !exercise.deadliftsSetsData.isEmpty {
                    if let sets = parseDeadliftSets() {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sets Breakdown")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                                HStack {
                                    Text("Set \(index + 1)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(set.reps) reps × \(set.weight)kg")
                                        .font(.caption)
                                    if set.restDuration > 0 {
                                        Text("(\(set.restDuration)s rest)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                } else if let reps = exercise.repetitions, let sets = exercise.sets {
                    DetailRow(label: "Reps", value: "\(reps)")
                    DetailRow(label: "Sets", value: "\(sets)")
                    if let weight = exercise.weight {
                        DetailRow(label: "Weight", value: "\(weight)kg")
                    }
                }
                
            case .shoulderLifts:
                // Show detailed sets if shoulderLiftsSetsData exists
                if !exercise.shoulderLiftsSetsData.isEmpty {
                    if let sets = parseShoulderLiftSets() {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sets Breakdown")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                                HStack {
                                    Text("Set \(index + 1)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(set.reps) reps × \(set.weight)kg")
                                        .font(.caption)
                                    if set.restDuration > 0 {
                                        Text("(\(set.restDuration)s rest)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                } else if let reps = exercise.repetitions, let sets = exercise.sets {
                    DetailRow(label: "Reps", value: "\(reps)")
                    DetailRow(label: "Sets", value: "\(sets)")
                    if let weight = exercise.weight {
                        DetailRow(label: "Weight", value: "\(weight)kg")
                    }
                }
                
            case .boardClimbing:
                // Show detailed routes if boardClimbingRoutesData exists
                if !exercise.boardClimbingRoutesData.isEmpty {
                    if let routes = parseBoardClimbingRoutes() {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Routes")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            ForEach(routes) { route in
                                HStack {
                                    Text(route.boardType)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("Grade: \(route.grade)")
                                        .font(.caption)
                                    Text("\(route.tries) tries")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if route.sent {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                } else {
                    // Fallback to basic info if no detailed data
                    if let boardType = exercise.boardType {
                        DetailRow(label: "Board Type", value: boardType.rawValue)
                    }
                    if let grade = exercise.grade {
                        DetailRow(label: "Grade", value: grade)
                    }
                    if let routes = exercise.routes {
                        DetailRow(label: "Routes", value: "\(routes)")
                    }
                    if let attempts = exercise.attempts {
                        DetailRow(label: "Attempts", value: "\(attempts)")
                    }
                }
                
            case .limitBouldering:
                // Show detailed routes if limitBoulderingRoutesData exists
                if !exercise.limitBoulderingRoutesData.isEmpty {
                    if let routes = parseLimitBoulderingRoutes() {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Boulders")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            ForEach(routes) { route in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(route.boulderType)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text("Grade: \(route.grade)")
                                            .font(.caption)
                                        Text("\(route.tries) tries")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if route.sent {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                    }
                                    if let name = route.name, !name.isEmpty {
                                        Text(name)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .italic()
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                } else {
                    // Fallback to basic info
                    if let grade = exercise.grade {
                        DetailRow(label: "Grade", value: grade)
                    }
                    if let routes = exercise.routes {
                        DetailRow(label: "Routes", value: "\(routes)")
                    }
                    if let attempts = exercise.attempts {
                        DetailRow(label: "Attempts", value: "\(attempts)")
                    }
                }
                
            case .nxn:
                if let routes = exercise.routes,
                   let sets = exercise.sets {
                    DetailRow(label: "Problems per Set", value: "\(routes)")
                    DetailRow(label: "Sets", value: "\(sets)")
                }
                
                // Show detailed sets if nxnSetsData exists
                if !exercise.nxnSetsData.isEmpty {
                    if let sets = parseNxNSets() {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sets Breakdown")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text("Set \(index + 1)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Spacer()
                                        if set.completed {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                        if set.restDuration > 0 {
                                            Text("\(set.restDuration)s rest")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    if !set.grades.isEmpty {
                                        Text("Grades: \(set.grades.joined(separator: ", "))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                
            case .boulderCampus:
                if let sets = exercise.sets {
                    DetailRow(label: "Sets", value: "\(sets)")
                }
                
                // Show detailed sets if boulderCampusSetsData exists
                if !exercise.boulderCampusSetsData.isEmpty {
                    if let sets = parseBoulderCampusSets() {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sets Breakdown")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                                HStack {
                                    Text("Set \(index + 1)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(set.moves) moves")
                                        .font(.caption)
                                    if set.restDuration > 0 {
                                        Text("(\(set.restDuration)s rest)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                
            case .campusing:
                if let sets = exercise.sets {
                    DetailRow(label: "Sets", value: "\(sets)")
                }
                if let edgeSize = exercise.edgeSize {
                    DetailRow(label: "Edge Size", value: "\(edgeSize)mm")
                }
                if let rest = exercise.restDuration {
                    DetailRow(label: "Rest Time", value: formatDuration(rest))
                }
                
                // Campusing stores detailed set data in notes
                if let notes = exercise.notes, !notes.isEmpty, notes.hasPrefix("Campusing:") {
                    campusingSetsView
                }
                
            case .circuit:
                // Use recordedDuration if available (for recorded exercises)
                if let duration = exercise.recordedDuration ?? exercise.duration {
                    DetailRow(label: "Duration", value: formatDuration(duration))
                }
                if let sets = exercise.sets {
                    DetailRow(label: "Sets", value: "\(sets)")
                }
                if let moves = exercise.moves {
                    DetailRow(label: "Moves per Set", value: "\(moves)")
                }
                if let grade = exercise.grade {
                    DetailRow(label: "Difficulty", value: grade)
                }
                if let rest = exercise.restDuration {
                    DetailRow(label: "Rest Time", value: formatDuration(rest))
                }
                
                // Circuit stores detailed data in notes
                if let notes = exercise.notes, !notes.isEmpty, (notes.hasPrefix("Circuit:") || notes.hasPrefix("Time Based Circuit:")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Workout Details")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                
            case .core:
                if let duration = exercise.duration {
                    DetailRow(label: "Training Time", value: formatDuration(duration))
                }
                if let sets = exercise.sets {
                    DetailRow(label: "Sets", value: "\(sets)")
                }
                if let rest = exercise.restDuration {
                    DetailRow(label: "Rest Time", value: formatDuration(rest))
                }
                
            case .flexibility, .warmup:
                // Use recordedDuration if available (for recorded exercises)
                if let duration = exercise.recordedDuration ?? exercise.duration {
                    DetailRow(label: "Duration", value: formatDuration(duration))
                }
                
                // Show selected areas if available
                if !exercise.selectedDetailOptions.isEmpty {
                    DetailRow(label: "Areas", value: exercise.selectedDetailOptions.joined(separator: ", "))
                }
                
                // Flexibility-specific fields
                if exercise.hamstrings {
                    DetailRow(label: "Hamstrings", value: "Yes")
                }
                if exercise.hips {
                    DetailRow(label: "Hips", value: "Yes")
                }
                if exercise.forearms {
                    DetailRow(label: "Forearms", value: "Yes")
                }
                if exercise.legs {
                    DetailRow(label: "Legs", value: "Yes")
                }
                
            case .benchmark:
                // Show benchmark results if available
                if !exercise.benchmarkResultsData.isEmpty {
                    if let results = parseBenchmarkResults() {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Benchmark Results")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                                if let type = BenchmarkType(rawValue: result.benchmarkType) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(type.displayName)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        HStack {
                                            Text(String(format: "%.1f", result.value1))
                                                .font(.caption)
                                            Text(type.unit)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            if let value2 = result.value2 {
                                                Spacer()
                                                Text("R: \(String(format: "%.1f", value2))")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                } else {
                    Text("No benchmark results recorded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func parseBenchmarkResults() -> [(benchmarkType: String, value1: Double, value2: Double?, date: String)]? {
        guard !exercise.benchmarkResultsData.isEmpty,
              let data = exercise.benchmarkResultsData.data(using: .utf8),
              let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        
        return results.compactMap { result in
            guard let type = result["benchmarkType"] as? String,
                  let value1 = result["value1"] as? Double else {
                return nil as (benchmarkType: String, value1: Double, value2: Double?, date: String)?
            }
            let value2 = result["value2"] as? Double
            let date = result["date"] as? String ?? ""
            return (benchmarkType: type, value1: value1, value2: value2, date: date)
        }
    }
    
    // MARK: - JSON Parsing Helpers
    
    private func parseMaxHangsSets() -> [MaxHangSet]? {
        guard !exercise.maxHangsSetsData.isEmpty,
              let data = exercise.maxHangsSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([MaxHangSet].self, from: data) else {
            return nil
        }
        return sets
    }
    
    private func parseRepeatersSets() -> [RepeaterSet]? {
        guard !exercise.repeatersSetsData.isEmpty,
              let data = exercise.repeatersSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([RepeaterSet].self, from: data) else {
            return nil
        }
        return sets
    }
    
    private func parseEdgePickupsSets() -> [EdgePickupSet]? {
        guard !exercise.edgePickupsSetsData.isEmpty,
              let data = exercise.edgePickupsSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([EdgePickupSet].self, from: data) else {
            return nil
        }
        return sets
    }
    
    private func parsePullupSets() -> [PullupSet]? {
        guard !exercise.pullupSetsData.isEmpty,
              let data = exercise.pullupSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([PullupSet].self, from: data) else {
            return nil
        }
        return sets
    }
    
    private func parseDeadliftSets() -> [DeadliftSet]? {
        guard !exercise.deadliftsSetsData.isEmpty,
              let data = exercise.deadliftsSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([DeadliftSet].self, from: data) else {
            return nil
        }
        return sets
    }
    
    private func parseShoulderLiftSets() -> [ShoulderLiftSet]? {
        guard !exercise.shoulderLiftsSetsData.isEmpty,
              let data = exercise.shoulderLiftsSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([ShoulderLiftSet].self, from: data) else {
            return nil
        }
        return sets
    }
    
    private func parseBoardClimbingRoutes() -> [BoardClimbingRoute]? {
        guard !exercise.boardClimbingRoutesData.isEmpty,
              let data = exercise.boardClimbingRoutesData.data(using: .utf8),
              let routes = try? JSONDecoder().decode([BoardClimbingRoute].self, from: data) else {
            return nil
        }
        return routes
    }
    
    private func parseLimitBoulderingRoutes() -> [LimitBoulderingRoute]? {
        guard !exercise.limitBoulderingRoutesData.isEmpty,
              let data = exercise.limitBoulderingRoutesData.data(using: .utf8),
              let routes = try? JSONDecoder().decode([LimitBoulderingRoute].self, from: data) else {
            return nil
        }
        return routes
    }
    
    private func parseNxNSets() -> [NxNSet]? {
        guard !exercise.nxnSetsData.isEmpty,
              let data = exercise.nxnSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([NxNSet].self, from: data) else {
            return nil
        }
        return sets
    }
    
    private func parseBoulderCampusSets() -> [BoulderCampusSet]? {
        guard !exercise.boulderCampusSetsData.isEmpty,
              let data = exercise.boulderCampusSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([BoulderCampusSet].self, from: data) else {
            return nil
        }
        return sets
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct MediaCard: View {
    let media: Media
    @State private var showingFullMedia = false
    
    var body: some View {
        Group {
            if let thumbnail = media.thumbnail {
                thumbnail
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        showingFullMedia = true
                    }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
        }
        .sheet(isPresented: $showingFullMedia) {
            MediaFullView(media: media)
        }
    }
}

struct MediaFullView: View {
    let media: Media
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if media.type == .image, let image = media.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else if media.type == .video, let videoURL = media.videoURL {
                    VideoPlayer(player: AVPlayer(url: videoURL))
                } else {
                    Text("Unable to load media")
                        .foregroundColor(.gray)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

