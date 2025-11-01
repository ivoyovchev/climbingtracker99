import Foundation
import SwiftData

enum BenchmarkType: String, CaseIterable, Codable {
    case maxPullups = "Max Pullups"
    case maxPullupWith3Reps = "Max Pull-up with 3 reps"
    case maxCampusMoves30mm = "Max Campus Moves 30mm"
    case maxLockoff1HandLeft = "Max Lockoff 1 hand (Left)"
    case maxLockoff1HandRight = "Max Lockoff 1 hand (Right)"
    case maxLockoff2Hands = "Max Lockoff 2 hands"
    case maxGripHang30mm = "Max Grip Hang 30mm"
    case maxHangTime10mm = "Max Hang Time on 10mm"
    case maxHangTime15mm = "Max Hang Time on 15mm"
    case maxHangTime20mm = "Max Hang Time on 20mm"
    case maxHangTime30mm = "Max Hang Time on 30mm"
    case maxRepeaters10mm = "Max Repeaters 10mm"
    case maxRepeaters15mm = "Max Repeaters 15mm"
    case maxRepeaters20mm = "Max Repeaters 20mm"
    case maxEdgePull20mm = "Max Edge Pull 20mm"
    
    var displayName: String {
        return rawValue
    }
    
    var iconName: String {
        switch self {
        case .maxPullups, .maxPullupWith3Reps:
            return "arrow.up.circle.fill" // Valid SF Symbol for pull-ups
        case .maxCampusMoves30mm:
            return "figure.climbing"
        case .maxLockoff1HandLeft, .maxLockoff1HandRight, .maxLockoff2Hands:
            return "hand.raised"
        case .maxGripHang30mm, .maxHangTime10mm, .maxHangTime15mm, .maxHangTime20mm, .maxHangTime30mm:
            return "figure.climbing"
        case .maxRepeaters10mm, .maxRepeaters15mm, .maxRepeaters20mm:
            return "repeat"
        case .maxEdgePull20mm:
            return "hand.point.up"
        }
    }
    
    var unit: String {
        switch self {
        case .maxPullups:
            return "reps"
        case .maxPullupWith3Reps, .maxGripHang30mm, .maxEdgePull20mm:
            return "kg"
        case .maxCampusMoves30mm:
            return "moves"
        case .maxLockoff1HandLeft, .maxLockoff1HandRight, .maxLockoff2Hands, .maxHangTime10mm, .maxHangTime15mm, .maxHangTime20mm, .maxHangTime30mm, .maxRepeaters10mm, .maxRepeaters15mm, .maxRepeaters20mm:
            return "seconds"
        }
    }
    
    var description: String {
        switch self {
        case .maxPullups:
            return "Maximum number of pullups with body weight"
        case .maxPullupWith3Reps:
            return "Maximum weight (kg) for 3 pullup repetitions"
        case .maxCampusMoves30mm:
            return "Maximum campus moves on 30mm edge without rest"
        case .maxLockoff1HandLeft:
            return "Maximum time to hold lockoff with left hand"
        case .maxLockoff1HandRight:
            return "Maximum time to hold lockoff with right hand"
        case .maxLockoff2Hands:
            return "Maximum time to hold lockoff with 2 hands"
        case .maxGripHang30mm:
            return "Maximum weight (kg) you can hang for 5 seconds on 30mm edge"
        case .maxHangTime10mm:
            return "Maximum time you can hang on 10mm edge with body weight"
        case .maxHangTime15mm:
            return "Maximum time you can hang on 15mm edge with body weight"
        case .maxHangTime20mm:
            return "Maximum time you can hang on 20mm edge with body weight"
        case .maxHangTime30mm:
            return "Maximum time you can hang on 30mm edge with body weight"
        case .maxRepeaters10mm:
            return "How long you can repeat 10sec on, 10sec off on 10mm edge"
        case .maxRepeaters15mm:
            return "How long you can repeat 10sec on, 10sec off on 15mm edge"
        case .maxRepeaters20mm:
            return "How long you can repeat 10sec on, 10sec off on 20mm edge"
        case .maxEdgePull20mm:
            return "Maximum pull strength (kg) on each hand on 20mm edge"
        }
    }
    
    var requiresTwoHands: Bool {
        return self == .maxEdgePull20mm
    }
}

@Model
final class PlannedBenchmark {
    var date: Date
    var benchmarkType: BenchmarkType
    var estimatedTime: Date? // Time of day for the benchmark (default 5:30 PM)
    var notes: String?
    
    // Results (filled when benchmark is completed)
    var completed: Bool = false
    var resultValue1: Double? // Main result value
    var resultValue2: Double? // Secondary result (e.g., left/right hand, or second measurement)
    var resultNotes: String?
    var completedDate: Date?
    
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
            return Self.defaultTime
        }
        set {
            estimatedTime = newValue
        }
    }
    
    init(date: Date, benchmarkType: BenchmarkType, estimatedTime: Date? = nil, notes: String? = nil) {
        self.date = date
        self.benchmarkType = benchmarkType
        self.estimatedTime = estimatedTime ?? Self.defaultTime
        self.notes = notes
        self.completed = false
    }
}

