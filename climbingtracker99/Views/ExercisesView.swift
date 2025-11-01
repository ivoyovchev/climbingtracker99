import SwiftUI
import SwiftData

struct ExercisesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var exercises: [Exercise]
    @State private var showingAddExercise = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(exercises) { exercise in
                    NavigationLink(destination: ExerciseEditView(exercise: exercise)) {
                        HStack(spacing: 16) {
                            // Exercise Image
                            Image(exercise.type.imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.type.rawValue)
                                    .font(.headline)
                                
                                ExerciseDetailsView(exercise: exercise)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteExercises)
            }
            .navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddExercise = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseView()
            }
            .onAppear {
                if exercises.isEmpty {
                    createDefaultExercises()
                } else {
                    updateExerciseFocuses()
                }
            }
        }
    }
    
    private func createDefaultExercises() {
        // Create default exercises for each type
        let defaultExercises = ExerciseType.allCases.map { type in
            Exercise(type: type)
        }
        
        for exercise in defaultExercises {
            modelContext.insert(exercise)
        }
    }
    
    private func updateExerciseFocuses() {
        for exercise in exercises {
            switch exercise.type {
            case .hangboarding:
                exercise.focus = .strength
            case .repeaters:
                exercise.focus = .endurance
            case .limitBouldering:
                exercise.focus = .power
            case .nxn:
                exercise.focus = .endurance
            case .boulderCampus:
                exercise.focus = .power
            case .deadlifts:
                exercise.focus = .strength
            case .shoulderLifts:
                exercise.focus = .strength
            case .pullups:
                exercise.focus = .strength
            case .boardClimbing:
                exercise.focus = .technique
            case .edgePickups:
                exercise.focus = .strength
            case .flexibility:
                exercise.focus = .mobility
            case .running:
                exercise.focus = .endurance
            case .warmup:
                exercise.focus = .mobility
            case .circuit:
                exercise.focus = .endurance
            case .core:
                exercise.focus = .mobility
            case .campusing:
                exercise.focus = .power
            }
        }
    }
    
    private func deleteExercises(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(exercises[index])
            }
        }
    }
}

struct ExerciseDetailsView: View {
    let exercise: Exercise
    
    var body: some View {
        Group {
            switch exercise.type {
            case .hangboarding:
                if let grip = exercise.gripType,
                   let edgeSize = exercise.edgeSize {
                    Text("Grip: \(grip.rawValue) - Edge: \(edgeSize)mm")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            case .repeaters:
                if let duration = exercise.duration,
                   let reps = exercise.repetitions,
                   let sets = exercise.sets {
                    Text("\(duration)s × \(reps) reps × \(sets) sets")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            case .limitBouldering:
                if let grade = exercise.grade,
                   let routes = exercise.routes {
                    Text("\(grade) × \(routes) routes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            case .nxn:
                if let grade = exercise.grade,
                   let routes = exercise.routes,
                   let sets = exercise.sets {
                    Text("\(grade) × \(routes) routes × \(sets) sets")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            case .boulderCampus:
                if let moves = exercise.moves,
                   let sets = exercise.sets {
                    Text("\(moves) moves × \(sets) sets")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            case .deadlifts:
                if let reps = exercise.repetitions,
                   let sets = exercise.sets,
                   let weight = exercise.weight {
                    Text("\(reps) reps × \(sets) sets × \(String(format: "%.1f", weight))kg")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            case .shoulderLifts:
                if let reps = exercise.repetitions,
                   let sets = exercise.sets,
                   let weight = exercise.weight {
                    Text("\(reps) reps × \(sets) sets × \(String(format: "%.1f", weight))kg")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            case .pullups:
                if let reps = exercise.repetitions,
                   let sets = exercise.sets,
                   let weight = exercise.addedWeight {
                    Text("\(reps) reps × \(sets) sets × \(String(format: "%.1f", weight))kg")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            case .boardClimbing:
                if let board = exercise.boardType,
                   let grade = exercise.grade {
                    Text("\(board.rawValue) - \(grade)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            case .edgePickups:
                if let duration = exercise.duration,
                   let sets = exercise.sets,
                   let weight = exercise.addedWeight,
                   let edgeSize = exercise.edgeSize {
                    Text("\(duration)s × \(sets) sets × \(String(format: "%.1f", weight))kg × \(edgeSize)mm")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            case .flexibility:
                let areas = [
                    exercise.hamstrings ? "Hamstrings" : nil,
                    exercise.hips ? "Hips" : nil,
                    exercise.forearms ? "Forearms" : nil,
                    exercise.legs ? "Legs" : nil
                ].compactMap { $0 }
                
                if !areas.isEmpty {
                    Text(areas.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            case .running:
                if let hours = exercise.hours,
                   let minutes = exercise.minutes,
                   let distance = exercise.distance {
                    Text("\(hours)h \(minutes)m × \(String(format: "%.2f", distance))km")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            case .warmup:
                if let duration = exercise.duration {
                    Text("\(duration) min")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            case .circuit:
                if let sets = exercise.sets, let duration = exercise.duration {
                    Text("\(sets) sets × \(duration)s")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            case .core:
                if let sets = exercise.sets, let duration = exercise.duration {
                    Text("\(sets) sets × \(duration)s")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            case .campusing:
                if let sets = exercise.sets {
                    if let edgeSize = exercise.edgeSize {
                        Text("\(sets) sets × \(edgeSize)mm")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(sets) sets")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct AddExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingExercises: [Exercise]
    @State private var selectedType: ExerciseType = .hangboarding
    
    private var availableExerciseTypes: [ExerciseType] {
        let existingTypes = Set(existingExercises.map { $0.type })
        return ExerciseType.allCases.filter { !existingTypes.contains($0) }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                if availableExerciseTypes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("All exercises have been added!")
                            .font(.title2)
                            .bold()
                        Text("You can manage your exercises in the main list.")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(availableExerciseTypes, id: \.self) { type in
                            ExerciseTypeButton(
                                type: type,
                                isSelected: selectedType == type,
                                action: { selectedType = type }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let exercise = Exercise(type: selectedType)
                        modelContext.insert(exercise)
                        dismiss()
                    }
                    .disabled(availableExerciseTypes.isEmpty)
                }
            }
        }
    }
}

struct ExerciseTypeButton: View {
    let type: ExerciseType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(type.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text(type.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
} 