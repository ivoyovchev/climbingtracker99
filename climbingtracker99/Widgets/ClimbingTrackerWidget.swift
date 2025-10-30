import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), trainingsLast7Days: 3, targetTrainingsPerWeek: 4, currentWeight: 79.2, targetWeight: 78.5)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        // Get data from shared UserDefaults
        let userDefaults = UserDefaults(suiteName: "group.com.ivoyovchev.climbingtracker99")
        
        // Get the start of the current week (Monday)
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let daysToSubtract = (weekday + 5) % 7 // Convert to Monday-based week (1 = Sunday, 2 = Monday, etc.)
        let startOfWeek = calendar.date(byAdding: .day, value: -daysToSubtract, to: now)!
        
        // Get the end of the current week (Sunday)
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
        
        // Get trainings from the current week
        let trainings = Training.fetchTrainings(from: startOfWeek, to: endOfWeek)
        let trainingsLast7Days = trainings.count
        
        let targetTrainingsPerWeek = userDefaults?.integer(forKey: "targetTrainingsPerWeek") ?? 0
        let currentWeight = userDefaults?.double(forKey: "currentWeight") ?? 0
        let targetWeight = userDefaults?.double(forKey: "targetWeight") ?? 0
        
        let entry = SimpleEntry(
            date: Date(),
            trainingsLast7Days: trainingsLast7Days,
            targetTrainingsPerWeek: targetTrainingsPerWeek,
            currentWeight: currentWeight,
            targetWeight: targetWeight
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Get data from shared UserDefaults
        let userDefaults = UserDefaults(suiteName: "group.com.ivoyovchev.climbingtracker99")
        
        // Get the start of the current week (Monday)
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let daysToSubtract = (weekday + 5) % 7 // Convert to Monday-based week (1 = Sunday, 2 = Monday, etc.)
        let startOfWeek = calendar.date(byAdding: .day, value: -daysToSubtract, to: now)!
        
        // Get the end of the current week (Sunday)
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
        
        // Get trainings from the current week
        let trainings = Training.fetchTrainings(from: startOfWeek, to: endOfWeek)
        let trainingsLast7Days = trainings.count
        
        let targetTrainingsPerWeek = userDefaults?.integer(forKey: "targetTrainingsPerWeek") ?? 0
        let currentWeight = userDefaults?.double(forKey: "currentWeight") ?? 0
        let targetWeight = userDefaults?.double(forKey: "targetWeight") ?? 0
        
        let entry = SimpleEntry(
            date: Date(),
            trainingsLast7Days: trainingsLast7Days,
            targetTrainingsPerWeek: targetTrainingsPerWeek,
            currentWeight: currentWeight,
            targetWeight: targetWeight
        )
        
        // Update every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
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
        VStack(alignment: .leading, spacing: 12) {
            // Training Progress
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Training")
                        .font(.headline)
                    Spacer()
                    Text("\(entry.trainingsLast7Days)/\(entry.targetTrainingsPerWeek)")
                        .font(.subheadline)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(width: geometry.size.width, height: 6)
                            .opacity(0.3)
                            .foregroundColor(.gray)
                        
                        Rectangle()
                            .frame(width: min(CGFloat(entry.trainingProgress) * geometry.size.width, geometry.size.width), height: 6)
                            .foregroundColor(entry.trainingProgress >= 1.0 ? .blue : .green)
                    }
                    .cornerRadius(3)
                }
                .frame(height: 6)
            }
            
            // Weight Progress
            if let weightProgress = entry.weightProgress {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Weight")
                            .font(.headline)
                        Spacer()
                        Text("\(String(format: "%.1f", entry.currentWeight)) kg")
                            .font(.subheadline)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .frame(width: geometry.size.width, height: 6)
                                .opacity(0.3)
                                .foregroundColor(.gray)
                            
                            Rectangle()
                                .frame(width: min(CGFloat(weightProgress) * geometry.size.width, geometry.size.width), height: 6)
                                .foregroundColor(weightProgress >= 1.0 ? .blue : .green)
                        }
                        .cornerRadius(3)
                    }
                    .frame(height: 6)
                }
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
        .description("View your training and weight progress.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    ClimbingTrackerWidget()
} timeline: {
    SimpleEntry(date: .now, trainingsLast7Days: 3, targetTrainingsPerWeek: 4, currentWeight: 79.2, targetWeight: 78.5)
} 