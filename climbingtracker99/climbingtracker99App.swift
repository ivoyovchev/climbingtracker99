//
//  climbingtracker99App.swift
//  climbingtracker99
//
//  Created by Ivo Yovchev on 17/04/2025.
//

import SwiftUI
import SwiftData

let APP_VERSION = "1.0.0"

@main
struct climbingtracker99App: App {
    let container: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                WeightEntry.self,
                UserSettings.self,
                Item.self,
                Exercise.self,
                Training.self,
                Goals.self,
                Media.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .identifier("group.com.tornado-studios.climbingtracker99")
            )
            
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Ensure default exercises exist
            let descriptor = FetchDescriptor<Exercise>()
            let exercises = try container.mainContext.fetch(descriptor)
            
            if exercises.isEmpty {
                // Create default exercises
                let defaultExercises = [
                    Exercise(type: .hangboarding),
                    Exercise(type: .repeaters),
                    Exercise(type: .limitBouldering)
                ]
                
                for exercise in defaultExercises {
                    container.mainContext.insert(exercise)
                }
            }
        } catch {
            fatalError("Could not configure SwiftData container: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
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
            let descriptor = FetchDescriptor<UserSettings>()
            userSettings = (try? modelContext.fetch(descriptor)) ?? []
        }
    }
}
