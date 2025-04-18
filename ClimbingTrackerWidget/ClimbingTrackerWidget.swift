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
        SimpleEntry(date: Date(), trainingsLast7Days: 3, targetTrainingsPerWeek: 4, currentWeight: 79.2, targetWeight: 78.5)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = readWidgetData()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let entry = readWidgetData()
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
    
    private func readWidgetData() -> SimpleEntry {
        var trainingsLast7Days = 0
        var targetTrainingsPerWeek = 0
        var currentWeight = 0.0
        var targetWeight = 0.0
        
        do {
            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.tornado-studios.climbingtracker99") else {
                print("Widget: Failed to get container URL")
                return SimpleEntry(date: Date(), trainingsLast7Days: 0, targetTrainingsPerWeek: 0, currentWeight: 0, targetWeight: 0)
            }
            
            print("Widget: Container URL: \(containerURL.path)")
            
            let fileURL = containerURL.appendingPathComponent("widgetData.json")
            print("Widget: Looking for data file at: \(fileURL.path)")
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                print("Widget: Data file exists")
                let data = try Data(contentsOf: fileURL)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    trainingsLast7Days = json["trainingsLast7Days"] as? Int ?? 0
                    targetTrainingsPerWeek = json["targetTrainingsPerWeek"] as? Int ?? 0
                    currentWeight = json["currentWeight"] as? Double ?? 0
                    targetWeight = json["targetWeight"] as? Double ?? 0
                    
                    print("Widget: Successfully read data - Trainings: \(trainingsLast7Days)/\(targetTrainingsPerWeek), Weight: \(currentWeight)/\(targetWeight)")
                } else {
                    print("Widget: Failed to parse JSON data")
                }
            } else {
                print("Widget: No data file found at \(fileURL.path)")
                // List contents of container directory for debugging
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: containerURL.path) {
                    print("Widget: Container directory contents: \(contents)")
                }
            }
        } catch {
            print("Widget: Error reading data: \(error.localizedDescription)")
        }
        
        return SimpleEntry(
            date: Date(),
            trainingsLast7Days: trainingsLast7Days,
            targetTrainingsPerWeek: targetTrainingsPerWeek,
            currentWeight: currentWeight,
            targetWeight: targetWeight
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let trainingsLast7Days: Int
    let targetTrainingsPerWeek: Int
    let currentWeight: Double
    let targetWeight: Double
    
    var trainingProgress: Double {
        guard targetTrainingsPerWeek > 0 else { return 0 }
        return Double(trainingsLast7Days) / Double(targetTrainingsPerWeek)
    }
    
    var weightProgress: Double? {
        guard currentWeight > 0, targetWeight > 0 else { return nil }
        if currentWeight > targetWeight {
            return 1.0 - ((currentWeight - targetWeight) / currentWeight)
        } else {
            return currentWeight / targetWeight
        }
    }
}

struct ClimbingTrackerWidgetEntryView : View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Climbing Goals")
                .font(.system(size: 14, weight: .bold))
                .padding(.bottom, 2)
            
            // Training Progress
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Train")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(entry.trainingsLast7Days)/\(entry.targetTrainingsPerWeek)")
                        .font(.system(size: 12))
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(width: geometry.size.width, height: 4)
                            .opacity(0.3)
                            .foregroundColor(.gray)
                        
                        Rectangle()
                            .frame(width: min(CGFloat(entry.trainingProgress) * geometry.size.width, geometry.size.width), height: 4)
                            .foregroundColor(entry.trainingProgress >= 1.0 ? .blue : .green)
                    }
                    .cornerRadius(2)
                }
                .frame(height: 4)
            }
            
            // Weight Progress
            if let weightProgress = entry.weightProgress {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Weight")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("\(String(format: "%.1f", entry.currentWeight)) kg")
                            .font(.system(size: 12))
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .frame(width: geometry.size.width, height: 4)
                                .opacity(0.3)
                                .foregroundColor(.gray)
                            
                            Rectangle()
                                .frame(width: min(CGFloat(weightProgress) * geometry.size.width, geometry.size.width), height: 4)
                                .foregroundColor(weightProgress >= 1.0 ? .blue : .green)
                        }
                        .cornerRadius(2)
                    }
                    .frame(height: 4)
                }
            }
        }
        .padding(8)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct ClimbingTrackerWidget: Widget {
    let kind: String = "ClimbingTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ClimbingTrackerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Climbing Tracker")
        .description("View your training and weight progress.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    ClimbingTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, trainingsLast7Days: 3, targetTrainingsPerWeek: 4, currentWeight: 79.2, targetWeight: 78.5)
}
