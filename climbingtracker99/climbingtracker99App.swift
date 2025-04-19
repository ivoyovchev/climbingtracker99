//
//  climbingtracker99App.swift
//  climbingtracker99
//
//  Created by Ivo Yovchev on 17/04/2025.
//

import SwiftUI
import SwiftData

@main
struct climbingtracker99App: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            modelContainer = try ModelContainer(
                for: WeightEntry.self, 
                UserSettings.self, 
                Item.self,
                Training.self,
                Goals.self,
                Media.self,
                Exercise.self,
                RecordedExercise.self,
                Meal.self
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
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
            Exercise(type: .maxHangs, focus: .strength),
            Exercise(type: .flexibility, focus: .mobility)
        ]
        
        for exercise in defaultExercises {
            modelContext.insert(exercise)
        }
    }
    
    private func createDefaultGoals() {
        let defaultGoals = Goals(targetTrainingsPerWeek: 3, targetWeight: 0.0)
        modelContext.insert(defaultGoals)
    }
}
