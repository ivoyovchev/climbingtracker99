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
            modelContainer = try ModelContainer(for: WeightEntry.self, UserSettings.self, Item.self)
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
