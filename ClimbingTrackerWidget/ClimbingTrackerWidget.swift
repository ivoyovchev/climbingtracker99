//
//  ClimbingTrackerWidget.swift
//  ClimbingTrackerWidget
//
//  Created by Ivo Yovchev on 17/04/2025.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), trainingsLast7Days: 0, targetTrainingsPerWeek: 0, runsThisWeek: 0, targetRunsPerWeek: 0, distanceThisWeek: 0, targetDistancePerWeek: 0, currentWeight: 0, targetWeight: 0, startingWeight: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), trainingsLast7Days: 0, targetTrainingsPerWeek: 0, runsThisWeek: 0, targetRunsPerWeek: 0, distanceThisWeek: 0, targetDistancePerWeek: 0, currentWeight: 0, targetWeight: 0, startingWeight: 0)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.tornado-studios.climbingtracker99") else {
            let entry = SimpleEntry(date: Date(), trainingsLast7Days: 0, targetTrainingsPerWeek: 0, runsThisWeek: 0, targetRunsPerWeek: 0, distanceThisWeek: 0, targetDistancePerWeek: 0, currentWeight: 0, targetWeight: 0, startingWeight: 0)
            let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300))) // Update every 5 minutes
            completion(timeline)
            return
        }
        
        let fileURL = containerURL.appendingPathComponent("widgetData.json")
        
        do {
            let data = try Data(contentsOf: fileURL)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let trainingsLast7Days = json["trainingsLast7Days"] as? Int ?? 0
                let targetTrainingsPerWeek = json["targetTrainingsPerWeek"] as? Int ?? 0
                let runsThisWeek = json["runsThisWeek"] as? Int ?? 0
                let targetRunsPerWeek = json["targetRunsPerWeek"] as? Int ?? 0
                let distanceThisWeek = json["distanceThisWeek"] as? Double ?? 0
                let targetDistancePerWeek = json["targetDistancePerWeek"] as? Double ?? 0
                let currentWeight = json["currentWeight"] as? Double ?? 0
                let targetWeight = json["targetWeight"] as? Double ?? 0
                let startingWeight = json["startingWeight"] as? Double ?? 0
                
                let entry = SimpleEntry(
                    date: Date(),
                    trainingsLast7Days: trainingsLast7Days,
                    targetTrainingsPerWeek: targetTrainingsPerWeek,
                    runsThisWeek: runsThisWeek,
                    targetRunsPerWeek: targetRunsPerWeek,
                    distanceThisWeek: distanceThisWeek,
                    targetDistancePerWeek: targetDistancePerWeek,
                    currentWeight: currentWeight,
                    targetWeight: targetWeight,
                    startingWeight: startingWeight
                )
                
                // Update every 5 minutes
                let nextUpdate = Date().addingTimeInterval(300)
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
                return
            }
        } catch {
            print("Error reading widget data: \(error)")
        }
        
        let entry = SimpleEntry(date: Date(), trainingsLast7Days: 0, targetTrainingsPerWeek: 0, runsThisWeek: 0, targetRunsPerWeek: 0, distanceThisWeek: 0, targetDistancePerWeek: 0, currentWeight: 0, targetWeight: 0, startingWeight: 0)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300))) // Update every 5 minutes
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let trainingsLast7Days: Int
    let targetTrainingsPerWeek: Int
    let runsThisWeek: Int
    let targetRunsPerWeek: Int
    let distanceThisWeek: Double
    let targetDistancePerWeek: Double
    let currentWeight: Double
    let targetWeight: Double
    let startingWeight: Double
    
    var trainingProgress: Double {
        guard targetTrainingsPerWeek > 0 else { return 0 }
        return Double(trainingsLast7Days) / Double(targetTrainingsPerWeek)
    }
    
    var runningProgress: Double {
        guard targetRunsPerWeek > 0 else { return 0 }
        return Double(runsThisWeek) / Double(targetRunsPerWeek)
    }
    
    var distanceProgress: Double {
        guard targetDistancePerWeek > 0 else { return 0 }
        return distanceThisWeek / targetDistancePerWeek
    }
    
    var weightProgress: Double {
        guard currentWeight > 0, targetWeight > 0, startingWeight > 0 else { return 0 }
        
        if startingWeight > targetWeight {
            // Losing weight
            if currentWeight > startingWeight {
                // Over starting weight
                return 0.0
            } else if currentWeight < targetWeight {
                // Below target weight
                return 1.0
            } else {
                // Between starting and target
                let totalRange = startingWeight - targetWeight
                let currentRange = startingWeight - currentWeight
                return currentRange / totalRange
            }
        } else {
            // Gaining weight
            if currentWeight < startingWeight {
                // Below starting weight
                return 0.0
            } else if currentWeight > targetWeight {
                // Above target weight
                return 1.0
            } else {
                // Between starting and target
                let totalRange = targetWeight - startingWeight
                let currentRange = currentWeight - startingWeight
                return currentRange / totalRange
            }
        }
    }
}

struct ClimbingTrackerWidgetEntryView : View {
    var entry: SimpleEntry
    
    var body: some View {
        VStack(spacing: 10) {
            // 4 Circles Grid (2x2)
            VStack(spacing: 10) {
                // Top row
                HStack(spacing: 10) {
                    // Training Circle
                    GoalCircleView(
                        progress: entry.trainingProgress,
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Training",
                        subtitle: "\(entry.trainingsLast7Days)/\(entry.targetTrainingsPerWeek)",
                        color: .blue
                    )
                    
                    // Runs Circle
                    GoalCircleView(
                        progress: entry.runningProgress,
                        icon: "figure.run",
                        title: "Runs",
                        subtitle: "\(entry.runsThisWeek)/\(entry.targetRunsPerWeek)",
                        color: .green
                    )
                }
                
                // Bottom row
                HStack(spacing: 10) {
                    // Distance Circle
                    GoalCircleView(
                        progress: entry.distanceProgress,
                        icon: "map",
                        title: "Distance",
                        subtitle: String(format: "%.1f/%.0f km", entry.distanceThisWeek, entry.targetDistancePerWeek),
                        color: .purple
                    )
                    
                    // Weight Circle
                    GoalCircleView(
                        progress: entry.weightProgress,
                        icon: "scalemass",
                        title: "Weight",
                        subtitle: entry.currentWeight > 0 ? String(format: "%.1f kg", entry.currentWeight) : "—",
                        color: .orange
                    )
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
        )
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Goal Circle View Component

struct GoalCircleView: View {
    let progress: Double
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 3)
                    .frame(width: 45, height: 45)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 45, height: 45)
                    .rotationEffect(.degrees(-90))
                
                // Icon in center
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            
            // Title
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            // Subtitle
            Text(subtitle)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ClimbingTrackerWidget: Widget {
    let kind: String = "ClimbingTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ClimbingTrackerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Climbing Tracker")
        .description("Track your training progress and weight.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    ClimbingTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, trainingsLast7Days: 3, targetTrainingsPerWeek: 4, runsThisWeek: 2, targetRunsPerWeek: 3, distanceThisWeek: 15.5, targetDistancePerWeek: 20.0, currentWeight: 75.5, targetWeight: 72.0, startingWeight: 70.0)
}
