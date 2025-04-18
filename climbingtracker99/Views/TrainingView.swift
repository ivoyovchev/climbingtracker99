import SwiftUI
import SwiftData

public struct TrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Training.date, order: .reverse) private var trainings: [Training]
    @State private var showingAddTraining = false
    @State private var trainingToEdit: Training?
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                addTrainingButton
                
                ExerciseStatsView(trainings: trainings)
                
                trainingList
            }
            .navigationTitle("Training")
            .sheet(isPresented: $showingAddTraining) {
                TrainingEditView()
            }
            .sheet(item: $trainingToEdit) { training in
                TrainingEditView(training: training)
            }
        }
    }
    
    private var addTrainingButton: some View {
        Button(action: { showingAddTraining = true }) {
            Label("Add Training", systemImage: "plus.circle.fill")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
        }
        .padding(.horizontal)
    }
    
    private var trainingList: some View {
        List {
            ForEach(trainings) { training in
                TrainingRow(training: training) {
                    trainingToEdit = training
                }
            }
            .onDelete(perform: deleteTrainings)
        }
    }
    
    private func deleteTrainings(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(trainings[index])
            }
        }
    }
}

struct TrainingRow: View {
    let training: Training
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(training.date, style: .date)
                    .font(.headline)
                Spacer()
                Text(training.date, style: .time)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            HStack {
                Text("\(training.duration) min")
                    .font(.subheadline)
                Spacer()
                Text(training.location.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Text(training.focus.rawValue)
                .font(.subheadline)
                .foregroundColor(.blue)
            
            if !training.recordedExercises.isEmpty {
                Text("Exercises: \(training.recordedExercises.count)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            if !training.notes.isEmpty {
                Text(training.notes)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

struct TrainingEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [Exercise]
    
    @State private var date: Date = Date()
    @State private var duration: Int = 60
    @State private var location: TrainingLocation = .indoor
    @State private var focus: TrainingFocus = .strength
    @State private var selectedExercises: [Exercise] = []
    @State private var recordedExercises: [RecordedExercise] = []
    @State private var notes: String = ""
    @State private var showingExercisePicker = false
    
    var training: Training?
    var isEditing: Bool { training != nil }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Date & Time")) {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section(header: Text("Details")) {
                    Stepper("Duration: \(duration) min", value: $duration, in: 15...240, step: 15)
                    
                    Picker("Location", selection: $location) {
                        ForEach(TrainingLocation.allCases, id: \.self) { location in
                            Text(location.rawValue).tag(location)
                        }
                    }
                    
                    Picker("Focus", selection: $focus) {
                        ForEach(TrainingFocus.allCases, id: \.self) { focus in
                            Text(focus.rawValue).tag(focus)
                        }
                    }
                }
                
                Section(header: Text("Exercises")) {
                    ForEach(recordedExercises) { recordedExercise in
                        NavigationLink(destination: ExerciseRecordView(recordedExercise: recordedExercise)) {
                            VStack(alignment: .leading) {
                                Text(recordedExercise.exercise.type.rawValue)
                                    .font(.headline)
                                
                                switch recordedExercise.exercise.type {
                                case .hangboarding:
                                    if let grip = recordedExercise.gripType,
                                       let duration = recordedExercise.duration,
                                       let weight = recordedExercise.addedWeight {
                                        Text("Grip: \(grip.rawValue), \(duration)s, +\(weight)kg")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                case .repeaters:
                                    if let duration = recordedExercise.duration,
                                       let reps = recordedExercise.repetitions,
                                       let sets = recordedExercise.sets {
                                        Text("\(duration)s × \(reps) reps × \(sets) sets")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                case .limitBouldering:
                                    if let grade = recordedExercise.grade,
                                       let routes = recordedExercise.routes {
                                        Text("\(grade) × \(routes) routes")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteExercises)
                    
                    Button(action: { showingExercisePicker = true }) {
                        Label("Add Exercise", systemImage: "plus")
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle(isEditing ? "Edit Training" : "New Training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        saveTraining()
                    }
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(selectedExercises: $selectedExercises) { exercise in
                    let recordedExercise = RecordedExercise(exercise: exercise)
                    recordedExercises.append(recordedExercise)
                }
            }
            .onAppear {
                if let training = training {
                    date = training.date
                    duration = training.duration
                    location = training.location
                    focus = training.focus
                    recordedExercises = training.recordedExercises
                    notes = training.notes
                }
            }
        }
    }
    
    private func saveTraining() {
        if let training = training {
            training.date = date
            training.duration = duration
            training.location = location
            training.focus = focus
            training.recordedExercises = recordedExercises
            training.notes = notes
        } else {
            let newTraining = Training(
                date: date,
                duration: duration,
                location: location,
                focus: focus,
                recordedExercises: recordedExercises,
                notes: notes
            )
            modelContext.insert(newTraining)
        }
        dismiss()
    }
    
    private func deleteExercises(offsets: IndexSet) {
        recordedExercises.remove(atOffsets: offsets)
    }
}

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [Exercise]
    @Binding var selectedExercises: [Exercise]
    var onSelect: (Exercise) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(exercises) { exercise in
                    Button(action: {
                        if !selectedExercises.contains(where: { $0.id == exercise.id }) {
                            selectedExercises.append(exercise)
                            onSelect(exercise)
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
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
                            
                            Spacer()
                            
                            if selectedExercises.contains(where: { $0.id == exercise.id }) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ExerciseRecordView: View {
    @ObservedObject var recordedExercise: RecordedExercise
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            switch recordedExercise.exercise.type {
            case .hangboarding:
                Section(header: Text("Grip Type")) {
                    Picker("Grip", selection: Binding(
                        get: { recordedExercise.gripType ?? .halfCrimp },
                        set: { recordedExercise.updateGripType($0) }
                    )) {
                        ForEach(GripType.allCases, id: \.self) { grip in
                            Text(grip.rawValue).tag(grip)
                        }
                    }
                }
                
                Section(header: Text("Duration")) {
                    Stepper("\(recordedExercise.duration ?? 7) seconds", 
                           value: Binding(
                            get: { recordedExercise.duration ?? 7 },
                            set: { recordedExercise.updateDuration($0) }
                           ),
                           in: 1...20)
                }
                
                Section(header: Text("Added Weight")) {
                    Stepper("+\(recordedExercise.addedWeight ?? 0) kg", 
                           value: Binding(
                            get: { recordedExercise.addedWeight ?? 0 },
                            set: { recordedExercise.updateAddedWeight($0) }
                           ),
                           in: 0...50)
                }
                
            case .repeaters:
                Section(header: Text("Duration")) {
                    Stepper("\(recordedExercise.duration ?? 7) seconds", 
                           value: Binding(
                            get: { recordedExercise.duration ?? 7 },
                            set: { recordedExercise.updateDuration($0) }
                           ),
                           in: 1...20)
                }
                
                Section(header: Text("Repetitions")) {
                    Stepper("\(recordedExercise.repetitions ?? 6) reps", 
                           value: Binding(
                            get: { recordedExercise.repetitions ?? 6 },
                            set: { recordedExercise.updateRepetitions($0) }
                           ),
                           in: 1...20)
                }
                
                Section(header: Text("Sets")) {
                    Stepper("\(recordedExercise.sets ?? 6) sets", 
                           value: Binding(
                            get: { recordedExercise.sets ?? 6 },
                            set: { recordedExercise.updateSets($0) }
                           ),
                           in: 1...10)
                }
                
                Section(header: Text("Rest Duration")) {
                    Stepper("\(recordedExercise.restDuration ?? 3) min", 
                           value: Binding(
                            get: { recordedExercise.restDuration ?? 3 },
                            set: { recordedExercise.updateRestDuration($0) }
                           ),
                           in: 1...10)
                }
                
            case .limitBouldering:
                Section(header: Text("Grade")) {
                    TextField("Grade", text: Binding(
                        get: { recordedExercise.grade ?? "V4" },
                        set: { recordedExercise.updateGrade($0) }
                    ))
                }
                
                Section(header: Text("Routes")) {
                    Stepper("\(recordedExercise.routes ?? 3) routes", 
                           value: Binding(
                            get: { recordedExercise.routes ?? 3 },
                            set: { recordedExercise.updateRoutes($0) }
                           ),
                           in: 1...10)
                }
                
                Section(header: Text("Attempts")) {
                    Stepper("\(recordedExercise.attempts ?? 3) attempts", 
                           value: Binding(
                            get: { recordedExercise.attempts ?? 3 },
                            set: { recordedExercise.updateAttempts($0) }
                           ),
                           in: 1...10)
                }
                
                Section(header: Text("Rest Between Routes")) {
                    Stepper("\(recordedExercise.restBetweenRoutes ?? 3) min", 
                           value: Binding(
                            get: { recordedExercise.restBetweenRoutes ?? 3 },
                            set: { recordedExercise.updateRestBetweenRoutes($0) }
                           ),
                           in: 1...10)
                }
                
                Section(header: Text("Session Duration")) {
                    Stepper("\(recordedExercise.sessionDuration ?? 60) min", 
                           value: Binding(
                            get: { recordedExercise.sessionDuration ?? 60 },
                            set: { recordedExercise.updateSessionDuration($0) }
                           ),
                           in: 15...180, step: 15)
                }
            }
        }
        .navigationTitle("Record Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
} 