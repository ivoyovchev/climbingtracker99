import SwiftUI
import SwiftData

struct ExerciseEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var exercise: Exercise
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Exercise Image
                Image(exercise.type.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                
                // Form with parameters
                Form {
                    switch exercise.type {
                    case .hangboarding:
                        Section(header: Text("Grip Type")) {
                            Picker("Grip Type", selection: $exercise.gripType) {
                                ForEach(GripType.allCases, id: \.self) { grip in
                                    Text(grip.rawValue).tag(grip as GripType?)
                                }
                            }
                        }
                        
                        Section(header: Text("Parameters")) {
                            Stepper("Duration: \(exercise.duration ?? 0) sec", value: Binding(
                                get: { exercise.duration ?? 0 },
                                set: { exercise.duration = $0 }
                            ), in: 1...60)
                            
                            Stepper("Repetitions: \(exercise.repetitions ?? 0)", value: Binding(
                                get: { exercise.repetitions ?? 0 },
                                set: { exercise.repetitions = $0 }
                            ), in: 1...20)
                            
                            Stepper("Sets: \(exercise.sets ?? 0)", value: Binding(
                                get: { exercise.sets ?? 0 },
                                set: { exercise.sets = $0 }
                            ), in: 1...10)
                            
                            Stepper("Added Weight: \(String(format: "%.1f", exercise.addedWeight ?? 0)) kg", value: Binding(
                                get: { exercise.addedWeight ?? 0 },
                                set: { exercise.addedWeight = $0 }
                            ), in: 0...90, step: 0.5)
                        }
                        
                    case .repeaters:
                        Section(header: Text("Parameters")) {
                            Stepper("Duration: \(exercise.duration ?? 0) sec", value: Binding(
                                get: { exercise.duration ?? 0 },
                                set: { exercise.duration = $0 }
                            ), in: 1...60)
                            
                            Stepper("Repetitions: \(exercise.repetitions ?? 0)", value: Binding(
                                get: { exercise.repetitions ?? 0 },
                                set: { exercise.repetitions = $0 }
                            ), in: 1...20)
                            
                            Stepper("Sets: \(exercise.sets ?? 0)", value: Binding(
                                get: { exercise.sets ?? 0 },
                                set: { exercise.sets = $0 }
                            ), in: 1...10)
                            
                            Stepper("Rest Duration: \(exercise.restDuration ?? 0) min", value: Binding(
                                get: { exercise.restDuration ?? 0 },
                                set: { exercise.restDuration = $0 }
                            ), in: 1...10)
                            
                            Stepper("Added Weight: \(String(format: "%.1f", exercise.addedWeight ?? 0)) kg", value: Binding(
                                get: { exercise.addedWeight ?? 0 },
                                set: { exercise.addedWeight = $0 }
                            ), in: 0...90, step: 0.5)
                        }
                        
                    case .limitBouldering:
                        Section(header: Text("Grade")) {
                            Picker("Grade", selection: $exercise.grade) {
                                ForEach((1...17).reversed(), id: \.self) { grade in
                                    Text("V\(grade)").tag("V\(grade)" as String?)
                                }
                            }
                        }
                        
                        Section(header: Text("Parameters")) {
                            Stepper("Routes: \(exercise.routes ?? 0)", value: Binding(
                                get: { exercise.routes ?? 0 },
                                set: { exercise.routes = $0 }
                            ), in: 1...20)
                            
                            Stepper("Attempts: \(exercise.attempts ?? 0)", value: Binding(
                                get: { exercise.attempts ?? 0 },
                                set: { exercise.attempts = $0 }
                            ), in: 1...10)
                            
                            Stepper("Rest Between Routes: \(exercise.restBetweenRoutes ?? 0) min", value: Binding(
                                get: { exercise.restBetweenRoutes ?? 0 },
                                set: { exercise.restBetweenRoutes = $0 }
                            ), in: 1...10)
                            
                            Stepper("Session Duration: \(exercise.sessionDuration ?? 0) min", value: Binding(
                                get: { exercise.sessionDuration ?? 0 },
                                set: { exercise.sessionDuration = $0 }
                            ), in: 10...120, step: 5)
                        }
                    }
                }
            }
            .navigationTitle(exercise.type.rawValue)
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