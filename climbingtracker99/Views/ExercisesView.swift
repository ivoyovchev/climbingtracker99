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
                                
                                switch exercise.type {
                                case .hangboarding:
                                    if let grip = exercise.gripType {
                                        Text("Grip: \(grip.rawValue)")
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
                                }
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
                }
            }
        }
    }
    
    private func createDefaultExercises() {
        // Create default exercises for each type
        let defaultExercises = [
            Exercise(type: .hangboarding),
            Exercise(type: .repeaters),
            Exercise(type: .limitBouldering)
        ]
        
        for exercise in defaultExercises {
            modelContext.insert(exercise)
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

struct AddExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: ExerciseType = .hangboarding
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Exercise Type")) {
                    Picker("Type", selection: $selectedType) {
                        ForEach(ExerciseType.allCases, id: \.self) { type in
                            HStack {
                                Image(type.imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 30)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                Text(type.rawValue)
                            }
                            .tag(type)
                        }
                    }
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
                }
            }
        }
    }
} 