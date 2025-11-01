//
//  climbingtracker99App.swift
//  climbingtracker99
//
//  Created by Ivo Yovchev on 17/04/2025.
//

import SwiftUI
import SwiftData
import WidgetKit
import UserNotifications

@main
struct climbingtracker99App: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                WeightEntry.self,
                UserSettings.self,
                Item.self,
                Training.self,
                Goals.self,
                ExerciseGoal.self,
                Media.self,
                Exercise.self,
                RecordedExercise.self,
                Meal.self,
                MoonLogEntry.self,
                RunningSession.self,
                PlannedTraining.self,
                PlannedRun.self,
                PlannedBenchmark.self
            ])
            
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                // If we can't load the existing store, create a new one
                print("Error loading store: \(error)")
                let storeURL = URL.documentsDirectory.appending(path: "default.store")
                try? FileManager.default.removeItem(at: storeURL)
                modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            }
            
            // Update widget data on app launch
            updateWidgetData()
            
            // Set notification delegate to show notifications in foreground
            UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    private func updateWidgetData() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.tornado-studios.climbingtracker99") else {
            print("Failed to get container URL")
            return
        }
        
        // Ensure the container directory exists
        do {
            try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        } catch {
            print("Failed to create container directory: \(error.localizedDescription)")
            return
        }
        
        let fileURL = containerURL.appendingPathComponent("widgetData.json")
        
        // Get the model context
        let context = ModelContext(modelContainer)
        
        // Calculate current week boundaries (Monday to Sunday)
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let daysToSubtract = (weekday + 5) % 7 // Convert to Monday-based week (1 = Sunday, 2 = Monday, etc.)
        let startOfWeek = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -daysToSubtract, to: now)!)
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)! // End of Sunday (start of next Monday)
        
        // Fetch trainings from current week (Monday to Sunday)
        // Note: We compare dates directly - training.date includes time components,
        // but startOfWeek is normalized to start of day and endOfWeek is start of next Monday
        let descriptor = FetchDescriptor<Training>(
            predicate: #Predicate<Training> { training in
                training.date >= startOfWeek && training.date < endOfWeek
            }
        )
        
        do {
            let recentTrainings = try context.fetch(descriptor)
            
            // Fetch goals
            let goalsDescriptor = FetchDescriptor<Goals>()
            let goals = try context.fetch(goalsDescriptor).first ?? Goals()
            
            // Fetch current weight
            let weightDescriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            let currentWeight = try context.fetch(weightDescriptor).first?.weight ?? 0.0
            
            // Fetch running sessions for this week
            let calendar = Calendar.current
            let now = Date()
            let weekday = calendar.component(.weekday, from: now)
            let daysToSubtract = (weekday + 5) % 7
            let startOfWeek = calendar.date(byAdding: .day, value: -daysToSubtract, to: now)!
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
            
            let runningDescriptor = FetchDescriptor<RunningSession>(
                predicate: #Predicate<RunningSession> { run in
                    run.startTime >= startOfWeek && run.startTime <= endOfWeek
                }
            )
            let runningSessions = try context.fetch(runningDescriptor)
            let runsThisWeek = runningSessions.count
            let distanceThisWeek = runningSessions.reduce(0.0) { $0 + $1.distanceInKm }
            
            // Process exercise goals
            var exerciseGoalsData: [[String: Any]] = []
            for goal in goals.exerciseGoals {
                var progress: Double = 0
                var details: String = ""
                
                if goal.exerciseType == .hangboarding {
                    let currentDuration = goal.getCurrentValue("duration") ?? 0
                    let targetDuration = goal.getTargetValue("duration") ?? 1
                    progress = currentDuration / targetDuration
                    
                    var detailsArray: [String] = []
                    if let gripTypeString = goal.getParameterValue("gripType") as String?,
                       let gripType = GripType(rawValue: gripTypeString) {
                        detailsArray.append(gripType.rawValue)
                    }
                    if let edgeSize = goal.getParameterValue("edgeSize") as Int? {
                        detailsArray.append("\(edgeSize)mm")
                    }
                    if let duration = goal.getTargetValue("duration") {
                        detailsArray.append("\(Int(duration))s")
                    }
                    if let weight = goal.getTargetValue("addedWeight"), weight > 0 {
                        detailsArray.append("+\(weight)kg")
                    }
                    details = detailsArray.joined(separator: " • ")
                } else if goal.exerciseType == .repeaters {
                    let currentReps = goal.getCurrentValue("repetitions") ?? 0
                    let targetReps = goal.getTargetValue("repetitions") ?? 1
                    progress = currentReps / targetReps
                    
                    var detailsArray: [String] = []
                    if let duration = goal.getTargetValue("duration") {
                        detailsArray.append("\(Int(duration))s")
                    }
                    if let reps = goal.getTargetValue("repetitions") {
                        detailsArray.append("\(Int(reps)) reps")
                    }
                    if let sets = goal.getTargetValue("sets") {
                        detailsArray.append("\(Int(sets)) sets")
                    }
                    if let weight = goal.getTargetValue("addedWeight"), weight > 0 {
                        detailsArray.append("+\(weight)kg")
                    }
                    details = detailsArray.joined(separator: " • ")
                }
                
                exerciseGoalsData.append([
                    "type": goal.exerciseType.rawValue,
                    "progress": progress,
                    "details": details
                ])
            }
            
            let data = [
                "trainingsLast7Days": recentTrainings.count,
                "targetTrainingsPerWeek": goals.targetTrainingsPerWeek,
                "runsThisWeek": runsThisWeek,
                "targetRunsPerWeek": goals.targetRunsPerWeek ?? 3,
                "distanceThisWeek": distanceThisWeek,
                "targetDistancePerWeek": goals.targetDistancePerWeek ?? 20.0,
                "currentWeight": currentWeight,
                "targetWeight": goals.targetWeight,
                "startingWeight": goals.startingWeight ?? 0.0,
                "exerciseGoals": exerciseGoalsData
            ] as [String : Any]
            
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            try jsonData.write(to: fileURL, options: .atomic)
            
            // Force a widget update
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Failed to update widget data: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}

struct AppContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var userSettings: [UserSettings] = []
    @State private var showingWelcome = false
    
    private var settings: UserSettings {
        if let existingSettings = userSettings.first {
            return existingSettings
        }
        let newSettings = UserSettings()
        modelContext.insert(newSettings)
        return newSettings
    }
    
    var body: some View {
        Group {
            if settings.hasCompletedWelcome && !showingWelcome {
                ContentView()
            } else {
                WelcomeView(showingWelcome: $showingWelcome)
            }
        }
        .animation(.default, value: showingWelcome)
        .task {
            // Fetch user settings
            let descriptor = FetchDescriptor<UserSettings>()
            userSettings = (try? modelContext.fetch(descriptor)) ?? []
            
            // Initialize default exercises if none exist
            let exerciseDescriptor = FetchDescriptor<Exercise>()
            let exercises = (try? modelContext.fetch(exerciseDescriptor)) ?? []
            if exercises.isEmpty {
                createDefaultExercises()
            }
            
            // Initialize default goals if none exist
            let goalsDescriptor = FetchDescriptor<Goals>()
            let goals = (try? modelContext.fetch(goalsDescriptor)) ?? []
            if goals.isEmpty {
                createDefaultGoals()
            }
        }
    }
    
    private func createDefaultExercises() {
        // Create default exercises for each type with appropriate focuses
        let defaultExercises = [
            Exercise(type: .warmup, focus: .mobility),
            Exercise(type: .hangboarding, focus: .strength),
            Exercise(type: .repeaters, focus: .endurance),
            Exercise(type: .limitBouldering, focus: .power),
            Exercise(type: .nxn, focus: .endurance),
            Exercise(type: .boulderCampus, focus: .power),
            Exercise(type: .deadlifts, focus: .strength),
            Exercise(type: .shoulderLifts, focus: .strength),
            Exercise(type: .pullups, focus: .strength),
            Exercise(type: .boardClimbing, focus: .technique),
            Exercise(type: .edgePickups, focus: .strength),
            Exercise(type: .flexibility, focus: .mobility),
            Exercise(type: .running, focus: .endurance),
            Exercise(type: .circuit, focus: .endurance),
            Exercise(type: .core, focus: .mobility),
            Exercise(type: .campusing, focus: .power),
            Exercise(type: .benchmark, focus: .strength)
        ]
        
        for exercise in defaultExercises {
            modelContext.insert(exercise)
        }
    }
    
    private func createDefaultGoals() {
        let defaultGoals = Goals(
            targetTrainingsPerWeek: 3,
            targetWeight: 0.0,
            exerciseGoals: []
        )
        modelContext.insert(defaultGoals)
    }
}

// Notification delegate to show notifications even when app is in foreground
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    override init() {
        super.init()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground with banner, sound, and badge
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
