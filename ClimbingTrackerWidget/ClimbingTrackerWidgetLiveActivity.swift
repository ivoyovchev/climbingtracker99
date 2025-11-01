//
//  ClimbingTrackerWidgetLiveActivity.swift
//  ClimbingTrackerWidget
//
//  Created by Ivo Yovchev on 17/04/2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

// Old attributes for compatibility
struct ClimbingTrackerWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var emoji: String
    }
    var name: String
}

// Running activity attributes - must be defined in widget extension for Live Activities
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

struct RunningLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunningActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "figure.run")
                        .font(.title3)
                        .foregroundColor(.green)
                    Text("Running")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    if context.state.isPaused {
                        Text("PAUSED")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // Main stats
                HStack(spacing: 20) {
                    // Distance
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Distance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f", context.state.distance))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("km")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                        .frame(height: 50)
                    
                    // Duration
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatDuration(context.state.duration))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                    }
                    
                    Divider()
                        .frame(height: 50)
                    
                    // Pace
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pace")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatPace(context.state.averagePace))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("min/km")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Secondary stats
                HStack(spacing: 30) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("\(context.state.calories)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("kcal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "gauge.high")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(formatPace(context.state.currentPace))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("current")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .activityBackgroundTint(Color(.systemBackground))
            .activitySystemActionForegroundColor(Color.primary)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.run")
                                .font(.title3)
                                .foregroundColor(.green)
                            Text("Running")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        if context.state.isPaused {
                            Text("PAUSED")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatDuration(context.state.duration))
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 30) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.2f", context.state.distance))
                                .font(.title)
                                .fontWeight(.bold)
                            Text("km")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatPace(context.state.averagePace))
                                .font(.title)
                                .fontWeight(.bold)
                            Text("avg pace")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatPace(context.state.currentPace))
                                .font(.title)
                                .fontWeight(.bold)
                            Text("current")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 8)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: "figure.run")
                        .foregroundColor(.green)
                    Text(String(format: "%.2f", context.state.distance))
                        .fontWeight(.semibold)
                }
            } compactTrailing: {
                Text(formatPace(context.state.averagePace))
                    .fontWeight(.semibold)
            } minimal: {
                Image(systemName: "figure.run")
                    .foregroundColor(.green)
            }
            .keylineTint(Color.green)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 && pace < 100 else { return "--:--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Keep the old one for compatibility
struct ClimbingTrackerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClimbingTrackerWidgetAttributes.self) { context in
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension ClimbingTrackerWidgetAttributes {
    fileprivate static var preview: ClimbingTrackerWidgetAttributes {
        ClimbingTrackerWidgetAttributes(name: "World")
    }
}

extension ClimbingTrackerWidgetAttributes.ContentState {
    fileprivate static var smiley: ClimbingTrackerWidgetAttributes.ContentState {
        ClimbingTrackerWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ClimbingTrackerWidgetAttributes.ContentState {
         ClimbingTrackerWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ClimbingTrackerWidgetAttributes.preview) {
   ClimbingTrackerWidgetLiveActivity()
} contentStates: {
    ClimbingTrackerWidgetAttributes.ContentState.smiley
    ClimbingTrackerWidgetAttributes.ContentState.starEyes
}
