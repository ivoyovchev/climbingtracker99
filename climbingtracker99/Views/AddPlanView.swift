import SwiftUI
import SwiftData

struct AddPlannedTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [Exercise]
    
    let date: Date
    @State private var selectedExerciseTypes: Set<ExerciseType> = []
    @State private var estimatedDuration: Int = 60
    @State private var estimatedTime: Date = PlannedTraining.defaultTime
    @State private var notes: String = ""
    @State private var repeatWeekly: Bool = false
    @State private var numberOfWeeks: Int = 4
    
    private var uniqueExerciseTypes: [ExerciseType] {
        Array(Set(exercises.map { $0.type })).sorted { $0.rawValue < $1.rawValue }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Training Details")) {
                    Text("Select Exercises")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(uniqueExerciseTypes, id: \.self) { type in
                        Toggle(isOn: Binding(
                            get: { selectedExerciseTypes.contains(type) },
                            set: { isSelected in
                                if isSelected {
                                    selectedExerciseTypes.insert(type)
                                } else {
                                    selectedExerciseTypes.remove(type)
                                }
                            }
                        )) {
                            HStack(spacing: 12) {
                                Image(type.imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 30)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                
                                Text(type.displayName)
                                    .font(.body)
                            }
                        }
                    }
                    
                    if !selectedExerciseTypes.isEmpty {
                        Divider()
                        
                        Stepper("Estimated Duration: \(estimatedDuration) min", value: $estimatedDuration, in: 15...300, step: 15)
                        
                        DatePicker("Estimated Time", selection: $estimatedTime, displayedComponents: .hourAndMinute)
                    }
                }
                
                Section(header: Text("Repeat")) {
                    Toggle("Repeat Every Week", isOn: $repeatWeekly)
                    
                    if repeatWeekly {
                        Stepper("For \(numberOfWeeks) weeks", value: $numberOfWeeks, in: 2...52)
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button("Save Plan") {
                        savePlan()
                    }
                    .disabled(selectedExerciseTypes.isEmpty)
                }
            }
            .navigationTitle("Add Training Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func savePlan() {
        guard !selectedExerciseTypes.isEmpty else { return }
        
        let calendar = Calendar.current
        let numberOfPlans = repeatWeekly ? numberOfWeeks : 1
        let exerciseTypesArray = Array(selectedExerciseTypes)
        
        var createdPlans: [PlannedTraining] = []
        
        for week in 0..<numberOfPlans {
            let planDate = calendar.date(byAdding: .weekOfYear, value: week, to: date) ?? date
            
            let plan = PlannedTraining(
                date: planDate,
                exerciseTypes: exerciseTypesArray,
                estimatedDuration: estimatedDuration,
                estimatedTime: estimatedTime,
                notes: notes.isEmpty ? nil : notes
            )
            
            modelContext.insert(plan)
            createdPlans.append(plan)
        }
        
        // Schedule notifications for all created plans
        Task {
            _ = await NotificationManager.shared.requestAuthorization()
            for plan in createdPlans {
                NotificationManager.shared.scheduleTrainingNotification(for: plan)
            }
        }
        
        dismiss()
    }
}

struct EditPlannedTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [Exercise]
    
    @Bindable var training: PlannedTraining
    @State private var selectedExerciseTypes: Set<ExerciseType>
    @State private var estimatedDuration: Int
    @State private var estimatedTime: Date
    @State private var notes: String
    
    private var uniqueExerciseTypes: [ExerciseType] {
        Array(Set(exercises.map { $0.type })).sorted { $0.rawValue < $1.rawValue }
    }
    
    init(training: PlannedTraining) {
        self.training = training
        _estimatedDuration = State(initialValue: training.estimatedDuration)
        _estimatedTime = State(initialValue: training.estimatedTimeOfDay)
        _notes = State(initialValue: training.notes ?? "")
        _selectedExerciseTypes = State(initialValue: Set(training.exerciseTypes))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Training Details")) {
                    Text("Select Exercises")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(uniqueExerciseTypes, id: \.self) { type in
                        Toggle(isOn: Binding(
                            get: { selectedExerciseTypes.contains(type) },
                            set: { isSelected in
                                if isSelected {
                                    selectedExerciseTypes.insert(type)
                                } else {
                                    selectedExerciseTypes.remove(type)
                                }
                            }
                        )) {
                            HStack(spacing: 12) {
                                Image(type.imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 30)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                
                                Text(type.displayName)
                                    .font(.body)
                            }
                        }
                    }
                    
                    if !selectedExerciseTypes.isEmpty {
                        Divider()
                        
                        Stepper("Estimated Duration: \(estimatedDuration) min", value: $estimatedDuration, in: 15...300, step: 15)
                        
                        DatePicker("Estimated Time", selection: $estimatedTime, displayedComponents: .hourAndMinute)
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button("Save Changes") {
                        saveChanges()
                    }
                    .disabled(selectedExerciseTypes.isEmpty)
                }
            }
            .navigationTitle("Edit Training Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveChanges() {
        training.exerciseTypes = Array(selectedExerciseTypes)
        training.estimatedDuration = estimatedDuration
        training.estimatedTime = estimatedTime
        training.notes = notes.isEmpty ? nil : notes
        
        // Always reschedule notification when editing (time might have changed)
        NotificationManager.shared.removeTrainingNotification(for: training)
        Task {
            NotificationManager.shared.scheduleTrainingNotification(for: training)
        }
        
        dismiss()
    }
}

struct AddPlannedRunView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let date: Date
    @State private var runningType: RunningType = .easyRun
    @State private var estimatedDistance: Double = 5.0
    @State private var estimatedTempo: Double? = nil
    @State private var estimatedDuration: Int = 30
    @State private var estimatedTime: Date = PlannedRun.defaultTime
    @State private var notes: String = ""
    @State private var hasTempo: Bool = false
    @State private var repeatWeekly: Bool = false
    @State private var numberOfWeeks: Int = 4
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Run Details")) {
                    Picker("Run Type", selection: $runningType) {
                        ForEach(RunningType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    Stepper("Estimated Distance: \(String(format: "%.1f", estimatedDistance)) km", 
                           value: Binding(
                               get: { estimatedDistance },
                               set: { 
                                   estimatedDistance = $0
                                   // Auto-calculate duration when distance changes and tempo is set
                                   if hasTempo, let tempo = estimatedTempo {
                                       estimatedDuration = Int($0 * tempo)
                                   }
                               }
                           ),
                           in: 1...50, step: 0.5)
                    
                    Toggle("Set Target Tempo", isOn: Binding(
                        get: { hasTempo },
                        set: { newValue in
                            hasTempo = newValue
                            if newValue {
                                // When enabling tempo, initialize if needed and calculate duration
                                if estimatedTempo == nil {
                                    estimatedTempo = 5.0
                                }
                                if let tempo = estimatedTempo {
                                    estimatedDuration = Int(estimatedDistance * tempo)
                                }
                            }
                        }
                    ))
                    
                    if hasTempo {
                        Stepper("Tempo: \(String(format: "%.1f", estimatedTempo ?? 5.0)) min/km",
                               value: Binding(
                                   get: { estimatedTempo ?? 5.0 },
                                   set: { 
                                       estimatedTempo = $0
                                       // Auto-calculate duration when tempo changes
                                       estimatedDuration = Int(estimatedDistance * $0)
                                   }
                               ),
                               in: 3.0...10.0, step: 0.1)
                    }
                    
                    Stepper("Estimated Duration: \(estimatedDuration) min", 
                           value: $estimatedDuration, 
                           in: 15...180, 
                           step: 5)
                        .disabled(hasTempo) // Disable manual editing when tempo is set
                        .foregroundColor(hasTempo ? .secondary : .primary)
                    
                    DatePicker("Estimated Time", selection: $estimatedTime, displayedComponents: .hourAndMinute)
                }
                
                Section(header: Text("Repeat")) {
                    Toggle("Repeat Every Week", isOn: $repeatWeekly)
                    
                    if repeatWeekly {
                        Stepper("For \(numberOfWeeks) weeks", value: $numberOfWeeks, in: 2...52)
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button("Save Plan") {
                        savePlan()
                    }
                }
            }
            .navigationTitle("Add Run Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func savePlan() {
        let calendar = Calendar.current
        let numberOfPlans = repeatWeekly ? numberOfWeeks : 1
        
        var createdPlans: [PlannedRun] = []
        
        for week in 0..<numberOfPlans {
            let planDate = calendar.date(byAdding: .weekOfYear, value: week, to: date) ?? date
            
            let plan = PlannedRun(
                date: planDate,
                runningType: runningType,
                estimatedDistance: estimatedDistance,
                estimatedTempo: hasTempo ? estimatedTempo : nil,
                estimatedDuration: estimatedDuration,
                estimatedTime: estimatedTime,
                notes: notes.isEmpty ? nil : notes
            )
            
            modelContext.insert(plan)
            createdPlans.append(plan)
        }
        
        // Schedule notifications for all created plans
        Task {
            _ = await NotificationManager.shared.requestAuthorization()
            for plan in createdPlans {
                NotificationManager.shared.scheduleRunNotification(for: plan)
            }
        }
        
        dismiss()
    }
}

struct EditPlannedRunView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var run: PlannedRun
    @State private var runningType: RunningType
    @State private var estimatedDistance: Double
    @State private var estimatedTempo: Double?
    @State private var estimatedDuration: Int
    @State private var estimatedTime: Date
    @State private var notes: String
    @State private var hasTempo: Bool
    
    init(run: PlannedRun) {
        self.run = run
        _runningType = State(initialValue: run.runningType)
        _estimatedDistance = State(initialValue: run.estimatedDistance)
        _estimatedTempo = State(initialValue: run.estimatedTempo)
        _estimatedDuration = State(initialValue: run.estimatedDuration)
        _estimatedTime = State(initialValue: run.estimatedTimeOfDay)
        _notes = State(initialValue: run.notes ?? "")
        _hasTempo = State(initialValue: run.estimatedTempo != nil)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Run Details")) {
                    Picker("Run Type", selection: $runningType) {
                        ForEach(RunningType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    Stepper("Estimated Distance: \(String(format: "%.1f", estimatedDistance)) km",
                           value: Binding(
                               get: { estimatedDistance },
                               set: { 
                                   estimatedDistance = $0
                                   // Auto-calculate duration when distance changes and tempo is set
                                   if hasTempo, let tempo = estimatedTempo {
                                       estimatedDuration = Int($0 * tempo)
                                   }
                               }
                           ),
                           in: 1...50, step: 0.5)
                    
                    Toggle("Set Target Tempo", isOn: Binding(
                        get: { hasTempo },
                        set: { newValue in
                            hasTempo = newValue
                            if newValue {
                                // When enabling tempo, initialize if needed and calculate duration
                                if estimatedTempo == nil {
                                    estimatedTempo = 5.0
                                }
                                if let tempo = estimatedTempo {
                                    estimatedDuration = Int(estimatedDistance * tempo)
                                }
                            }
                        }
                    ))
                    
                    if hasTempo {
                        Stepper("Tempo: \(String(format: "%.1f", estimatedTempo ?? 5.0)) min/km",
                               value: Binding(
                                   get: { estimatedTempo ?? 5.0 },
                                   set: { 
                                       estimatedTempo = $0
                                       // Auto-calculate duration when tempo changes
                                       estimatedDuration = Int(estimatedDistance * $0)
                                   }
                               ),
                               in: 3.0...10.0, step: 0.1)
                    }
                    
                    Stepper("Estimated Duration: \(estimatedDuration) min", 
                           value: $estimatedDuration, 
                           in: 15...180, 
                           step: 5)
                        .disabled(hasTempo) // Disable manual editing when tempo is set
                        .foregroundColor(hasTempo ? .secondary : .primary)
                    
                    DatePicker("Estimated Time", selection: $estimatedTime, displayedComponents: .hourAndMinute)
                }
                
                Section(header: Text("Notes")) {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button("Save Changes") {
                        saveChanges()
                    }
                }
            }
            .navigationTitle("Edit Run Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveChanges() {
        run.runningType = runningType
        run.estimatedDistance = estimatedDistance
        run.estimatedTempo = hasTempo ? estimatedTempo : nil
        run.estimatedDuration = estimatedDuration
        run.estimatedTime = estimatedTime
        run.notes = notes.isEmpty ? nil : notes
        
        // Always reschedule notification when editing (time might have changed)
        NotificationManager.shared.removeRunNotification(for: run)
        Task {
            NotificationManager.shared.scheduleRunNotification(for: run)
        }
        
        dismiss()
    }
}

