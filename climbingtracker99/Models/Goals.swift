import Foundation
import SwiftData

enum GoalType: String, Codable {
    case trainingFrequency = "Training Frequency"
    case weight = "Weight"
    case exercise = "Exercise"
    case technique = "Technique"
    case flexibility = "Flexibility"
}

@Model
final class Parameter {
    var key: String
    var value: String
    
    init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

@Model
final class Value {
    var key: String
    var value: Double
    
    init(key: String, value: Double) {
        self.key = key
        self.value = value
    }
}

@Model
final class ExerciseGoal {
    var id: UUID
    private var _exerciseType: String
    var exerciseType: ExerciseType {
        get { ExerciseType(rawValue: _exerciseType) ?? .hangboarding }
        set { _exerciseType = newValue.rawValue }
    }
    
    @Relationship(deleteRule: .cascade) var parameters: [Parameter]
    @Relationship(deleteRule: .cascade) var targetValues: [Value]
    @Relationship(deleteRule: .cascade) var currentValues: [Value]
    var deadline: Date?
    
    init(id: UUID = UUID(), 
         exerciseType: ExerciseType,
         parameters: [String: String] = [:],
         targetValues: [String: Double] = [:],
         currentValues: [String: Double] = [:],
         deadline: Date? = nil) {
        self.id = id
        self._exerciseType = exerciseType.rawValue
        self.parameters = parameters.map { Parameter(key: $0.key, value: $0.value) }
        self.targetValues = targetValues.map { Value(key: $0.key, value: $0.value) }
        self.currentValues = currentValues.map { Value(key: $0.key, value: $0.value) }
        self.deadline = deadline
    }
    
    // Helper methods to get exercise-specific parameters
    func getParameterValue<T>(_ key: String) -> T? where T: LosslessStringConvertible {
        guard let parameter = parameters.first(where: { $0.key == key }) else { return nil }
        return T(parameter.value)
    }
    
    func setParameterValue<T>(_ key: String, value: T) where T: LosslessStringConvertible {
        let stringValue = String(describing: value)
        if let index = parameters.firstIndex(where: { $0.key == key }) {
            parameters[index].value = stringValue
        } else {
            parameters.append(Parameter(key: key, value: stringValue))
        }
    }
    
    func getTargetValue(_ key: String) -> Double? {
        return targetValues.first(where: { $0.key == key })?.value
    }
    
    func setTargetValue(_ key: String, value: Double) {
        if let index = targetValues.firstIndex(where: { $0.key == key }) {
            targetValues[index].value = value
        } else {
            targetValues.append(Value(key: key, value: value))
        }
    }
    
    func getCurrentValue(_ key: String) -> Double? {
        return currentValues.first(where: { $0.key == key })?.value
    }
    
    func setCurrentValue(_ key: String, value: Double) {
        if let index = currentValues.firstIndex(where: { $0.key == key }) {
            currentValues[index].value = value
        } else {
            currentValues.append(Value(key: key, value: value))
        }
    }
    
    // Example for Hangboarding
    static func createHangboardingGoal(
        gripType: GripType,
        edgeSize: Int,
        duration: Int,
        addedWeight: Double,
        deadline: Date? = nil
    ) -> ExerciseGoal {
        let goal = ExerciseGoal(
            exerciseType: .hangboarding,
            parameters: [
                "gripType": gripType.rawValue,
                "edgeSize": String(edgeSize)
            ],
            targetValues: [
                "duration": Double(duration),
                "addedWeight": addedWeight
            ],
            currentValues: [
                "duration": 0,
                "addedWeight": 0
            ],
            deadline: deadline
        )
        return goal
    }
    
    // Example for Repeaters
    static func createRepeatersGoal(
        duration: Int,
        repetitions: Int,
        sets: Int,
        addedWeight: Double,
        deadline: Date? = nil
    ) -> ExerciseGoal {
        let goal = ExerciseGoal(
            exerciseType: .repeaters,
            parameters: [:],
            targetValues: [
                "duration": Double(duration),
                "repetitions": Double(repetitions),
                "sets": Double(sets),
                "addedWeight": addedWeight
            ],
            currentValues: [
                "duration": 0,
                "repetitions": 0,
                "sets": 0,
                "addedWeight": 0
            ],
            deadline: deadline
        )
        return goal
    }
}

@Model
final class Goals {
    var id: UUID
    var targetTrainingsPerWeek: Int
    var targetWeight: Double
    var startingWeight: Double?
    var lastUpdated: Date
    @Relationship(deleteRule: .cascade) var exerciseGoals: [ExerciseGoal]
    var techniqueGoals: [String]
    var flexibilityGoals: [String]
    var currentStreak: Int
    var longestStreak: Int
    var lastTrainingDate: Date?
    
    init(id: UUID = UUID(), 
         targetTrainingsPerWeek: Int = 3, 
         targetWeight: Double = 0.0, 
         startingWeight: Double? = nil,
         lastUpdated: Date = Date(),
         exerciseGoals: [ExerciseGoal] = [],
         techniqueGoals: [String] = [],
         flexibilityGoals: [String] = [],
         currentStreak: Int = 0,
         longestStreak: Int = 0,
         lastTrainingDate: Date? = nil) {
        self.id = id
        self.targetTrainingsPerWeek = targetTrainingsPerWeek
        self.targetWeight = targetWeight
        self.startingWeight = startingWeight
        self.lastUpdated = lastUpdated
        self.exerciseGoals = exerciseGoals
        self.techniqueGoals = techniqueGoals
        self.flexibilityGoals = flexibilityGoals
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastTrainingDate = lastTrainingDate
    }
    
    func updateStreak() {
        guard let lastDate = lastTrainingDate else {
            currentStreak = 1
            lastTrainingDate = Date()
            return
        }
        
        let calendar = Calendar.current
        let daysSinceLastTraining = calendar.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        
        if daysSinceLastTraining == 1 {
            currentStreak += 1
            if currentStreak > longestStreak {
                longestStreak = currentStreak
            }
        } else if daysSinceLastTraining > 1 {
            currentStreak = 1
        }
        
        lastTrainingDate = Date()
    }
} 