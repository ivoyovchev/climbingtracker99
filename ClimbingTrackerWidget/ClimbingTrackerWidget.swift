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
        SimpleEntry(date: Date(), trainingsLast7Days: 0, targetTrainingsPerWeek: 0, currentWeight: 0, targetWeight: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), trainingsLast7Days: 0, targetTrainingsPerWeek: 0, currentWeight: 0, targetWeight: 0)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.APP_GROUP_IDENTIFIER) else {
            let entry = SimpleEntry(date: Date(), trainingsLast7Days: 0, targetTrainingsPerWeek: 0, currentWeight: 0, targetWeight: 0)
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
                
                let entry = SimpleEntry(
                    date: Date(),
                    trainingsLast7Days: trainingsLast7Days,
                    targetTrainingsPerWeek: targetTrainingsPerWeek,
                    currentWeight: currentWeight,
                    targetWeight: targetWeight
                )
                let timeline = Timeline(entries: [entry], policy: .atEnd)
                completion(timeline)
                return
            }
        } catch {
            print("Error reading widget data: \(error)")
        }
        
        let entry = SimpleEntry(date: Date(), trainingsLast7Days: 0, targetTrainingsPerWeek: 0, currentWeight: 0, targetWeight: 0)
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
            Text("Training Progress")
                .font(.headline)
            
            HStack {
                Text("This Week")
                Spacer()
                Text("\(entry.trainingsLast7Days)/\(entry.targetTrainingsPerWeek)")
            }
            .font(.subheadline)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .frame(width: geometry.size.width, height: 10)
                        .opacity(0.3)
                        .foregroundColor(.gray)
                    
                    let progress = entry.targetTrainingsPerWeek > 0 ? Double(entry.trainingsLast7Days) / Double(entry.targetTrainingsPerWeek) : 0
                    Rectangle()
                        .frame(width: min(CGFloat(progress) * geometry.size.width, geometry.size.width), height: 10)
                        .foregroundColor(progress >= 1.0 ? .blue : .green)
                }
                .cornerRadius(5)
            }
            .frame(height: 10)
            
            if entry.currentWeight > 0 {
                HStack {
                    Text("Weight")
                    Spacer()
                    Text("\(String(format: "%.1f", entry.currentWeight)) kg")
                }
                .font(.subheadline)
            }
        }
        .padding()
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
    SimpleEntry(date: .now, trainingsLast7Days: 3, targetTrainingsPerWeek: 4, currentWeight: 75.5, targetWeight: 72.0)
}
