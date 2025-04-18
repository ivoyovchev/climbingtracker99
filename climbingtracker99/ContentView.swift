//
//  ContentView.swift
//  climbingtracker99
//
//  Created by Ivo Yovchev on 17/04/2025.
//

import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            TrainingView()
                .tabItem {
                    Label("Training", systemImage: "figure.climbing")
                }
            
            MomentsView()
                .tabItem {
                    Label("Moments", systemImage: "photo.on.rectangle")
                }
            
            HealthView()
                .tabItem {
                    Label("Health", systemImage: "heart")
                }
            
            NutritionView()
                .tabItem {
                    Label("Nutrition", systemImage: "fork.knife")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trainings: [Training]
    @Query private var weightEntries: [WeightEntry]
    @Query private var goals: [Goals]
    
    @State private var showingGoalsSheet = false
    
    private var currentWeight: Double? {
        weightEntries.sorted(by: { $0.date > $1.date }).first?.weight
    }
    
    private var trainingsLast7Days: Int {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return trainings.filter { $0.date >= sevenDaysAgo }.count
    }
    
    private var trainingsLast30Days: Int {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return trainings.filter { $0.date >= thirtyDaysAgo }.count
    }
    
    private var trainingsLast6Months: Int {
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        return trainings.filter { $0.date >= sixMonthsAgo }.count
    }
    
    private var userGoals: Goals {
        if let existingGoals = goals.first {
            return existingGoals
        }
        let newGoals = Goals()
        modelContext.insert(newGoals)
        return newGoals
    }
    
    private var trainingProgress: Double {
        guard userGoals.targetTrainingsPerWeek > 0 else { return 0 }
        return Double(trainingsLast7Days) / Double(userGoals.targetTrainingsPerWeek)
    }
    
    private var weightProgress: Double? {
        guard let current = currentWeight, userGoals.targetWeight > 0 else { return nil }
        // If current weight is higher than target, we want to lose weight
        if current > userGoals.targetWeight {
            // Progress is 1.0 when we reach target, 0.0 when we're at current
            return 1.0 - ((current - userGoals.targetWeight) / current)
        } else {
            // For weight gain, progress is current/target
            return current / userGoals.targetWeight
        }
    }
    
    private func updateWidgetData() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedConstants.APP_GROUP_IDENTIFIER) else {
            print("Failed to get container URL")
            return
        }
        
        // Ensure the container directory exists
        do {
            try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
            print("Container directory exists at: \(containerURL.path)")
        } catch {
            print("Failed to create container directory: \(error.localizedDescription)")
            return
        }
        
        let fileURL = containerURL.appendingPathComponent("widgetData.json")
        print("Writing widget data to: \(fileURL.path)")
        
        // Calculate trainings in last 7 days
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let recentTrainings = trainings.filter { $0.date >= sevenDaysAgo }.count
        
        let data = [
            "trainingsLast7Days": recentTrainings,
            "targetTrainingsPerWeek": userGoals.targetTrainingsPerWeek,
            "currentWeight": currentWeight ?? 0,
            "targetWeight": userGoals.targetWeight
        ] as [String : Any]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            try jsonData.write(to: fileURL, options: .atomic)
            print("Successfully wrote widget data: \(data)")
            
            // Force a widget update
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Failed to write widget data: \(error.localizedDescription)")
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TabHeaderView(title: "Dashboard") {
                    Button(action: { showingGoalsSheet = true }) {
                        Image(systemName: "target")
                            .font(.system(size: 24))
                    }
                }
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Training Stats
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Training")
                                    .font(.title2)
                                    .bold()
                                Spacer()
                            }
                            
                            // Training Progress Bar
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text("This Week")
                                    Spacer()
                                    Text("\(trainingsLast7Days)/\(userGoals.targetTrainingsPerWeek)")
                                }
                                .font(.subheadline)
                                
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .frame(width: geometry.size.width, height: 10)
                                            .opacity(0.3)
                                            .foregroundColor(.gray)
                                        
                                        Rectangle()
                                            .frame(width: min(CGFloat(trainingProgress) * geometry.size.width, geometry.size.width), height: 10)
                                            .foregroundColor(trainingProgress >= 1.0 ? .blue : .green)
                                        
                                        if trainingProgress >= 1.0 {
                                            Image(systemName: "trophy.fill")
                                                .foregroundColor(.yellow)
                                                .offset(x: min(CGFloat(trainingProgress) * geometry.size.width - 20, geometry.size.width - 20))
                                        }
                                    }
                                    .cornerRadius(5)
                                }
                                .frame(height: 10)
                            }
                            
                            // Training Stats
                            HStack {
                                StatBox(title: "Last 30 Days", value: "\(trainingsLast30Days)")
                                StatBox(title: "Last 6 Months", value: "\(trainingsLast6Months)")
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        
                        // Weight Stats
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Weight")
                                    .font(.title2)
                                    .bold()
                                Spacer()
                                Button(action: { showingGoalsSheet = true }) {
                                    Image(systemName: "target")
                                }
                            }
                            
                            if let currentWeight = currentWeight {
                                // Weight Progress
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text("Current: \(String(format: "%.1f", currentWeight)) kg")
                                        Spacer()
                                        if userGoals.targetWeight > 0 {
                                            Text("Target: \(String(format: "%.1f", userGoals.targetWeight)) kg")
                                        }
                                    }
                                    .font(.subheadline)
                                    
                                    if userGoals.targetWeight > 0, let progress = weightProgress {
                                        GeometryReader { geometry in
                                            ZStack(alignment: .leading) {
                                                Rectangle()
                                                    .frame(width: geometry.size.width, height: 10)
                                                    .opacity(0.3)
                                                    .foregroundColor(.gray)
                                                
                                                Rectangle()
                                                    .frame(width: min(CGFloat(progress) * geometry.size.width, geometry.size.width), height: 10)
                                                    .foregroundColor(progress >= 1.0 ? .blue : .green)
                                                
                                                if progress >= 1.0 {
                                                    Image(systemName: "trophy.fill")
                                                        .foregroundColor(.yellow)
                                                        .offset(x: min(CGFloat(progress) * geometry.size.width - 20, geometry.size.width - 20))
                                                }
                                            }
                                            .cornerRadius(5)
                                        }
                                        .frame(height: 10)
                                    }
                                }
                            } else {
                                Text("No weight data available")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingGoalsSheet) {
                GoalsEditView(goals: userGoals)
            }
            .onChange(of: trainings) { oldValue, newValue in
                print("Trainings changed - Count: \(newValue.count)")
                updateWidgetData()
            }
            .onChange(of: weightEntries) { oldValue, newValue in
                print("Weight entries changed - Count: \(newValue.count)")
                updateWidgetData()
            }
            .onChange(of: goals) { oldValue, newValue in
                print("Goals changed")
                updateWidgetData()
            }
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            Text(value)
                .font(.title3)
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 1)
    }
}

struct GoalsEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var targetTrainings: Int
    @State private var targetWeight: Double
    
    let goals: Goals
    
    init(goals: Goals) {
        self.goals = goals
        _targetTrainings = State(initialValue: goals.targetTrainingsPerWeek)
        _targetWeight = State(initialValue: goals.targetWeight)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Training Goals")) {
                    Stepper("Target trainings per week: \(targetTrainings)", value: $targetTrainings, in: 1...7)
                }
                
                Section(header: Text("Weight Goals")) {
                    HStack {
                        Text("Target Weight")
                        Spacer()
                        TextField("Weight", value: $targetWeight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("kg")
                    }
                }
            }
            .navigationTitle("Edit Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        goals.targetTrainingsPerWeek = targetTrainings
                        goals.targetWeight = targetWeight
                        goals.lastUpdated = Date()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct HealthView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    @State private var showingAddWeight = false
    @State private var entryToEdit: WeightEntry?
    
    private var sortedEntries: [WeightEntry] {
        weightEntries
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TabHeaderView(title: "Health") {
                    Button(action: { showingAddWeight = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                    }
                }
                
                Button(action: { showingAddWeight = true }) {
                    Label("Add Weight", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                WeightGraphView(entries: sortedEntries)
                    .frame(height: 200)
                    .padding()
                
                List {
                    ForEach(sortedEntries) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(String(format: "%.1f", entry.weight)) kg")
                                    .font(.headline)
                                Text(entry.date, style: .date)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                if !entry.note.isEmpty {
                                    Text(entry.note)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            Spacer()
                            Button(action: { entryToEdit = entry }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .onDelete(perform: deleteEntries)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddWeight) {
                WeightEntryView()
            }
            .sheet(item: $entryToEdit) { entry in
                WeightEntryView(entry: entry)
            }
        }
    }
    
    private func deleteEntries(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(sortedEntries[index])
            }
        }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userSettings: [UserSettings]
    @Query private var weightEntries: [WeightEntry]
    @State private var showingResetAlert = false
    @State private var showingWelcome = false
    
    private var settings: UserSettings? {
        userSettings.first
    }
    
    var body: some View {
        NavigationView {
            List {
                if let userName = settings?.userName {
                    Section(header: Text("User Info")) {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(userName)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section(header: Text("Training")) {
                    NavigationLink(destination: ExercisesView()) {
                        HStack {
                            Image(systemName: "figure.climbing")
                            Text("Exercises")
                        }
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(SharedConstants.APP_VERSION)
                            .foregroundColor(.gray)
                    }
                }
                
                Section {
                    Button(role: .destructive, action: {
                        showingResetAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Reset All Data")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Reset All Data", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("This will delete all your data and return to the welcome screen. This action cannot be undone.")
            }
            .fullScreenCover(isPresented: $showingWelcome) {
                WelcomeView(showingWelcome: $showingWelcome)
            }
        }
    }
    
    private func resetAllData() {
        // Delete all weight entries
        for entry in weightEntries {
            modelContext.delete(entry)
        }
        
        // Reset user settings
        if let settings = settings {
            settings.userName = ""
            settings.hasCompletedWelcome = false
            showingWelcome = true
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WeightEntry.self, UserSettings.self, Item.self], inMemory: true)
}

