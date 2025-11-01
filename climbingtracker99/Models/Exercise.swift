import Foundation
import SwiftData

enum GripType: String, CaseIterable, Codable {
    case halfCrimp = "Half Crimp"
    case open = "Open"
    case threeFingerDrag = "3-Finger Drag"
}

enum BoardType: String, CaseIterable, Codable {
    case moonBoard = "MoonBoard"
    case kilterBoard = "KilterBoard"
    case frankieBoard = "FrankieBoard"
}

enum ExerciseType: String, CaseIterable, Codable {
    case hangboarding = "Hangboarding (Max Hang)"
    case repeaters = "Repeaters"
    case limitBouldering = "Limit Bouldering"
    case nxn = "N x Ns"
    case boulderCampus = "Boulder Campus"
    case deadlifts = "Deadlifts"
    case shoulderLifts = "Shoulder Lifts"
    case pullups = "Pull-ups"
    case boardClimbing = "Board Climbing"
    case edgePickups = "Edge Pickups"
    case flexibility = "Flexibility"
    case running = "Running"
    case warmup = "Warm Up"
    case circuit = "Circuit"
    case core = "Core"
    case campusing = "Campusing"
    
    // Custom decoder to handle migration from old "Hangboarding (Max Hang)" to new name
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        // Handle migration: accept both old and new names
        if rawValue == "Hangboarding (Max Hang)" || rawValue == "Max Hangs" {
            self = .hangboarding
            return
        }
        
        // Try to decode normally using the enum's rawValue initializer
        // We need to manually check each case to avoid recursion
        switch rawValue {
        case "Repeaters":
            self = .repeaters
        case "Limit Bouldering":
            self = .limitBouldering
        case "N x Ns":
            self = .nxn
        case "Boulder Campus":
            self = .boulderCampus
        case "Deadlifts":
            self = .deadlifts
        case "Shoulder Lifts":
            self = .shoulderLifts
        case "Pull-ups":
            self = .pullups
        case "Board Climbing":
            self = .boardClimbing
        case "Edge Pickups":
            self = .edgePickups
        case "Flexibility":
            self = .flexibility
        case "Running":
            self = .running
        case "Warm Up":
            self = .warmup
        case "Circuit":
            self = .circuit
        case "Core":
            self = .core
        case "Campusing":
            self = .campusing
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot initialize ExerciseType from invalid String value \(rawValue)")
        }
    }
    
    // Display name (for UI purposes)
    var displayName: String {
        switch self {
        case .hangboarding:
            return "Max Hangs"
        default:
            return self.rawValue
        }
    }
    
    var imageName: String {
        switch self {
        case .hangboarding:
            return "hangboarding"
        case .repeaters:
            return "repeaters"
        case .limitBouldering:
            return "limit_bouldering"
        case .nxn:
            return "n_x_ns"
        case .boulderCampus:
            return "boulder_campus"
        case .deadlifts:
            return "deadlifts"
        case .shoulderLifts:
            return "shoulder_lifts"
        case .pullups:
            return "pull_ups"
        case .boardClimbing:
            return "board_climbing"
        case .edgePickups:
            return "edge_pickups"
        case .flexibility:
            return "flexibility"
        case .running:
            return "running"
        case .warmup:
            return "flexibility" // Use flexibility icon for warmup
        case .circuit:
            return "boulder_campus" // Use boulder campus icon for circuit
        case .core:
            return "flexibility" // Use flexibility icon for core
        case .campusing:
            return "boulder_campus"
        }
    }
    
    // Detail options for live recording (can be customized per exercise type)
    var detailOptions: [String] {
        switch self {
        case .hangboarding:
            return ["Half Crimp", "Open", "3-Finger Drag"]
        case .repeaters:
            return ["Arms", "Fingers", "Back", "Core"]
        case .limitBouldering:
            return ["Power", "Technique", "Endurance", "Strength"]
        case .nxn:
            return ["Routes", "Boulders", "Technical"]
        case .boulderCampus:
            return ["Power", "Coordination", "Explosiveness"]
        case .deadlifts:
            return ["Heavy", "Light", "Technique"]
        case .shoulderLifts:
            return ["Arms", "Shoulders", "Stability"]
        case .pullups:
            return ["Arms", "Back", "Weighted", "Bodyweight"]
        case .boardClimbing:
            return ["MoonBoard", "KilterBoard", "FrankieBoard", "Technique"]
        case .edgePickups:
            return ["Fingers", "Grip Strength", "Endurance"]
        case .flexibility:
            return ["Hamstrings", "Hips", "Forearms", "Legs", "Back"]
        case .running:
            return ["Cardio", "Endurance", "Speed", "Recovery"]
        case .warmup:
            return ["Arms", "Fingers", "Back", "Legs", "Mobility", "Core"]
        case .circuit:
            return ["Free Climbing", "Time Based", "Endurance", "Technique"]
        case .core:
            return ["Abs", "Full Core", "Lower Back", "Obliques"]
        case .campusing:
            return ["Power", "Strength", "Coordination", "Dynamic"]
        }
    }
    
    // Check if exercise type supports detail options
    var supportsDetailOptions: Bool {
        return !detailOptions.isEmpty
    }
}

@Model
final class Exercise {
    var type: ExerciseType
    var focus: TrainingFocus?
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
    var boardType: BoardType?
    var gradeTried: String?
    var moves: Int?
    var weight: Double?
    var edgeSize: Int?
    var hamstrings: Bool = false
    var hips: Bool = false
    var forearms: Bool = false
    var legs: Bool = false
    // Running specific properties
    var hours: Int?
    var minutes: Int?
    var distance: Double?
    
    init(type: ExerciseType, focus: TrainingFocus? = .strength) {
        self.type = type
        self.focus = focus
        // Set default values based on exercise type
        switch type {
        case .hangboarding:
            self.gripType = .halfCrimp
            self.duration = 10
            self.repetitions = 6
            self.sets = 3
            self.restDuration = 2
            self.addedWeight = 0
            self.edgeSize = 20
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
        case .nxn:
            self.grade = "V5"
            self.routes = 4
            self.sets = 4
            self.restDuration = 2
        case .boulderCampus:
            self.moves = 15
            self.restDuration = 2
            self.sets = 3
        case .deadlifts:
            self.repetitions = 5
            self.restDuration = 2
            self.sets = 3
            self.weight = 50
        case .shoulderLifts:
            self.repetitions = 20
            self.restDuration = 2
            self.sets = 3
            self.weight = 10
        case .pullups:
            self.repetitions = 5
            self.restDuration = 3
            self.sets = 3
            self.addedWeight = 0
        case .boardClimbing:
            self.boardType = .moonBoard
            self.routes = 5
            self.grade = "V6"
            self.gradeTried = "V8"
        case .edgePickups:
            self.duration = 15
            self.restDuration = 2
            self.sets = 6
            self.addedWeight = 30
            self.edgeSize = 20
        case .flexibility:
            self.duration = 15
            self.hamstrings = false
            self.hips = false
            self.forearms = false
            self.legs = false
        case .running:
            self.hours = 0
            self.minutes = 30
            self.distance = 5.0
            self.focus = .endurance
        case .warmup:
            self.duration = 10
            self.focus = .mobility
        case .circuit:
            self.duration = 60
            self.sets = 3
            self.restDuration = 60
            self.focus = .endurance
        case .core:
            self.duration = 45
            self.sets = 3
            self.restDuration = 30
            self.focus = .mobility
        case .campusing:
            self.sets = 3
            self.restDuration = 60
            self.edgeSize = 20
            self.focus = .power
        }
    }
} 