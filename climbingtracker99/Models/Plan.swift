import Foundation
import SwiftData

enum RunningType: String, CaseIterable, Codable {
    case longRun = "Long Run"
    case easyRun = "Easy Run"
    case intervals = "Intervals"
    case tempoRun = "Tempo Run"
    case recoveryRun = "Recovery Run"
    case fartlek = "Fartlek"
    case hillRun = "Hill Run"
    case trackWorkout = "Track Workout"
}

@Model
final class PlannedTraining {
    var syncIdentifier: String?
    var date: Date
    var trainingType: ExerciseType // Keep for backward compatibility
    var exerciseTypesData: String = "" // JSON array of ExerciseType rawValues
    var estimatedDuration: Int // in minutes
    var estimatedTime: Date? // Time of day for the training (default 5:30 PM)
    var notes: String?
    
    // Computed property to get/set exercise types
    var exerciseTypes: [ExerciseType] {
        get {
            guard !exerciseTypesData.isEmpty,
                  let data = exerciseTypesData.data(using: .utf8),
                  let strings = try? JSONDecoder().decode([String].self, from: data) else {
                // Fallback to single trainingType for backward compatibility
                return [trainingType]
            }
            return strings.compactMap { ExerciseType(rawValue: $0) }
        }
        set {
            if let data = try? JSONEncoder().encode(newValue.map { $0.rawValue }),
               let jsonString = String(data: data, encoding: .utf8) {
                exerciseTypesData = jsonString
            }
            // Also update trainingType for backward compatibility (use first one)
            if let firstType = newValue.first {
                trainingType = firstType
            }
        }
    }
    
    // Helper to get default time (5:30 PM)
    static var defaultTime: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 17 // 5 PM
        components.minute = 30 // 30 minutes
        return calendar.date(from: components) ?? Date()
    }
    
    // Computed property to get/set time components
    var estimatedTimeOfDay: Date {
        get {
            if let time = estimatedTime {
                return time
            }
            // Return default 5:30 PM if not set
            return Self.defaultTime
        }
        set {
            estimatedTime = newValue
        }
    }
    
    init(date: Date, exerciseTypes: [ExerciseType], estimatedDuration: Int, estimatedTime: Date? = nil, notes: String? = nil, syncIdentifier: String? = nil) {
        self.syncIdentifier = syncIdentifier ?? UUID().uuidString
        self.date = date
        self.trainingType = exerciseTypes.first ?? .hangboarding // Fallback
        self.estimatedDuration = estimatedDuration
        self.estimatedTime = estimatedTime ?? Self.defaultTime // Default to 5:30 PM
        self.notes = notes
        self.exerciseTypes = exerciseTypes // This will set exerciseTypesData
    }
    
    // Convenience initializer for single exercise (backward compatibility)
    init(date: Date, trainingType: ExerciseType, estimatedDuration: Int, estimatedTime: Date? = nil, notes: String? = nil, syncIdentifier: String? = nil) {
        self.syncIdentifier = syncIdentifier ?? UUID().uuidString
        self.date = date
        self.trainingType = trainingType
        self.estimatedDuration = estimatedDuration
        self.estimatedTime = estimatedTime ?? Self.defaultTime // Default to 5:30 PM
        self.notes = notes
        self.exerciseTypes = [trainingType] // Set exerciseTypesData
    }
}

@Model
final class PlannedRun {
    var syncIdentifier: String?
    var date: Date
    var runningType: RunningType
    var estimatedDistance: Double // in km
    var estimatedTempo: Double? // minutes per km
    var estimatedDuration: Int // in minutes
    var estimatedTime: Date? // Time of day for the run (default 5:30 PM)
    var notes: String?
    
    // Helper to get default time (5:30 PM)
    static var defaultTime: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 17 // 5 PM
        components.minute = 30 // 30 minutes
        return calendar.date(from: components) ?? Date()
    }
    
    // Computed property to get/set time components
    var estimatedTimeOfDay: Date {
        get {
            if let time = estimatedTime {
                return time
            }
            // Return default 5:30 PM if not set
            return Self.defaultTime
        }
        set {
            estimatedTime = newValue
        }
    }
    
    init(date: Date, runningType: RunningType, estimatedDistance: Double, estimatedTempo: Double? = nil, estimatedDuration: Int, estimatedTime: Date? = nil, notes: String? = nil, syncIdentifier: String? = nil) {
        self.syncIdentifier = syncIdentifier ?? UUID().uuidString
        self.date = date
        self.runningType = runningType
        self.estimatedDistance = estimatedDistance
        self.estimatedTempo = estimatedTempo
        self.estimatedDuration = estimatedDuration
        self.estimatedTime = estimatedTime ?? Self.defaultTime // Default to 5:30 PM
        self.notes = notes
    }
}

