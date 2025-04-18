import Foundation
import SwiftData

enum GripType: String, CaseIterable, Codable {
    case halfCrimp = "Half Crimp"
    case open = "Open"
    case threeFingerDrag = "3-Finger Drag"
}

enum ExerciseType: String, CaseIterable, Codable {
    case hangboarding = "Hangboarding (Max Hang)"
    case repeaters = "Repeaters"
    case limitBouldering = "Limit Bouldering"
    
    var imageName: String {
        switch self {
        case .hangboarding:
            return "hangboarding"
        case .repeaters:
            return "repeaters"
        case .limitBouldering:
            return "limit_bouldering"
        }
    }
}

@Model
final class Exercise {
    var type: ExerciseType
    var gripType: GripType?
    var duration: Int?
    var repetitions: Int?
    var sets: Int?
    var addedWeight: Double?
    var restDuration: Int?
    var grade: String?
    var routes: Int?
    var attempts: Int?
    var restBetweenRoutes: Int?
    var sessionDuration: Int?
    
    init(type: ExerciseType) {
        self.type = type
        // Set default values based on exercise type
        switch type {
        case .hangboarding:
            self.gripType = .halfCrimp
            self.duration = 10
            self.repetitions = 6
            self.sets = 3
            self.addedWeight = 0
        case .repeaters:
            self.duration = 7
            self.repetitions = 6
            self.sets = 3
            self.restDuration = 2
            self.addedWeight = 0
        case .limitBouldering:
            self.grade = "V8"
            self.routes = 5
            self.attempts = 5
            self.restBetweenRoutes = 2
            self.sessionDuration = 30
        }
    }
} 