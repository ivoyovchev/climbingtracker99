import SwiftUI
import SwiftData

// Add color extension for TrainingFocus
extension TrainingFocus {
    var color: Color {
        switch self {
        case .strength:
            return .red
        case .power:
            return .orange
        case .endurance:
            return .green
        case .technique:
            return .blue
        case .mobility:
            return .purple
        }
    }
}

public struct TrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Training.date, order: .reverse) private var trainings: [Training]
    @State private var showingAddTraining = false
    @State private var trainingToEdit: Training?
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                ExerciseStatsView(trainings: trainings)
                
                trainingList
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("Training")
                            .font(.system(size: 24, weight: .bold))
                        Spacer()
                        Button(action: { showingAddTraining = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddTraining) {
                TrainingEditView()
            }
            .sheet(item: $trainingToEdit) { training in
                TrainingEditView(training: training)
            }
        }
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
        HStack(spacing: 0) {
            // Focus type colored stripe
            Rectangle()
                .fill(training.focus.color)
                .frame(width: 8)
            
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
                    .foregroundColor(training.focus.color)
                
                // Exercise thumbnails
                if !training.recordedExercises.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(training.recordedExercises) { recordedExercise in
                                Image(recordedExercise.exercise.type.imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 30)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                if !training.notes.isEmpty {
                    Text(training.notes)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .padding(.vertical, 12)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .listRowInsets(EdgeInsets())
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
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    // Computed property for available exercises
    private var availableExercises: [Exercise] {
        let selectedExerciseIds = recordedExercises.map { $0.exercise.id }
        return exercises.filter { !selectedExerciseIds.contains($0.id) }
    }
    
    private func addExercise(_ exercise: Exercise) {
        // Create a new recorded exercise and add it
        let recordedExercise = RecordedExercise(exercise: exercise)
        recordedExercises.append(recordedExercise)
    }
    
    var training: Training?
    var isEditing: Bool { training != nil }
    
    var body: some View {
        NavigationView {
            Form {
                // Header section with three rows
                Section {
                    // Row 1: Date/Time
                    DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .font(.subheadline)
                    
                    // Row 2: Location/Focus
                    HStack(spacing: 20) {
                        Picker("Location", selection: $location) {
                            ForEach(TrainingLocation.allCases, id: \.self) { location in
                                Text(location.rawValue).tag(location)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, -8)
                        
                        Picker("Focus", selection: $focus) {
                            ForEach(TrainingFocus.allCases, id: \.self) { focus in
                                Text(focus.rawValue).tag(focus)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, -8)
                    }
                    
                    // Row 3: Duration
                    HStack {
                        Text("Duration")
                            .font(.subheadline)
                        Spacer()
                        Text("\(duration) min")
                            .font(.subheadline)
                        Stepper("", value: $duration, in: 15...240, step: 15)
                            .labelsHidden()
                    }
                }
                
                // Completed Exercises section
                if !recordedExercises.isEmpty {
                    Section(header: Text("Completed Exercises")) {
                        ForEach(recordedExercises) { recordedExercise in
                            NavigationLink(destination: ExerciseRecordView(recordedExercise: recordedExercise)) {
                                HStack(spacing: 12) {
                                    Image(recordedExercise.exercise.type.imageName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 45)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(recordedExercise.exercise.type.rawValue)
                                            .font(.system(size: 14, weight: .semibold))
                                        
                                        switch recordedExercise.exercise.type {
                                        case .hangboarding:
                                            if let grip = recordedExercise.gripType,
                                               let duration = recordedExercise.duration,
                                               let weight = recordedExercise.addedWeight {
                                                Text("Grip: \(grip.rawValue), \(duration)s, +\(weight)kg")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.secondary)
                                            }
                                        case .repeaters:
                                            if let duration = recordedExercise.duration,
                                               let reps = recordedExercise.repetitions,
                                               let sets = recordedExercise.sets {
                                                Text("\(duration)s × \(reps) reps × \(sets) sets")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.secondary)
                                            }
                                        case .limitBouldering:
                                            if let grade = recordedExercise.grade,
                                               let routes = recordedExercise.routes {
                                                Text("\(grade) × \(routes) routes")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .onDelete(perform: deleteExercises)
                    }
                }
                
                // Available Exercises section
                Section(header: Text("Available Exercises")) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(availableExercises, id: \.id) { exercise in
                            Button(action: {
                                withAnimation {
                                    addExercise(exercise)
                                }
                            }) {
                                VStack(spacing: 8) {
                                    Image(exercise.type.imageName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    
                                    HStack {
                                        Text(exercise.type.rawValue)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.bottom, 8)
                                }
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(radius: 1)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
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