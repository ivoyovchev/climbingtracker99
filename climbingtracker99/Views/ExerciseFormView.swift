import SwiftUI
import SwiftData

// MARK: - View Model
class ExerciseFormViewModel: ObservableObject {
    @Published var exercise: Exercise
    @Published var recordedExercise: RecordedExercise?
    let isRecording: Bool
    
    init(exercise: Exercise, recordedExercise: RecordedExercise?, isRecording: Bool) {
        self.exercise = exercise
        self.recordedExercise = recordedExercise
        self.isRecording = isRecording
    }
    
    // MARK: - Helper Methods for Bindings
    func createEdgeSizeBinding() -> Binding<Double> {
        Binding(
            get: {
                if self.isRecording {
                    return Double(self.recordedExercise?.edgeSize ?? self.exercise.edgeSize ?? 20)
                }
                return Double(self.exercise.edgeSize ?? 20)
            },
            set: { newValue in
                if self.isRecording {
                    self.recordedExercise?.updateEdgeSize(Int(newValue))
                } else {
                    self.exercise.edgeSize = Int(newValue)
                }
            }
        )
    }
    
    func createDurationBinding() -> Binding<Double> {
        Binding(
            get: {
                if self.isRecording {
                    return Double(self.recordedExercise?.duration ?? self.exercise.duration ?? 15)
                }
                return Double(self.exercise.duration ?? 15)
            },
            set: { newValue in
                if self.isRecording {
                    self.recordedExercise?.updateDuration(Int(newValue))
                } else {
                    self.exercise.duration = Int(newValue)
                }
            }
        )
    }
    
    func createSetsBinding() -> Binding<Double> {
        Binding(
            get: {
                if self.isRecording {
                    return Double(self.recordedExercise?.sets ?? self.exercise.sets ?? 6)
                }
                return Double(self.exercise.sets ?? 6)
            },
            set: { newValue in
                if self.isRecording {
                    self.recordedExercise?.updateSets(Int(newValue))
                } else {
                    self.exercise.sets = Int(newValue)
                }
            }
        )
    }
    
    func createRestDurationBinding() -> Binding<Double> {
        Binding(
            get: {
                if self.isRecording {
                    return Double(self.recordedExercise?.restDuration ?? self.exercise.restDuration ?? 2)
                }
                return Double(self.exercise.restDuration ?? 2)
            },
            set: { newValue in
                if self.isRecording {
                    self.recordedExercise?.updateRestDuration(Int(newValue))
                } else {
                    self.exercise.restDuration = Int(newValue)
                }
            }
        )
    }
    
    func createAddedWeightBinding() -> Binding<Double> {
        Binding(
            get: {
                if self.isRecording {
                    return Double(self.recordedExercise?.addedWeight ?? Int(self.exercise.addedWeight ?? 30))
                }
                return self.exercise.addedWeight ?? 30
            },
            set: { newValue in
                if self.isRecording {
                    self.recordedExercise?.updateAddedWeight(Int(newValue))
                } else {
                    self.exercise.addedWeight = newValue
                }
            }
        )
    }
}

// MARK: - Stepper Component
struct ExerciseStepper: View {
    let title: String
    let value: Double
    let binding: Binding<Double>
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    
    init(title: String,
         value: Double,
         binding: Binding<Double>,
         range: ClosedRange<Double>,
         step: Double = 1,
         format: String = "%.0f") {
        self.title = title
        self.value = value
        self.binding = binding
        self.range = range
        self.step = step
        self.format = format
    }
    
    var body: some View {
        Stepper(value: binding, in: range, step: step) {
            Text("\(title): \(String(format: format, value))")
        }
    }
}

// MARK: - Main View
struct ExerciseFormView: View {
    @StateObject private var viewModel: ExerciseFormViewModel
    
    init(exercise: Exercise, recordedExercise: RecordedExercise?, isRecording: Bool) {
        _viewModel = StateObject(wrappedValue: ExerciseFormViewModel(
            exercise: exercise,
            recordedExercise: recordedExercise,
            isRecording: isRecording
        ))
    }
    
    // MARK: - Computed Properties for Bindings
    private var boardTypeBinding: Binding<BoardType?> {
        Binding(
            get: {
                if viewModel.isRecording {
                    return viewModel.recordedExercise?.boardType ?? viewModel.exercise.boardType
                }
                return viewModel.exercise.boardType
            },
            set: { newValue in
                if viewModel.isRecording {
                    viewModel.recordedExercise?.updateBoardType(newValue)
                } else {
                    viewModel.exercise.boardType = newValue
                }
            }
        )
    }
    
    private var gradeBinding: Binding<String?> {
        Binding(
            get: {
                if viewModel.isRecording {
                    return viewModel.recordedExercise?.grade ?? viewModel.exercise.grade
                }
                return viewModel.exercise.grade
            },
            set: { newValue in
                if viewModel.isRecording {
                    viewModel.recordedExercise?.updateGrade(newValue)
                } else {
                    viewModel.exercise.grade = newValue
                }
            }
        )
    }
    
    private var gradeTriedBinding: Binding<String?> {
        Binding(
            get: {
                if viewModel.isRecording {
                    return viewModel.recordedExercise?.gradeTried ?? viewModel.exercise.gradeTried
                }
                return viewModel.exercise.gradeTried
            },
            set: { newValue in
                if viewModel.isRecording {
                    viewModel.recordedExercise?.updateGradeTried(newValue)
                } else {
                    viewModel.exercise.gradeTried = newValue
                }
            }
        )
    }
    
    private var hamstringsBinding: Binding<Bool> {
        Binding(
            get: {
                if viewModel.isRecording {
                    return viewModel.recordedExercise?.hamstrings ?? false
                }
                return viewModel.exercise.hamstrings
            },
            set: { newValue in
                if viewModel.isRecording {
                    viewModel.recordedExercise?.updateHamstrings(newValue)
                } else {
                    viewModel.exercise.hamstrings = newValue
                }
            }
        )
    }
    
    private var hipsBinding: Binding<Bool> {
        Binding(
            get: {
                if viewModel.isRecording {
                    return viewModel.recordedExercise?.hips ?? false
                }
                return viewModel.exercise.hips
            },
            set: { newValue in
                if viewModel.isRecording {
                    viewModel.recordedExercise?.updateHips(newValue)
                } else {
                    viewModel.exercise.hips = newValue
                }
            }
        )
    }
    
    private var forearmsBinding: Binding<Bool> {
        Binding(
            get: {
                if viewModel.isRecording {
                    return viewModel.recordedExercise?.forearms ?? false
                }
                return viewModel.exercise.forearms
            },
            set: { newValue in
                if viewModel.isRecording {
                    viewModel.recordedExercise?.updateForearms(newValue)
                } else {
                    viewModel.exercise.forearms = newValue
                }
            }
        )
    }
    
    private var legsBinding: Binding<Bool> {
        Binding(
            get: {
                if viewModel.isRecording {
                    return viewModel.recordedExercise?.legs ?? false
                }
                return viewModel.exercise.legs
            },
            set: { newValue in
                if viewModel.isRecording {
                    viewModel.recordedExercise?.updateLegs(newValue)
                } else {
                    viewModel.exercise.legs = newValue
                }
            }
        )
    }
    
    var body: some View {
        Form {
            // Exercise Type and Focus Section
            Section(header: Text("Exercise Type")) {
                HStack {
                    Image(viewModel.exercise.type.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 45)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading) {
                        Text(viewModel.exercise.type.rawValue)
                            .font(.headline)
                        
                        if let focus = viewModel.exercise.focus {
                            Text(focus.rawValue)
                                .font(.subheadline)
                                .foregroundColor(focus.color)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Exercise-specific parameters
            switch viewModel.exercise.type {
            case .hangboarding:
                hangboardingSection
            case .repeaters:
                repeatersSection
            case .limitBouldering:
                limitBoulderingSection
            case .nxn:
                nxnSection
            case .boulderCampus:
                boulderCampusSection
            case .deadlifts:
                deadliftsSection
            case .shoulderLifts:
                shoulderLiftsSection
            case .pullups:
                pullupsSection
            case .boardClimbing:
                boardClimbingSection
            case .edgePickups:
                edgePickupsSection
            case .maxHangs:
                maxHangsSection
            case .flexibility:
                flexibilitySection
            }
        }
    }
    
    // MARK: - Exercise Sections
    
    private var hangboardingSection: some View {
        Group {
            Section(header: Text("Grip Type")) {
                Picker("Grip Type", selection: viewModel.isRecording ? 
                    Binding(get: { viewModel.recordedExercise?.gripType ?? viewModel.exercise.gripType },
                           set: { viewModel.recordedExercise?.updateGripType($0) }) :
                    Binding(get: { viewModel.exercise.gripType },
                           set: { viewModel.exercise.gripType = $0 })) {
                    ForEach(GripType.allCases, id: \.self) { grip in
                        Text(grip.rawValue).tag(grip as GripType?)
                    }
                }
            }
            
            Section(header: Text("Parameters")) {
                ExerciseStepper(
                    title: "Edge Size",
                    value: viewModel.createEdgeSizeBinding().wrappedValue,
                    binding: viewModel.createEdgeSizeBinding(),
                    range: 5...30
                )
                
                ExerciseStepper(
                    title: "Duration",
                    value: viewModel.createDurationBinding().wrappedValue,
                    binding: viewModel.createDurationBinding(),
                    range: 1...60
                )
                
                ExerciseStepper(
                    title: "Repetitions",
                    value: viewModel.createSetsBinding().wrappedValue,
                    binding: viewModel.createSetsBinding(),
                    range: 1...20
                )
                
                ExerciseStepper(
                    title: "Sets",
                    value: viewModel.createSetsBinding().wrappedValue,
                    binding: viewModel.createSetsBinding(),
                    range: 1...10
                )
                
                ExerciseStepper(
                    title: "Added Weight",
                    value: viewModel.createAddedWeightBinding().wrappedValue,
                    binding: viewModel.createAddedWeightBinding(),
                    range: 0...90,
                    step: 0.5,
                    format: "%.1f"
                )
            }
        }
    }
    
    private var repeatersSection: some View {
        Section(header: Text("Parameters")) {
            ExerciseStepper(
                title: "Duration",
                value: viewModel.createDurationBinding().wrappedValue,
                binding: viewModel.createDurationBinding(),
                range: 1...60
            )
            
            ExerciseStepper(
                title: "Repetitions",
                value: viewModel.createSetsBinding().wrappedValue,
                binding: viewModel.createSetsBinding(),
                range: 1...20
            )
            
            ExerciseStepper(
                title: "Sets",
                value: viewModel.createSetsBinding().wrappedValue,
                binding: viewModel.createSetsBinding(),
                range: 1...10
            )
            
            ExerciseStepper(
                title: "Rest Duration",
                value: viewModel.createRestDurationBinding().wrappedValue,
                binding: viewModel.createRestDurationBinding(),
                range: 1...10
            )
            
            ExerciseStepper(
                title: "Added Weight",
                value: viewModel.createAddedWeightBinding().wrappedValue,
                binding: viewModel.createAddedWeightBinding(),
                range: 0...90,
                step: 0.5,
                format: "%.1f"
            )
        }
    }
    
    private var limitBoulderingSection: some View {
        Group {
            Section(header: Text("Grade")) {
                Picker("Grade", selection: gradeBinding) {
                    ForEach((1...17).reversed(), id: \.self) { grade in
                        Text("V\(grade)").tag("V\(grade)" as String?)
                    }
                }
            }
            
            Section(header: Text("Parameters")) {
                ExerciseStepper(
                    title: "Routes",
                    value: viewModel.createSetsBinding().wrappedValue,
                    binding: viewModel.createSetsBinding(),
                    range: 1...20
                )
                
                ExerciseStepper(
                    title: "Attempts",
                    value: viewModel.createSetsBinding().wrappedValue,
                    binding: viewModel.createSetsBinding(),
                    range: 1...10
                )
                
                ExerciseStepper(
                    title: "Rest Between Routes",
                    value: viewModel.createRestDurationBinding().wrappedValue,
                    binding: viewModel.createRestDurationBinding(),
                    range: 1...10
                )
                
                ExerciseStepper(
                    title: "Session Duration",
                    value: viewModel.createDurationBinding().wrappedValue,
                    binding: viewModel.createDurationBinding(),
                    range: 10...120,
                    step: 5
                )
            }
        }
    }
    
    private var nxnSection: some View {
        Group {
            Section(header: Text("Grade")) {
                Picker("Grade", selection: gradeBinding) {
                    ForEach((1...17).reversed(), id: \.self) { grade in
                        Text("V\(grade)").tag("V\(grade)" as String?)
                    }
                }
            }
            
            Section(header: Text("Parameters")) {
                ExerciseStepper(
                    title: "Routes",
                    value: viewModel.createSetsBinding().wrappedValue,
                    binding: viewModel.createSetsBinding(),
                    range: 1...20
                )
                
                ExerciseStepper(
                    title: "Sets",
                    value: viewModel.createSetsBinding().wrappedValue,
                    binding: viewModel.createSetsBinding(),
                    range: 1...10
                )
                
                ExerciseStepper(
                    title: "Rest Between Sets",
                    value: viewModel.createRestDurationBinding().wrappedValue,
                    binding: viewModel.createRestDurationBinding(),
                    range: 1...10
                )
            }
        }
    }
    
    private var boulderCampusSection: some View {
        Section(header: Text("Parameters")) {
            ExerciseStepper(
                title: "Moves",
                value: viewModel.createSetsBinding().wrappedValue,
                binding: viewModel.createSetsBinding(),
                range: 1...40
            )
            
            ExerciseStepper(
                title: "Sets",
                value: viewModel.createSetsBinding().wrappedValue,
                binding: viewModel.createSetsBinding(),
                range: 1...10
            )
            
            ExerciseStepper(
                title: "Rest Between Sets",
                value: viewModel.createRestDurationBinding().wrappedValue,
                binding: viewModel.createRestDurationBinding(),
                range: 1...10
            )
        }
    }
    
    private var deadliftsSection: some View {
        Section(header: Text("Parameters")) {
            ExerciseStepper(
                title: "Weight",
                value: viewModel.createAddedWeightBinding().wrappedValue,
                binding: viewModel.createAddedWeightBinding(),
                range: 0...200,
                step: 0.5,
                format: "%.1f"
            )
            
            ExerciseStepper(
                title: "Repetitions",
                value: viewModel.createSetsBinding().wrappedValue,
                binding: viewModel.createSetsBinding(),
                range: 1...20
            )
            
            ExerciseStepper(
                title: "Sets",
                value: viewModel.createSetsBinding().wrappedValue,
                binding: viewModel.createSetsBinding(),
                range: 1...10
            )
            
            ExerciseStepper(
                title: "Rest Between Sets",
                value: viewModel.createRestDurationBinding().wrappedValue,
                binding: viewModel.createRestDurationBinding(),
                range: 1...10
            )
        }
    }
    
    private var shoulderLiftsSection: some View {
        Section(header: Text("Parameters")) {
            ExerciseStepper(
                title: "Weight",
                value: viewModel.createAddedWeightBinding().wrappedValue,
                binding: viewModel.createAddedWeightBinding(),
                range: 0...50,
                step: 0.5,
                format: "%.1f"
            )
            
            ExerciseStepper(
                title: "Repetitions",
                value: viewModel.createSetsBinding().wrappedValue,
                binding: viewModel.createSetsBinding(),
                range: 1...50
            )
            
            ExerciseStepper(
                title: "Sets",
                value: viewModel.createSetsBinding().wrappedValue,
                binding: viewModel.createSetsBinding(),
                range: 1...10
            )
            
            ExerciseStepper(
                title: "Rest Between Sets",
                value: viewModel.createRestDurationBinding().wrappedValue,
                binding: viewModel.createRestDurationBinding(),
                range: 1...10
            )
        }
    }
    
    private var pullupsSection: some View {
        Section(header: Text("Parameters")) {
            ExerciseStepper(
                title: "Added Weight",
                value: viewModel.createAddedWeightBinding().wrappedValue,
                binding: viewModel.createAddedWeightBinding(),
                range: -20...50,
                step: 0.5,
                format: "%.1f"
            )
            
            ExerciseStepper(
                title: "Repetitions",
                value: viewModel.createSetsBinding().wrappedValue,
                binding: viewModel.createSetsBinding(),
                range: 1...50
            )
            
            ExerciseStepper(
                title: "Sets",
                value: viewModel.createSetsBinding().wrappedValue,
                binding: viewModel.createSetsBinding(),
                range: 1...10
            )
            
            ExerciseStepper(
                title: "Rest Between Sets",
                value: viewModel.createRestDurationBinding().wrappedValue,
                binding: viewModel.createRestDurationBinding(),
                range: 1...10
            )
        }
    }
    
    private var boardClimbingSection: some View {
        Section(header: Text("Parameters")) {
            Picker("Board Type", selection: boardTypeBinding) {
                ForEach(BoardType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type as BoardType?)
                }
            }
            
            ExerciseStepper(
                title: "Number of Climbs",
                value: viewModel.createSetsBinding().wrappedValue,
                binding: viewModel.createSetsBinding(),
                range: 1...30
            )
            
            Picker("Grade Sent", selection: gradeBinding) {
                ForEach(["5+", "6A", "6A+", "6B", "6B+", "6C", "6C+", "7A", "7A+", "7B", "7B+", "7C", "7C+", "8A"], id: \.self) { grade in
                    Text(grade).tag(grade as String?)
                }
            }
            
            Picker("Grade Tried", selection: gradeTriedBinding) {
                ForEach(["5+", "6A", "6A+", "6B", "6B+", "6C", "6C+", "7A", "7A+", "7B", "7B+", "7C", "7C+", "8A"], id: \.self) { grade in
                    Text(grade).tag(grade as String?)
                }
            }
        }
    }
    
    private var edgePickupsSection: some View {
        Section(header: Text("Parameters")) {
            edgeSizeStepper
            durationStepper
            setsStepper
            restDurationStepper
            addedWeightStepper
        }
    }
    
    private var edgeSizeStepper: some View {
        ExerciseStepper(
            title: "Edge Size",
            value: viewModel.createEdgeSizeBinding().wrappedValue,
            binding: viewModel.createEdgeSizeBinding(),
            range: 5...30
        )
    }
    
    private var durationStepper: some View {
        ExerciseStepper(
            title: "Duration",
            value: viewModel.createDurationBinding().wrappedValue,
            binding: viewModel.createDurationBinding(),
            range: 1...30
        )
    }
    
    private var setsStepper: some View {
        ExerciseStepper(
            title: "Sets",
            value: viewModel.createSetsBinding().wrappedValue,
            binding: viewModel.createSetsBinding(),
            range: 1...12
        )
    }
    
    private var restDurationStepper: some View {
        ExerciseStepper(
            title: "Rest Between Sets",
            value: viewModel.createRestDurationBinding().wrappedValue,
            binding: viewModel.createRestDurationBinding(),
            range: 1...10
        )
    }
    
    private var addedWeightStepper: some View {
        ExerciseStepper(
            title: "Added Weight",
            value: viewModel.createAddedWeightBinding().wrappedValue,
            binding: viewModel.createAddedWeightBinding(),
            range: 0...60,
            step: 0.5,
            format: "%.1f"
        )
    }
    
    private var maxHangsSection: some View {
        Section(header: Text("Parameters")) {
            ExerciseStepper(
                title: "Edge Size",
                value: viewModel.createEdgeSizeBinding().wrappedValue,
                binding: viewModel.createEdgeSizeBinding(),
                range: 5...30
            )
            
            ExerciseStepper(
                title: "Duration",
                value: viewModel.createDurationBinding().wrappedValue,
                binding: viewModel.createDurationBinding(),
                range: 1...30
            )
            
            ExerciseStepper(
                title: "Sets",
                value: viewModel.createSetsBinding().wrappedValue,
                binding: viewModel.createSetsBinding(),
                range: 1...12
            )
            
            ExerciseStepper(
                title: "Rest Between Sets",
                value: viewModel.createRestDurationBinding().wrappedValue,
                binding: viewModel.createRestDurationBinding(),
                range: 1...10
            )
            
            ExerciseStepper(
                title: "Added/Removed Weight",
                value: viewModel.createAddedWeightBinding().wrappedValue,
                binding: viewModel.createAddedWeightBinding(),
                range: -50...60,
                step: 0.5,
                format: "%.1f"
            )
        }
    }
    
    private var flexibilitySection: some View {
        Section(header: Text("Focus Areas")) {
            Toggle("Hamstrings", isOn: hamstringsBinding)
            Toggle("Hips", isOn: hipsBinding)
            Toggle("Forearms", isOn: forearmsBinding)
            Toggle("Legs", isOn: legsBinding)
        }
    }
} 