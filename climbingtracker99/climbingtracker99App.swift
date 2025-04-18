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
    let container: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                WeightEntry.self,
                UserSettings.self,
                Item.self,
                Exercise.self,
                Training.self,
                Goals.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
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
