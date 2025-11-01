import Foundation
import ActivityKit

// Running Live Activity Attributes
// Note: This is a duplicate definition that must match the one in ClimbingTrackerWidget
// The attributes must be defined in the widget extension for Live Activities to work,
// but we define it here too so the main app can reference it for type checking.
// In production, this file should be included in both the main app and widget extension targets.
struct RunningActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic running stats that update in real-time
        var distance: Double // in kilometers
        var duration: TimeInterval // in seconds
        var averagePace: Double // min/km
        var currentPace: Double // min/km
        var calories: Int
        var isPaused: Bool
    }

    // Fixed non-changing properties
    var startTime: Date
}

