import SwiftUI
import SwiftData

struct GoalsEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var goals: Goals
    
    @State private var targetTrainingsPerWeek: Int = 0
    @State private var targetWeight: Double = 0
    @State private var startingWeight: Double?
    @State private var targetRunsPerWeek: Int? = 3
    @State private var targetDistancePerWeek: Double? = 20.0
    
    @State private var newExerciseType: ExerciseType = .hangboarding
    @State private var newGripType: GripType = .halfCrimp
    @State private var newEdgeSize: Int = 20
    @State private var newDuration: Int = 10
    @State private var newRepetitions: Int = 6
    @State private var newSets: Int = 3
    @State private var newAddedWeight: Double = 0
    @State private var newDeadline: Date = Date().addingTimeInterval(30 * 24 * 60 * 60)
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Training Goals") {
                    Stepper("Target Trainings per Week: \(targetTrainingsPerWeek)", value: $targetTrainingsPerWeek, in: 0...7)
                }
                
                Section("Running Goals") {
                    Stepper("Target Runs per Week: \(targetRunsPerWeek ?? 3)", value: Binding(
                        get: { targetRunsPerWeek ?? 3 },
                        set: { targetRunsPerWeek = $0 }
                    ), in: 0...7)
                    
                    HStack {
                        Text("Target Distance per Week")
                        Spacer()
                        TextField("km", value: Binding(
                            get: { targetDistancePerWeek ?? 20.0 },
                            set: { targetDistancePerWeek = $0 }
                        ), format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                
                Section("Weight Goals") {
                    HStack {
                        Text("Starting Weight")
                        Spacer()
                        TextField("kg", value: $startingWeight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Target Weight")
                        Spacer()
                        TextField("kg", value: $targetWeight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Exercise Goals") {
                    ForEach(goals.exerciseGoals) { goal in
                        Text(goal.exerciseType.rawValue)
                            .font(.headline)
                        
                        if goal.exerciseType == .hangboarding {
                            if let gripTypeString = goal.getParameterValue("gripType") as String?,
                               let gripType = GripType(rawValue: gripTypeString) {
                                Text("Grip: \(gripType.rawValue)")
                            }
                            if let edgeSize = goal.getParameterValue("edgeSize") as Int? {
                                Text("Edge Size: \(edgeSize)mm")
                            }
                            if let duration = goal.getTargetValue("duration") {
                                Text("Duration: \(Int(duration))s")
                            }
                            if let weight = goal.getTargetValue("addedWeight") {
                                Text("Added Weight: \(weight)kg")
                            }
                        } else if goal.exerciseType == .repeaters {
                            if let duration = goal.getTargetValue("duration") {
                                Text("Duration: \(Int(duration))s")
                            }
                            if let reps = goal.getTargetValue("repetitions") {
                                Text("Repetitions: \(Int(reps))")
                            }
                            if let sets = goal.getTargetValue("sets") {
                                Text("Sets: \(Int(sets))")
                            }
                            if let weight = goal.getTargetValue("addedWeight") {
                                Text("Added Weight: \(weight)kg")
                            }
                        }
                        
                        if let deadline = goal.deadline {
                            Text("Deadline: \(deadline.formatted(date: .abbreviated, time: .omitted))")
                        }
                    }
                    .onDelete(perform: deleteExerciseGoals)
                }
                
                Section("Add New Exercise Goal") {
                    Picker("Exercise Type", selection: $newExerciseType) {
                        ForEach(ExerciseType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    if newExerciseType == .hangboarding {
                        Picker("Grip Type", selection: $newGripType) {
                            ForEach(GripType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        
                        Stepper("Edge Size: \(newEdgeSize)mm", value: $newEdgeSize, in: 10...30)
                        
                        Stepper("Duration: \(newDuration)s", value: $newDuration, in: 5...30)
                        
                        Stepper("Added Weight: \(newAddedWeight)kg", value: $newAddedWeight, in: 0...50, step: 0.5)
                    } else if newExerciseType == .repeaters {
                        Stepper("Duration: \(newDuration)s", value: $newDuration, in: 5...30)
                        
                        Stepper("Repetitions: \(newRepetitions)", value: $newRepetitions, in: 1...10)
                        
                        Stepper("Sets: \(newSets)", value: $newSets, in: 1...5)
                        
                        Stepper("Added Weight: \(newAddedWeight)kg", value: $newAddedWeight, in: 0...50, step: 0.5)
                    }
                    
                    DatePicker("Deadline", selection: $newDeadline, displayedComponents: .date)
                    
                    Button("Add Goal") {
                        addExerciseGoal()
                    }
                }
            }
            .navigationTitle("Edit Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveGoals()
                        dismiss()
                    }
                }
            }
            .onAppear {
                targetTrainingsPerWeek = goals.targetTrainingsPerWeek
                targetWeight = goals.targetWeight
                startingWeight = goals.startingWeight
                targetRunsPerWeek = goals.targetRunsPerWeek ?? 3
                targetDistancePerWeek = goals.targetDistancePerWeek ?? 20.0
            }
        }
    }
    
    private func saveGoals() {
        goals.targetTrainingsPerWeek = targetTrainingsPerWeek
        goals.targetWeight = targetWeight
        goals.startingWeight = startingWeight
        goals.targetRunsPerWeek = targetRunsPerWeek
        goals.targetDistancePerWeek = targetDistancePerWeek
        goals.lastUpdated = Date()
    }
    
    private func deleteExerciseGoals(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                goals.exerciseGoals.remove(at: index)
            }
        }
    }
    
    private func addExerciseGoal() {
        let newGoal: ExerciseGoal
        
        if newExerciseType == .hangboarding {
            newGoal = ExerciseGoal.createHangboardingGoal(
                gripType: newGripType,
                edgeSize: newEdgeSize,
                duration: newDuration,
                addedWeight: newAddedWeight,
                deadline: newDeadline
            )
        } else if newExerciseType == .repeaters {
            newGoal = ExerciseGoal.createRepeatersGoal(
                duration: newDuration,
                repetitions: newRepetitions,
                sets: newSets,
                addedWeight: newAddedWeight,
                deadline: newDeadline
            )
        } else {
            return
        }
        
        goals.exerciseGoals.append(newGoal)
        
        // Reset form
        newExerciseType = .hangboarding
        newGripType = .halfCrimp
        newEdgeSize = 20
        newDuration = 10
        newRepetitions = 6
        newSets = 3
        newAddedWeight = 0
        newDeadline = Date().addingTimeInterval(30 * 24 * 60 * 60)
    }
}

struct ExerciseGoalRow: View {
    let goal: ExerciseGoal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(goal.exerciseType.rawValue)
                .font(.headline)
            
            if goal.exerciseType == .hangboarding {
                if let gripTypeString = goal.getParameterValue("gripType") as String?,
                   let gripType = GripType(rawValue: gripTypeString) {
                    Text("Grip: \(gripType.rawValue)")
                }
                if let edgeSize = goal.getParameterValue("edgeSize") as Int? {
                    Text("Edge Size: \(edgeSize)mm")
                }
                if let duration = goal.getTargetValue("duration") {
                    Text("Target Duration: \(Int(duration))s")
                }
                if let weight = goal.getTargetValue("addedWeight") {
                    Text("Target Weight: \(weight)kg")
                }
            } else if goal.exerciseType == .repeaters {
                if let duration = goal.getTargetValue("duration") {
                    Text("Target Duration: \(Int(duration))s")
                }
                if let reps = goal.getTargetValue("repetitions") {
                    Text("Target Repetitions: \(Int(reps))")
                }
                if let sets = goal.getTargetValue("sets") {
                    Text("Target Sets: \(Int(sets))")
                }
                if let weight = goal.getTargetValue("addedWeight") {
                    Text("Target Weight: \(weight)kg")
                }
            }
            
            if let deadline = goal.deadline {
                Text("Deadline: \(deadline.formatted(date: .abbreviated, time: .omitted))")
            }
        }
    }
}

struct AddExerciseGoalView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedExercise: ExerciseType = .hangboarding
    @State private var newGripType: GripType = .halfCrimp
    @State private var newEdgeSize: Int = 20
    @State private var newDuration: Int = 10
    @State private var newRepetitions: Int = 6
    @State private var newSets: Int = 3
    @State private var newAddedWeight: Double = 0
    @State private var deadline: Date?
    
    let onSave: (ExerciseGoal?) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Exercise Details")) {
                    Picker("Exercise Type", selection: $selectedExercise) {
                        ForEach(ExerciseType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    if selectedExercise == .hangboarding {
                        Picker("Grip Type", selection: $newGripType) {
                            ForEach(GripType.allCases, id: \.self) { grip in
                                Text(grip.rawValue).tag(grip)
                            }
                        }
                        
                        Stepper("Edge Size: \(newEdgeSize)mm", value: $newEdgeSize, in: 5...50, step: 1)
                    }
                }
                
                Section(header: Text("Goal Details")) {
                    if selectedExercise == .hangboarding {
                        Stepper("Duration: \(newDuration)s", value: $newDuration, in: 5...60, step: 1)
                        Stepper("Added Weight: \(newAddedWeight)kg", value: $newAddedWeight, in: 0...50, step: 0.5)
                    } else if selectedExercise == .repeaters {
                        Stepper("Duration: \(newDuration)s", value: $newDuration, in: 5...60, step: 1)
                        Stepper("Repetitions: \(newRepetitions)", value: $newRepetitions, in: 1...20, step: 1)
                        Stepper("Sets: \(newSets)", value: $newSets, in: 1...10, step: 1)
                        Stepper("Added Weight: \(newAddedWeight)kg", value: $newAddedWeight, in: 0...50, step: 0.5)
                    }
                    
                    DatePicker("Deadline (Optional)", selection: Binding(
                        get: { deadline ?? Date() },
                        set: { deadline = $0 }
                    ), displayedComponents: .date)
                }
            }
            .navigationTitle("New Exercise Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let goal: ExerciseGoal
                        if selectedExercise == .hangboarding {
                            goal = ExerciseGoal(
                                exerciseType: .hangboarding,
                                parameters: [
                                    "gripType": newGripType.rawValue,
                                    "edgeSize": String(newEdgeSize)
                                ],
                                targetValues: [
                                    "duration": Double(newDuration),
                                    "addedWeight": newAddedWeight
                                ],
                                currentValues: [
                                    "duration": 0,
                                    "addedWeight": 0
                                ],
                                deadline: deadline
                            )
                        } else {
                            goal = ExerciseGoal(
                                exerciseType: .repeaters,
                                parameters: [:],
                                targetValues: [
                                    "duration": Double(newDuration),
                                    "repetitions": Double(newRepetitions),
                                    "sets": Double(newSets),
                                    "addedWeight": newAddedWeight
                                ],
                                currentValues: [
                                    "duration": 0,
                                    "repetitions": 0,
                                    "sets": 0,
                                    "addedWeight": 0
                                ],
                                deadline: deadline
                            )
                        }
                        onSave(goal)
                        dismiss()
                    }
                }
            }
        }
    }
} 