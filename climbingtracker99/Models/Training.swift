import Foundation
import SwiftData
import Combine

enum TrainingLocation: String, CaseIterable, Codable {
    case indoor = "Indoor"
    case outdoor = "Outdoor"
}

enum TrainingFocus: String, CaseIterable, Codable {
    case strength = "Strength"
    case power = "Power"
    case endurance = "Endurance"
    case technique = "Technique"
    case mobility = "Mobility"
}

@Model
final class RecordedExercise: ObservableObject {
    var exercise: Exercise
    var gripType: GripType?
    var duration: Int?
    var repetitions: Int?
    var sets: Int?
    var addedWeight: Int?
    var restDuration: Int?
    var grade: String?
    var routes: Int?
    var attempts: Int?
    var restBetweenRoutes: Int?
    var sessionDuration: Int?
    
    // ObservableObject conformance - marked as non-persisted
    @Transient
    var objectWillChange = PassthroughSubject<Void, Never>()
    
    init(exercise: Exercise) {
        self.exercise = exercise
    }
    
    // Helper method to update a property and notify observers
    private func update<T>(_ keyPath: ReferenceWritableKeyPath<RecordedExercise, T>, value: T) {
        self[keyPath: keyPath] = value
        objectWillChange.send()
    }
    
    // UI binding methods
    func updateGripType(_ value: GripType?) {
        update(\.gripType, value: value)
    }
    
    func updateDuration(_ value: Int?) {
        update(\.duration, value: value)
    }
    
    func updateRepetitions(_ value: Int?) {
        update(\.repetitions, value: value)
    }
    
    func updateSets(_ value: Int?) {
        update(\.sets, value: value)
    }
    
    func updateAddedWeight(_ value: Int?) {
        update(\.addedWeight, value: value)
    }
    
    func updateRestDuration(_ value: Int?) {
        update(\.restDuration, value: value)
    }
    
    func updateGrade(_ value: String?) {
        update(\.grade, value: value)
    }
    
    func updateRoutes(_ value: Int?) {
        update(\.routes, value: value)
    }
    
    func updateAttempts(_ value: Int?) {
        update(\.attempts, value: value)
    }
    
    func updateRestBetweenRoutes(_ value: Int?) {
        update(\.restBetweenRoutes, value: value)
    }
    
    func updateSessionDuration(_ value: Int?) {
        update(\.sessionDuration, value: value)
    }
}

@Model
final class Training {
    var date: Date
    var duration: Int // in minutes
    var location: TrainingLocation
    var focus: TrainingFocus
    var recordedExercises: [RecordedExercise]
    var notes: String
    
    init(date: Date = Date(), duration: Int = 60, location: TrainingLocation = .indoor, 
         focus: TrainingFocus = .strength, recordedExercises: [RecordedExercise] = [], notes: String = "") {
        self.date = date
        self.duration = duration
        self.location = location
        self.focus = focus
        self.recordedExercises = recordedExercises
        self.notes = notes
    }
} 