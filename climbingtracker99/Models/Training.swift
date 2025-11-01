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
    var boardType: BoardType?
    var gradeTried: String?
    var moves: Int?
    var weight: Int?
    var edgeSize: Int?
    // New flexibility parameters
    var hamstrings: Bool = false
    var hips: Bool = false
    var forearms: Bool = false
    var legs: Bool = false
    // Running specific properties
    var hours: Int?
    var minutes: Int?
    var distance: Double?
    var notes: String?
    
    // Live recording timing fields
    var recordedStartTime: Date?
    var recordedEndTime: Date?
    var recordedDuration: Int? // in seconds
    var pausedDuration: Int = 0 // total paused time in seconds
    var isCompleted: Bool = false
    var selectedDetailOptionsData: String = "" // JSON array of strings, e.g., ["Arms", "Fingers"] for Warmup
    
    // Pullups set tracking (stored as JSON string)
    var pullupSetsData: String = "" // JSON array of {reps: Int, weight: Int, restDuration: Int}
    
    // NxN set tracking (stored as JSON string)
    var nxnSetsData: String = "" // JSON array of {problems: Int, completed: Bool, restDuration: Int, grades: [String]}
    
    // Board climbing route tracking (stored as JSON string)
    var boardClimbingRoutesData: String = "" // JSON array of {boardType: String, grade: String, tries: Int, sent: Bool}
    
    // Shoulder lifts set tracking (stored as JSON string)
    var shoulderLiftsSetsData: String = "" // JSON array of {reps: Int, weight: Int, restDuration: Int}
    
    // Repeaters set tracking (stored as JSON string)
    var repeatersSetsData: String = "" // JSON array of {edgeSize: Int, hangTime: Int, restTime: Int, repeats: Int, addedWeight: Int, completed: Bool}
    
    // Edge pickups set tracking (stored as JSON string)
    var edgePickupsSetsData: String = "" // JSON array of {edgeSize: Int, hangTime: Int, restTime: Int, repeats: Int, gripType: String, addedWeight: Int, completed: Bool}
    
    // Limit bouldering route tracking (stored as JSON string)
    var limitBoulderingRoutesData: String = "" // JSON array of {boulderType: String, grade: String, tries: Int, sent: Bool, name: String?}
    
    // Max Hangs set tracking (stored as JSON string)
    var maxHangsSetsData: String = "" // JSON array of {edgeSize: Int, duration: Int, restDuration: Int, addedWeight: Int}
    
    // Boulder Campus set tracking (stored as JSON string)
    var boulderCampusSetsData: String = "" // JSON array of {moves: Int, restDuration: Int}
    
    // Deadlifts set tracking (stored as JSON string)
    var deadliftsSetsData: String = "" // JSON array of {reps: Int, weight: Int, restDuration: Int}
    
    // Benchmark results tracking (stored as JSON string)
    var benchmarkResultsData: String = "" // JSON array of {benchmarkType: String, value1: Double, value2: Double?, date: String}
    
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
    
    func updateGradeTried(_ value: String?) {
        update(\.gradeTried, value: value)
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
    
    func updateMoves(_ value: Int?) {
        update(\.moves, value: value)
    }
    
    func updateWeight(_ value: Int?) {
        update(\.weight, value: value)
    }
    
    func updateEdgeSize(_ value: Int?) {
        update(\.edgeSize, value: value)
    }
    
    // New flexibility update methods
    func updateHamstrings(_ value: Bool) {
        update(\.hamstrings, value: value)
    }
    
    func updateHips(_ value: Bool) {
        update(\.hips, value: value)
    }
    
    func updateForearms(_ value: Bool) {
        update(\.forearms, value: value)
    }
    
    func updateLegs(_ value: Bool) {
        update(\.legs, value: value)
    }
    
    // Add the missing updateBoardType method
    func updateBoardType(_ value: BoardType?) {
        update(\.boardType, value: value)
    }
    
    func updateHours(_ value: Int?) {
        update(\.hours, value: value)
    }
    
    func updateMinutes(_ value: Int?) {
        update(\.minutes, value: value)
    }
    
    func updateDistance(_ value: Double?) {
        update(\.distance, value: value)
    }
    
    func updateNotes(_ value: String?) {
        update(\.notes, value: value)
    }
    
    // Computed property for selectedDetailOptions (converted from/to JSON)
    var selectedDetailOptions: [String] {
        get {
            guard !selectedDetailOptionsData.isEmpty,
                  let data = selectedDetailOptionsData.data(using: .utf8),
                  let array = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return array
        }
        set {
            if let jsonData = try? JSONEncoder().encode(newValue),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                selectedDetailOptionsData = jsonString
                objectWillChange.send()
            }
        }
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
    var media: [Media]
    
    // Live recording fields
    var isRecorded: Bool = false // true if this was recorded live
    var recordingStartTime: Date?
    var recordingEndTime: Date?
    var totalRecordedDuration: Int? // in seconds
    
    init(date: Date = Date(), duration: Int = 60, location: TrainingLocation = .indoor, 
         focus: TrainingFocus = .strength, recordedExercises: [RecordedExercise] = [], 
         notes: String = "", media: [Media] = [], isRecorded: Bool = false,
         recordingStartTime: Date? = nil) {
        self.date = date
        self.duration = duration
        self.location = location
        self.focus = focus
        self.recordedExercises = recordedExercises
        self.notes = notes
        self.media = media
        self.isRecorded = isRecorded
        self.recordingStartTime = recordingStartTime ?? (isRecorded ? Date() : nil)
    }
    
    static func fetchTrainings(from startDate: Date, to endDate: Date) -> [Training] {
        let descriptor = FetchDescriptor<Training>(
            predicate: #Predicate<Training> { training in
                training.date >= startDate && training.date <= endDate
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            // Get the shared model container from the app
            let container = try ModelContainer(for: Training.self, configurations: ModelConfiguration(isStoredInMemoryOnly: false))
            let context = ModelContext(container)
            return try context.fetch(descriptor)
        } catch {
            print("Error fetching trainings: \(error)")
            return []
        }
    }
} 