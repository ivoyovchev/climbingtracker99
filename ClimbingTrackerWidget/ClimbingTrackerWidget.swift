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
        SimpleEntry(date: Date(), trainingsLast7Days: 0, targetTrainingsPerWeek: 0, currentWeight: 0, targetWeight: 0, startingWeight: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), trainingsLast7Days: 0, targetTrainingsPerWeek: 0, currentWeight: 0, targetWeight: 0, startingWeight: 0)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.tornado-studios.climbingtracker99") else {
            let entry = SimpleEntry(date: Date(), trainingsLast7Days: 0, targetTrainingsPerWeek: 0, currentWeight: 0, targetWeight: 0, startingWeight: 0)
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
            return
        }
        
        let fileURL = containerURL.appendingPathComponent("widgetData.json")
        
        do {
            let data = try Data(contentsOf: fileURL)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let trainingsLast7Days = json["trainingsLast7Days"] as? Int ?? 0
                let targetTrainingsPerWeek = json["targetTrainingsPerWeek"] as? Int ?? 0
                let currentWeight = json["currentWeight"] as? Double ?? 0
                let targetWeight = json["targetWeight"] as? Double ?? 0
                let startingWeight = json["startingWeight"] as? Double ?? 0
                
                let entry = SimpleEntry(
                    date: Date(),
                    trainingsLast7Days: trainingsLast7Days,
                    targetTrainingsPerWeek: targetTrainingsPerWeek,
                    currentWeight: currentWeight,
                    targetWeight: targetWeight,
                    startingWeight: startingWeight
                )
                let timeline = Timeline(entries: [entry], policy: .atEnd)
                completion(timeline)
                return
            }
        } catch {
            print("Error reading widget data: \(error)")
        }
        
        let entry = SimpleEntry(date: Date(), trainingsLast7Days: 0, targetTrainingsPerWeek: 0, currentWeight: 0, targetWeight: 0, startingWeight: 0)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let trainingsLast7Days: Int
    let targetTrainingsPerWeek: Int
    let currentWeight: Double
    let targetWeight: Double
    let startingWeight: Double
    
    var trainingProgress: Double {
        guard targetTrainingsPerWeek > 0 else { return 0 }
        return Double(trainingsLast7Days) / Double(targetTrainingsPerWeek)
    }
    
    var weightProgress: (progress: Double, isOverStarting: Bool)? {
        guard currentWeight > 0, targetWeight > 0, startingWeight > 0 else { return nil }
        
        if startingWeight > targetWeight {
            // Losing weight
            if currentWeight > startingWeight {
                // Over starting weight
                return (1.0, true)
            } else if currentWeight < targetWeight {
                // Below target weight
                return (0.0, false)
            } else {
                // Between starting and target
                let totalRange = startingWeight - targetWeight
                let currentRange = currentWeight - targetWeight
                return (currentRange / totalRange, false)
            }
        } else {
            // Gaining weight
            if currentWeight < startingWeight {
                // Below starting weight
                return (1.0, true)
            } else if currentWeight > targetWeight {
                // Above target weight
                return (0.0, false)
            } else {
                // Between starting and target
                let totalRange = targetWeight - startingWeight
                let currentRange = currentWeight - startingWeight
                return (currentRange / totalRange, false)
            }
        }
    }
}

struct ClimbingTrackerWidgetEntryView : View {
    var entry: SimpleEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Training Progress")
                .font(.system(size: 12, weight: .semibold))
            
            HStack {
                Text("This Week")
                    .font(.system(size: 10))
                Spacer()
                Text("\(entry.trainingsLast7Days)/\(entry.targetTrainingsPerWeek)")
                    .font(.system(size: 10))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .frame(width: geometry.size.width, height: 6)
                        .opacity(0.3)
                        .foregroundColor(.gray)
                    
                    let progress = entry.targetTrainingsPerWeek > 0 ? Double(entry.trainingsLast7Days) / Double(entry.targetTrainingsPerWeek) : 0
                    Rectangle()
                        .frame(width: min(CGFloat(progress) * geometry.size.width, geometry.size.width), height: 6)
                        .foregroundColor(progress >= 1.0 ? .blue : .green)
                }
                .cornerRadius(3)
            }
            .frame(height: 6)
            
            if entry.currentWeight > 0 {
                HStack {
                    Text("Weight")
                        .font(.system(size: 10))
                    Spacer()
                    Text("\(String(format: "%.1f", entry.currentWeight)) kg")
                        .font(.system(size: 10))
                }
                
                if let weightProgress = entry.weightProgress {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .frame(width: geometry.size.width, height: 6)
                                .opacity(0.3)
                                .foregroundColor(.gray)
                            
                            if weightProgress.isOverStarting {
                                // Show red bar for the overage
                                Rectangle()
                                    .frame(width: geometry.size.width, height: 6)
                                    .foregroundColor(.red)
                            } else {
                                // Show progress bar
                                Rectangle()
                                    .frame(width: min(CGFloat(weightProgress.progress) * geometry.size.width, geometry.size.width), height: 6)
                                    .foregroundColor(.green)
                            }
                        }
                        .cornerRadius(3)
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(8)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
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
    }
}

#Preview(as: .systemSmall) {
    ClimbingTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, trainingsLast7Days: 3, targetTrainingsPerWeek: 4, currentWeight: 75.5, targetWeight: 72.0, startingWeight: 70.0)
}
