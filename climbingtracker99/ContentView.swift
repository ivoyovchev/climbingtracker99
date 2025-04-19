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
    @Query(sort: \Training.date, order: .reverse) private var trainings: [Training]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    @Query private var goals: [Goals]
    
    @State private var showingGoalsSheet = false
    @State private var animateStats = false
    
    private var currentWeight: Double? {
        weightEntries.first?.weight
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
    
    private var totalTrainingTime: Int {
        trainings.reduce(0) { $0 + $1.duration }
    }
    
    private var averageTrainingTime: Double {
        guard !trainings.isEmpty else { return 0 }
        return Double(totalTrainingTime) / Double(trainings.count)
    }
    
    private var exerciseFocusDistribution: [(focus: TrainingFocus, count: Int)] {
        let allExercises = trainings.flatMap { $0.recordedExercises }
        let counts = Dictionary(grouping: allExercises) { exercise in
            exercise.exercise.focus ?? .strength
        }
        .mapValues { $0.count }
        return TrainingFocus.allCases.map { focus in
            (focus: focus, count: counts[focus] ?? 0)
        }
    }
    
    private var exerciseTypeDistribution: [(type: ExerciseType, count: Int)] {
        let allExercises = trainings.flatMap { $0.recordedExercises }
        let counts = Dictionary(grouping: allExercises) { exercise in
            exercise.exercise.type
        }
        .mapValues { $0.count }
        .filter { $0.value > 0 }
        .sorted { $0.value > $1.value }
        
        return counts.map { (type: $0.key, count: $0.value) }
    }
    
    private var trainingLocationDistribution: [(location: TrainingLocation, count: Int)] {
        let counts = Dictionary(grouping: trainings, by: \.location)
            .mapValues { $0.count }
        return TrainingLocation.allCases.map { location in
            (location: location, count: counts[location] ?? 0)
        }
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
        guard let current = currentWeight, 
              let starting = userGoals.startingWeight,
              userGoals.targetWeight > 0 else { return nil }
        
        if current > userGoals.targetWeight {
            return 1.0 - ((current - userGoals.targetWeight) / (starting - userGoals.targetWeight))
        } else {
            return (current - starting) / (userGoals.targetWeight - starting)
        }
    }
    
    private var recentTrainings: [Training] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return trainings.filter { $0.date >= thirtyDaysAgo }
    }
    
    private var exercisesByFocus: [(focus: TrainingFocus, exercises: [(type: ExerciseType, count: Int)])] {
        TrainingFocus.allCases.map { focus in
            let exercises = exerciseTypeDistribution
                .filter { $0.count > 0 }
                .filter { exercise in
                    let exerciseFocus = trainings
                        .flatMap { $0.recordedExercises }
                        .first { $0.exercise.type == exercise.type }?
                        .exercise.focus ?? .strength
                    return exerciseFocus == focus
                }
            return (focus: focus, exercises: exercises)
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
        
        // Calculate weight progress for widget
        var weightProgress: Double = 0
        if let current = currentWeight,
           let starting = userGoals.startingWeight,
           userGoals.targetWeight > 0 {
            if current > userGoals.targetWeight {
                weightProgress = 1.0 - ((current - userGoals.targetWeight) / (starting - userGoals.targetWeight))
            } else {
                weightProgress = (current - starting) / (userGoals.targetWeight - starting)
            }
        }
        
        let data = [
            "trainingsLast7Days": recentTrainings,
            "targetTrainingsPerWeek": userGoals.targetTrainingsPerWeek,
            "currentWeight": currentWeight ?? 0.0,
            "targetWeight": userGoals.targetWeight,
            "startingWeight": userGoals.startingWeight ?? 0.0,
            "weightProgress": weightProgress
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
            ScrollView {
                VStack(spacing: 20) {
                    // Goals Section
                    Section(header: Text("Goals")) {
                        VStack(spacing: 15) {
                            if let userGoals = goals.first {
                                // Training Progress
                                ProgressView(value: trainingProgress) {
                                    HStack {
                                        Text("Training")
                                            .font(.subheadline)
                                        Spacer()
                                        Text("\(trainingsLast7Days)/\(userGoals.targetTrainingsPerWeek)")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                // Weight Progress
                                if let progress = weightProgress {
                                    ProgressView(value: progress) {
                                        HStack {
                                            Text("Weight")
                                                .font(.subheadline)
                                            Spacer()
                                            if let current = currentWeight {
                                                Text(String(format: "%.1f/%.1f kg", current, userGoals.targetWeight))
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(15)
                        .shadow(radius: 5)
                    }
                    
                    // Stats Section
                    Section(header: Text("Stats")) {
                        VStack(spacing: 15) {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                                StatCard(
                                    title: "Total Time",
                                    value: "\(totalTrainingTime) min",
                                    icon: "clock.fill",
                                    color: .orange
                                )
                                
                                StatCard(
                                    title: "Avg. Duration",
                                    value: String(format: "%.0f min", averageTrainingTime),
                                    icon: "timer",
                                    color: .purple
                                )
                                
                                StatCard(
                                    title: "Last 30 Days",
                                    value: "\(trainingsLast30Days)",
                                    icon: "calendar",
                                    color: .blue
                                )
                                
                                StatCard(
                                    title: "Last 6 Months",
                                    value: "\(trainingsLast6Months)",
                                    icon: "chart.bar.fill",
                                    color: .green
                                )
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(15)
                        .shadow(radius: 5)
                    }
                    
                    // Exercise Stats Section
                    Section(header: Text("Exercise Analysis")) {
                        VStack(spacing: 15) {
                            ForEach(exercisesByFocus, id: \.focus) { section in
                                if !section.exercises.isEmpty {
                                    FocusExerciseSection(
                                        focus: section.focus,
                                        exercises: section.exercises
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(15)
                        .shadow(radius: 5)
                    }
                }
                .padding()
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingGoalsSheet = true }) {
                        Image(systemName: "target")
                    }
                }
            }
            .sheet(isPresented: $showingGoalsSheet) {
                GoalsEditView(goals: userGoals)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.3)) {
                    animateStats = true
                }
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

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Text(value)
                .font(.title2)
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct GoalsEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var targetTrainings: Int
    @State private var targetWeight: Double
    @State private var startingWeight: Double?
    
    let goals: Goals
    
    init(goals: Goals) {
        self.goals = goals
        _targetTrainings = State(initialValue: goals.targetTrainingsPerWeek)
        _targetWeight = State(initialValue: goals.targetWeight)
        _startingWeight = State(initialValue: goals.startingWeight)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Training Goals")) {
                    Stepper("Target trainings per week: \(targetTrainings)", value: $targetTrainings, in: 1...7)
                }
                
                Section(header: Text("Weight Goals")) {
                    HStack {
                        Text("Starting Weight")
                        Spacer()
                        TextField("Weight", value: $startingWeight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("kg")
                    }
                    
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
                        goals.startingWeight = startingWeight
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
                        Text("1.0.5")
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
        // Delete all data
        func deleteAll<T>(_ type: T.Type) where T: PersistentModel {
            let descriptor = FetchDescriptor<T>()
            if let items = try? modelContext.fetch(descriptor) {
                for item in items {
                    modelContext.delete(item)
                }
            }
        }
        
        // Delete each type of data
        deleteAll(WeightEntry.self)
        deleteAll(Training.self)
        deleteAll(Exercise.self)
        deleteAll(Goals.self)
        deleteAll(Media.self)
        deleteAll(Meal.self)
        
        // Reset user settings
        if let settings = settings {
            settings.userName = ""
            settings.hasCompletedWelcome = false
            showingWelcome = true
        }
    }
}

struct ExerciseCountCard: View {
    let type: ExerciseType
    let count: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(type.rawValue)
                .font(.subheadline)
            Text("\(count) times")
                .font(.title3)
                .bold()
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .frame(width: 150)
    }
}

struct FocusExerciseSection: View {
    let focus: TrainingFocus
    let exercises: [(type: ExerciseType, count: Int)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(focus.rawValue)
                .font(.headline)
                .foregroundColor(focus.color)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(exercises, id: \.type) { item in
                        ExerciseCountCard(type: item.type, count: item.count)
                    }
                }
                .padding(.vertical, 5)
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WeightEntry.self, UserSettings.self, Item.self], inMemory: true)
}

