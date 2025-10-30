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
        SimpleEntry(date: Date(), trainingsLast7Days: 0, targetTrainingsPerWeek: 0, currentWeight: 0, targetWeight: 0, startingWeight: 0, exerciseGoals: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), trainingsLast7Days: 0, targetTrainingsPerWeek: 0, currentWeight: 0, targetWeight: 0, startingWeight: 0, exerciseGoals: [])
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.tornado-studios.climbingtracker99") else {
            let entry = SimpleEntry(date: Date(), trainingsLast7Days: 0, targetTrainingsPerWeek: 0, currentWeight: 0, targetWeight: 0, startingWeight: 0, exerciseGoals: [])
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
                let currentWeight = json["currentWeight"] as? Double ?? 0
                let targetWeight = json["targetWeight"] as? Double ?? 0
                let startingWeight = json["startingWeight"] as? Double ?? 0
                
                // Parse exercise goals
                var exerciseGoals: [ExerciseGoalData] = []
                if let goalsData = json["exerciseGoals"] as? [[String: Any]] {
                    for goalData in goalsData {
                        if let type = goalData["type"] as? String,
                           let progress = goalData["progress"] as? Double,
                           let details = goalData["details"] as? String {
                            exerciseGoals.append(ExerciseGoalData(type: type, progress: progress, details: details))
                        }
                    }
                }
                
                let entry = SimpleEntry(
                    date: Date(),
                    trainingsLast7Days: trainingsLast7Days,
                    targetTrainingsPerWeek: targetTrainingsPerWeek,
                    currentWeight: currentWeight,
                    targetWeight: targetWeight,
                    startingWeight: startingWeight,
                    exerciseGoals: exerciseGoals
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
        
        let entry = SimpleEntry(date: Date(), trainingsLast7Days: 0, targetTrainingsPerWeek: 0, currentWeight: 0, targetWeight: 0, startingWeight: 0, exerciseGoals: [])
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300))) // Update every 5 minutes
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
    let exerciseGoals: [ExerciseGoalData]
    
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
                return (0.0, true)
            } else if currentWeight < targetWeight {
                // Below target weight
                return (1.0, false)
            } else {
                // Between starting and target
                let totalRange = startingWeight - targetWeight
                let currentRange = startingWeight - currentWeight
                return (currentRange / totalRange, false)
            }
        } else {
            // Gaining weight
            if currentWeight < startingWeight {
                // Below starting weight
                return (0.0, true)
            } else if currentWeight > targetWeight {
                // Above target weight
                return (1.0, false)
            } else {
                // Between starting and target
                let totalRange = targetWeight - startingWeight
                let currentRange = currentWeight - startingWeight
                return (currentRange / totalRange, false)
            }
        }
    }
}

struct ExerciseGoalData: Codable {
    let type: String
    let progress: Double
    let details: String
}

struct ClimbingTrackerWidgetEntryView : View {
    var entry: SimpleEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(alignment: .center, spacing: 4) {
                Image("climbing.icon")
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.black)
                    .frame(height: 20)
                Text("Climbing Tracker")
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
            }
            .padding(.bottom, 6)
            
            // Training Progress Section
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 2) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                    Text("Training")
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    Text("\(entry.trainingsLast7Days)/\(entry.targetTrainingsPerWeek)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 2)
                            .frame(width: geometry.size.width, height: 6)
                            .foregroundColor(Color(.systemGray5))
                        
                        // Progress bar
                        RoundedRectangle(cornerRadius: 2)
                            .frame(width: min(CGFloat(entry.trainingProgress) * geometry.size.width, geometry.size.width), height: 6)
                            .foregroundColor(entry.trainingProgress >= 1.0 ? .green : .blue)
                            .shadow(color: .blue.opacity(0.3), radius: 1, x: 0, y: 1)
                    }
                }
                .frame(height: 6)
            }
            
            // Weight Progress Section
            if entry.currentWeight > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 2) {
                        Image(systemName: "scalemass")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        Text("Weight")
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text("\(String(format: "%.1f", entry.currentWeight)) kg")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                    }
                    
                    if let weightProgress = entry.weightProgress {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 2)
                                    .frame(width: geometry.size.width, height: 6)
                                    .foregroundColor(Color(.systemGray5))
                                
                                if weightProgress.isOverStarting {
                                    // Show red bar for the overage
                                    RoundedRectangle(cornerRadius: 2)
                                        .frame(width: geometry.size.width, height: 6)
                                        .foregroundColor(.red)
                                        .shadow(color: .red.opacity(0.3), radius: 1, x: 0, y: 1)
                                } else {
                                    // Show progress bar
                                    RoundedRectangle(cornerRadius: 2)
                                        .frame(width: min(CGFloat(weightProgress.progress) * geometry.size.width, geometry.size.width), height: 6)
                                        .foregroundColor(.orange)
                                        .shadow(color: .orange.opacity(0.3), radius: 1, x: 0, y: 1)
                                }
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
            
            // Exercise Goals Section
            if !entry.exerciseGoals.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 2) {
                        Image(systemName: "figure.climbing")
                            .font(.system(size: 11))
                            .foregroundColor(.purple)
                        Text("Exercise Goals")
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                    }
                    
                    ForEach(entry.exerciseGoals.prefix(2), id: \.type) { goal in
                        HStack(spacing: 2) {
                            Text(goal.type)
                                .font(.system(size: 10))
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(goal.progress * 100))%")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.purple)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 2)
                                    .frame(width: geometry.size.width, height: 4)
                                    .foregroundColor(Color(.systemGray5))
                                
                                // Progress bar
                                RoundedRectangle(cornerRadius: 2)
                                    .frame(width: min(CGFloat(goal.progress) * geometry.size.width, geometry.size.width), height: 4)
                                    .foregroundColor(.purple)
                                    .shadow(color: .purple.opacity(0.3), radius: 1, x: 0, y: 1)
                            }
                        }
                        .frame(height: 4)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
        )
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
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    ClimbingTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, trainingsLast7Days: 3, targetTrainingsPerWeek: 4, currentWeight: 75.5, targetWeight: 72.0, startingWeight: 70.0, exerciseGoals: [])
}
