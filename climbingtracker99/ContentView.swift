//
//  ContentView.swift
//  climbingtracker99
//
//  Created by Ivo Yovchev on 17/04/2025.
//

import SwiftUI
import SwiftData
import WidgetKit
import Charts
import UserNotifications
import FirebaseAuth

struct TabNavigationTitle: ViewModifier {
    let title: String
    
    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.headline)
                }
            }
    }
}

extension View {
    func tabNavigationTitle(_ title: String) -> some View {
        modifier(TabNavigationTitle(title: title))
    }
    @ViewBuilder
    func ifLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var recordingManager = RecordingManager.shared
    @State private var showingActiveRecording = false
    @State private var showingCancelRecordingAlert = false
    @State private var activeRecordingSnapshot: ActiveRecordingSnapshot?
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }
            
            ActivityView()
                .tabItem {
                    Label("Activity", systemImage: "list.bullet.rectangle")
                }
            
            BasecampView()
                .tabItem {
                    Label("Basecamp", systemImage: "person.2.fill")
                }
            
            PlanView()
                .tabItem {
                    Label("Plan", systemImage: "calendar")
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
        .safeAreaInset(edge: .top) {
            if let snapshot = recordingManager.snapshot {
                ActiveRecordingBanner(
                    snapshot: snapshot,
                    onResume: {
                        activeRecordingSnapshot = snapshot
                        RecordingManager.shared.snapshot = nil
                        showingActiveRecording = true
                    },
                    onCancel: { showingCancelRecordingAlert = true }
                )
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .fullScreenCover(isPresented: $showingActiveRecording, onDismiss: {
            activeRecordingSnapshot = nil
        }) {
            if let snapshot = activeRecordingSnapshot {
                RecordTrainingView(training: snapshot.training, snapshot: snapshot)
            } else {
                RecordTrainingView()
            }
        }
        .alert("End current training?", isPresented: $showingCancelRecordingAlert) {
            Button("Stop Recording", role: .destructive) {
                RecordingManager.shared.snapshot = nil
                activeRecordingSnapshot = nil
            }
            Button("Continue", role: .cancel) { }
        } message: {
            Text("This will discard the ongoing training session.")
        }
    }
}

struct HealthView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    @State private var showingAddWeight = false
    @State private var entryToEdit: WeightEntry?
    @State private var isSyncingHealth = false
    @State private var showingCustomize = false
    
    // HealthKit-backed state
    @State private var hkWeight: [(date: Date, kg: Double)] = []
    @State private var hkSleep: [(start: Date, end: Date, value: Int)] = []
    @State private var hkHRSamples: [(date: Date, bpm: Double)] = []
    @State private var hkEnergyDaily: [(date: Date, kcal: Double)] = []
    
    init() {}
    
    // Metric configuration
    enum HealthMetricType: String, CaseIterable, Identifiable { case weight = "Weight", sleep = "Sleep", heartRate = "Heart Rate", energy = "Active Energy"; var id: String { rawValue } }
    struct MetricConfig: Identifiable { let id = UUID(); var type: HealthMetricType; var enabled: Bool }
    @State private var metricConfigs: [MetricConfig] = [
        .init(type: .weight, enabled: true),
        .init(type: .sleep, enabled: true),
        .init(type: .heartRate, enabled: true),
        .init(type: .energy, enabled: true)
    ]
    
    private func filterSeries(_ series: [(Date, Double)]) -> [(Date, Double)] {
        let start = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let filtered = series.filter { $0.0 >= start }
        if !filtered.isEmpty { return filtered }
        // Fallback: show recent points if range has no data
        return Array(series.suffix(365))
    }
    
    // Aggregations
    private var weightSeries: [(Date, Double)] {
        let samples = hkWeight.isEmpty ? weightEntries.map { ($0.date, $0.weight) } : hkWeight
        // Aggregate to daily (latest of the day)
        var byDay: [Date: (Date, Double)] = [:]
        for (date, value) in samples {
            let day = Calendar.current.startOfDay(for: date)
            if let existing = byDay[day] {
                if date > existing.0 { byDay[day] = (date, value) }
            } else {
                byDay[day] = (date, value)
            }
        }
        return byDay.map { ($0.key, $0.value.1) }.sorted { $0.0 < $1.0 }
    }
    private var weightYAxisRange: ClosedRange<Double>? {
        let data = filterSeries(weightSeries)
        guard !data.isEmpty else { return nil }
        let weights = data.map { $0.1 }
        guard let minVal = weights.min(), let maxVal = weights.max() else { return nil }
        let lower = minVal - 5
        let upper = maxVal + 5
        if lower == upper {
            return (lower - 1)...(upper + 1)
        }
        return lower...upper
    }
    private var sleepDailyHours: [(Date, Double)] {
        var map: [Date: Double] = [:]
        let cal = Calendar.current
        for seg in hkSleep where [1,3,4,5].contains(seg.value) {
            var cursorStart = seg.start
            let end = seg.end
            while cursorStart < end {
                let dayStart = cal.startOfDay(for: cursorStart)
                let nextDay = cal.date(byAdding: .day, value: 1, to: dayStart)!
                let chunkEnd = min(end, nextDay)
                let hours = chunkEnd.timeIntervalSince(cursorStart) / 3600.0
                map[dayStart, default: 0] += max(0, hours)
                cursorStart = chunkEnd
            }
        }
        return map.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }
    private var sleepLastNightHours: Double? {
        sleepDailyHours.last?.1
    }
    private var sleepSevenDayAverage: Double? {
        guard !sleepDailyHours.isEmpty else { return nil }
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentValues = sleepDailyHours.filter { $0.0 >= start }
        let samples = recentValues.isEmpty ? Array(sleepDailyHours.suffix(min(7, sleepDailyHours.count))) : recentValues
        guard !samples.isEmpty else { return nil }
        let totalHours = samples.reduce(0) { $0 + $1.1 }
        return totalHours / Double(samples.count)
    }
    private var sleepAllTimeAverage: Double? {
        guard !sleepDailyHours.isEmpty else { return nil }
        let values = sleepDailyHours.map { $0.1 }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
    private var hrSeries: [(Date, Double)] { hkHRSamples.sorted { $0.0 < $1.0 } }
    private var energySeries: [(Date, Double)] { hkEnergyDaily.sorted { $0.0 < $1.0 } }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    TabHeaderView(title: "Health") {
                        HStack(spacing: 16) {
                            Button(action: { showingCustomize = true }) { Image(systemName: "slider.horizontal.3").font(.system(size: 22)) }
                            Button(action: { syncWithAppleHealth() }) {
                                if isSyncingHealth { ProgressView().progressViewStyle(CircularProgressViewStyle()) }
                                else { Image(systemName: "arrow.down.circle.fill").font(.system(size: 24)) }
                            }
                            Button(action: { showingAddWeight = true }) { Image(systemName: "plus.circle.fill").font(.system(size: 24)) }
                        }
                    }
                    
                    VStack(spacing: 16) {
                        ForEach(metricConfigs.indices, id: \.self) { idx in
                            if metricConfigs[idx].enabled {
                                switch metricConfigs[idx].type {
                                case .weight:
                                    MetricChart(title: "Weight", unit: "kg", color: .blue, series: filterSeries(weightSeries), yRange: weightYAxisRange)
                                case .sleep:
                                    SleepSummaryView(lastNightHours: sleepLastNightHours, sevenDayAverage: sleepSevenDayAverage, allTimeAverage: sleepAllTimeAverage)
                                case .heartRate:
                                    MetricChart(title: "Heart Rate", unit: "bpm", color: .red, series: filterSeries(hrSeries))
                                case .energy:
                                    MetricChart(title: "Active Energy", unit: "kcal", color: .orange, series: filterSeries(energySeries))
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .tabNavigationTitle("Health")
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddWeight) { WeightEntryView() }
            .sheet(isPresented: $showingCustomize) { customizeSheet }
            .task { await refreshHealthDataOnAppear() }
        }
    }
    
    private var customizeSheet: some View {
        NavigationStack {
            List {
                ForEach($metricConfigs) { $config in
                    HStack {
                        Image(systemName: config.enabled ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(config.enabled ? .blue : .secondary)
                        Text(config.type.rawValue)
                        Spacer()
                        Toggle("", isOn: $config.enabled).labelsHidden()
                    }
                }
                .onMove { indices, newOffset in
                    metricConfigs.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .navigationTitle("Customize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { showingCustomize = false } }
            }
        }
    }
    
    private func syncWithAppleHealth() {
        guard HealthKitManager.shared.isHealthDataAvailable else { return }
        isSyncingHealth = true
        Task {
            do {
                try await HealthKitManager.shared.requestAuthorization()
                let now = Date()
                let start6m = Calendar.current.date(byAdding: .month, value: -12, to: now) ?? Date.distantPast
                // Weight
                hkWeight = try await HealthKitManager.shared.fetchBodyMassSamples(from: start6m, to: now)
                // Sleep last 30d (fallback to 12m if empty)
                let primarySleepStart = Calendar.current.date(byAdding: .day, value: -30, to: now)!
                hkSleep = try await HealthKitManager.shared.fetchSleepFallbackIfEmpty(primaryStart: primarySleepStart, end: now)
                // Heart Rate last 14d
                hkHRSamples = try await HealthKitManager.shared.fetchHeartRateSamples(from: Calendar.current.date(byAdding: .day, value: -14, to: now)!, to: now)
                // Energy daily last 14d (sum per day)
                var daily: [(Date, Double)] = []
                for d in 0..<14 {
                    let day = Calendar.current.date(byAdding: .day, value: -d, to: now)!
                    let start = Calendar.current.startOfDay(for: day)
                    let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
                    let kcal = try await HealthKitManager.shared.fetchActiveEnergySum(from: start, to: end)
                    daily.append((start, kcal))
                }
                hkEnergyDaily = daily.sorted { $0.0 < $1.0 }
                // Import new weights
                let existing = Set(weightEntries.map { $0.date.timeIntervalSince1970 })
                for (date, kg) in hkWeight where !existing.contains(date.timeIntervalSince1970) {
                    modelContext.insert(WeightEntry(weight: kg, date: date))
                }
            } catch { print("Health sync error: \(error)") }
            isSyncingHealth = false
        }
    }
    
    private func refreshHealthDataOnAppear() async {
        guard HealthKitManager.shared.isHealthDataAvailable else { return }
        do {
            try await HealthKitManager.shared.requestAuthorization()
            let now = Date()
            let start6m = Calendar.current.date(byAdding: .month, value: -12, to: now) ?? Date.distantPast
            hkWeight = try await HealthKitManager.shared.fetchBodyMassSamples(from: start6m, to: now)
            let primarySleepStart = Calendar.current.date(byAdding: .day, value: -30, to: now)!
            hkSleep = try await HealthKitManager.shared.fetchSleepFallbackIfEmpty(primaryStart: primarySleepStart, end: now)
            hkHRSamples = try await HealthKitManager.shared.fetchHeartRateSamples(from: Calendar.current.date(byAdding: .day, value: -14, to: now)!, to: now)
            var daily: [(Date, Double)] = []
            for d in 0..<14 {
                let day = Calendar.current.date(byAdding: .day, value: -d, to: now)!
                let start = Calendar.current.startOfDay(for: day)
                let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
                let kcal = try await HealthKitManager.shared.fetchActiveEnergySum(from: start, to: end)
                daily.append((start, kcal))
            }
            hkEnergyDaily = daily.sorted { $0.0 < $1.0 }
        } catch {
            print("Health refresh error: \(error)")
        }
    }
}

private struct MetricChart: View {
    let title: String
    let unit: String
    let color: Color
    let series: [(Date, Double)]
    let yRange: ClosedRange<Double>?
    init(title: String, unit: String, color: Color, series: [(Date, Double)], yRange: ClosedRange<Double>? = nil) {
        self.title = title
        self.unit = unit
        self.color = color
        self.series = series
        self.yRange = yRange
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            if series.isEmpty {
                Text("No data").foregroundColor(.secondary).font(.footnote)
            } else {
                Chart {
                    ForEach(Array(series.enumerated()), id: \.offset) { _, p in
                        LineMark(x: .value("Date", p.0), y: .value(unit, p.1))
                            .foregroundStyle(color)
                        PointMark(x: .value("Date", p.0), y: .value(unit, p.1))
                            .symbolSize(36)
                            .foregroundStyle(color.opacity(0.8))
                    }
                }
                .ifLet(yRange) { chart, range in
                    chart.chartYScale(domain: range)
                }
                .frame(height: 220)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
        .cornerRadius(12)
    }
}

// Health metric card component
private struct HealthMetricCard<Content: View>: View {
    let title: String
    let value: String
    let subtitle: String
    let tint: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.subheadline).foregroundColor(.secondary)
                Spacer()
            }
            Text(value).font(.title2).bold().foregroundColor(.primary)
            if !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundColor(.secondary) }
            content
        }
        .padding(12)
        .background(Color(.systemBackground))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
        .cornerRadius(12)
    }
}

// Simple sparkline for weight
private struct Sparkline: View {
    let points: [(Date, Double)]
    var body: some View {
        if points.isEmpty {
            Rectangle().fill(Color.clear)
        } else {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                    LineMark(x: .value("Date", p.0), y: .value("Value", p.1))
                        .foregroundStyle(Color.blue)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        }
    }
}

private struct SleepSummaryView: View {
    let lastNightHours: Double?
    let sevenDayAverage: Double?
    let allTimeAverage: Double?
    
    private func formattedHours(_ hours: Double?) -> String {
        guard let hours = hours else { return "--" }
        let totalMinutes = Int((hours * 60).rounded())
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        switch (h, m) {
        case (_, 0): return "\(h)h"
        case (0, _): return "\(m)m"
        default: return "\(h)h \(m)m"
        }
    }
    
    private func trend(for value: Double?) -> (String, Color, String) {
        guard let value = value, let baseline = allTimeAverage else {
            return ("arrow.right", .secondary, "")
        }
        let diff = value - baseline
        let threshold = 0.1 // ~6 minutes
        if diff > threshold {
            let minutes = Int((diff * 60).rounded())
            return ("arrow.up", .green, String(format: "+%d min", minutes))
        } else if diff < -threshold {
            let minutes = Int((abs(diff) * 60).rounded())
            return ("arrow.down", .red, String(format: "-%d min", minutes))
        } else {
            return ("arrow.right", .secondary, "0 min")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep")
                .font(.headline)
            SleepStatRow(title: "Last Night", value: formattedHours(lastNightHours), trend: trend(for: lastNightHours))
            SleepStatRow(title: "7-day Avg", value: formattedHours(sevenDayAverage), trend: trend(for: sevenDayAverage))
        }
        .padding(12)
        .background(Color(.systemBackground))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
        .cornerRadius(12)
    }
}

private struct SleepStatRow: View {
    let title: String
    let value: String
    let trend: (String, Color, String)
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title3)
                    .bold()
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: trend.0)
                    .foregroundColor(trend.1)
                    .font(.title3)
                if !trend.2.isEmpty {
                    Text(trend.2)
                        .font(.footnote)
                        .foregroundColor(trend.1)
                }
            }
        }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userSettings: [UserSettings]
    @Query private var goals: [Goals]
    @Query private var plannedTrainings: [PlannedTraining]
    @Query private var plannedRuns: [PlannedRun]
    @Query private var plannedBenchmarks: [PlannedBenchmark]
    @Query private var exercises: [Exercise]
    @Query private var moonLogs: [MoonLogEntry]
    @State private var showingResetAlert = false
    @State private var showingWelcome = false
    @State private var moonUsername: String = Keychain.get("mb_username") ?? ""
    @State private var moonPassword: String = ""
    @State private var syncingMoon = false
    @State private var moonSyncMessage: String = ""
    @State private var isAuthErrorsVisible = false
    @State private var isShowingResetConfirmation = false
    
    enum AuthMode: String, CaseIterable, Identifiable {
        case signIn = "Sign In"
        case signUp = "Sign Up"
        var id: String { rawValue }
    }
    @State private var currentFirebaseUser: FirebaseAuth.User? = Auth.auth().currentUser
    @State private var authStateHandle: AuthStateDidChangeListenerHandle?
    @State private var authEmail: String = ""
    @State private var authPassword: String = ""
    @State private var authStatusMessage: String = ""
    @State private var authStatusColor: Color = .secondary
    @State private var isProcessingAuth: Bool = false
    @State private var authMode: AuthMode = .signIn
    
    private var settings: UserSettings? {
        userSettings.first
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Account")) {
                    if let user = currentFirebaseUser {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Signed in as")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(user.email ?? "Unknown email")
                                .font(.body)
                            Text("User ID: \(user.uid)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if isProcessingAuth {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Button(role: .destructive) {
                                signOut()
                            } label: {
                                Text("Sign Out")
                            }
                        }
                    } else {
                        Picker("", selection: $authMode) {
                            ForEach(AuthMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 4)
                        TextField("Email", text: $authEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.emailAddress)
                        SecureField("Password", text: $authPassword)
                            .textContentType(.password)
                        if authMode == .signUp {
                            Text("Password must be at least 6 characters.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if isProcessingAuth {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Button(authMode == .signIn ? "Sign In" : "Create Account") {
                                handleAuthAction()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(authEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || authPassword.count < 6)
                        }
                    }
                    if !authStatusMessage.isEmpty {
                        Text(authStatusMessage)
                            .font(.footnote)
                            .foregroundColor(authStatusColor)
                            .padding(.top, 4)
                    }
                }
                
                Section(header: Text("MoonBoard")) {
                    HStack {
                        Text("Username")
                        Spacer()
                        TextField("username", text: $moonUsername)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                    }
                    HStack {
                        Text("Password")
                        Spacer()
                        SecureField("password", text: $moonPassword)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        if syncingMoon { ProgressView() }
                        Button("Sync from MoonBoard") { Task { await syncMoonBoard() } }
                            .disabled(moonUsername.isEmpty || moonPassword.isEmpty)
                        Spacer()
                        if !moonSyncMessage.isEmpty {
                            Text(moonSyncMessage).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
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
                
                Section(header: Text("Notifications")) {
                    Toggle(isOn: Binding(
                        get: { self.settings?.notificationsEnabled ?? true },
                        set: { newValue in
                            if let settings = self.settings {
                                settings.notificationsEnabled = newValue
                                NotificationManager.shared.syncSettings(
                                    enabled: newValue,
                                    reminderHours: settings.notificationReminderHours
                                )
                                
                                // Update notification authorization and reschedule if enabled
                                Task {
                                    if newValue {
                                        _ = await NotificationManager.shared.requestAuthorization()
                                        // Reschedule all notifications
                                        let trainingDescriptor = FetchDescriptor<PlannedTraining>()
                                        let runDescriptor = FetchDescriptor<PlannedRun>()
                                        let benchmarkDescriptor = FetchDescriptor<PlannedBenchmark>()
                                        if let trainings = try? modelContext.fetch(trainingDescriptor),
                                           let runs = try? modelContext.fetch(runDescriptor),
                                           let benchmarks = try? modelContext.fetch(benchmarkDescriptor) {
                                            NotificationManager.shared.rescheduleAllNotifications(
                                                trainings: trainings,
                                                runs: runs,
                                                benchmarks: benchmarks
                                            )
                                        }
                                    } else {
                                        // Remove all pending notifications
                                        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                                    }
                                }
                            }
                        }
                    )) {
                        HStack {
                            Image(systemName: "bell")
                            Text("Plan Reminders")
                        }
                    }
                    
                    if self.settings?.notificationsEnabled ?? true {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Reminder Time")
                                Spacer()
                                Text(formatReminderTime(self.settings?.notificationReminderHours ?? 1.5))
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(
                                value: Binding(
                                    get: { self.settings?.notificationReminderHours ?? 1.5 },
                                    set: { newValue in
                                        if let settings = self.settings {
                                            settings.notificationReminderHours = newValue
                                            NotificationManager.shared.syncSettings(
                                                enabled: settings.notificationsEnabled,
                                                reminderHours: newValue
                                            )
                                            
                                            // Reschedule all notifications with new time
                                            Task {
                                                let trainingDescriptor = FetchDescriptor<PlannedTraining>()
                                                let runDescriptor = FetchDescriptor<PlannedRun>()
                                                if let trainings = try? modelContext.fetch(trainingDescriptor),
                                                   let runs = try? modelContext.fetch(runDescriptor) {
                                                    NotificationManager.shared.rescheduleAllNotifications(
                                                        trainings: trainings,
                                                        runs: runs
                                                    )
                                                }
                                            }
                                        }
                                    }
                                ),
                                in: 0.5...3.0,
                                step: 0.5
                            )
                            
                            HStack {
                                Text("30 min")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("3 hours")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button(action: {
                            testNotification()
                        }) {
                            HStack {
                                Image(systemName: "bell.badge")
                                Text("Test Notification")
                            }
                        }
                    }
                }
                
                Section(header: Text("Media")) {
                    NavigationLink(destination: MomentsView()) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("Moments")
                        }
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.2.1")
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
            .tabNavigationTitle("Settings")
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
        .onAppear {
            if authStateHandle == nil {
                authStateHandle = Auth.auth().addStateDidChangeListener { _, user in
                    DispatchQueue.main.async {
                        self.currentFirebaseUser = user
                        if let email = user?.email {
                            self.authEmail = email
                        }
                    }
                }
            }
        }
        .onDisappear {
            if let handle = authStateHandle {
                Auth.auth().removeStateDidChangeListener(handle)
                authStateHandle = nil
            }
        }
    }
    
    private func syncMoonBoard() async {
        syncingMoon = true
        moonSyncMessage = ""
        do {
            Keychain.set(moonUsername, for: "mb_username")
            let token = try await MoonBoardClient.shared.login(username: moonUsername, password: moonPassword)
            let since = Calendar.current.date(byAdding: .year, value: -1, to: Date())
            let entries = try await MoonBoardClient.shared.fetchLogbook(accessToken: token, since: since)
            var imported = 0
            for dto in entries {
                // Parse date (accept ISO8601 or yyyy-MM-dd)
                let date: Date
                if let d = ISO8601DateFormatter().date(from: dto.date) {
                    date = d
                } else {
                    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; date = f.date(from: dto.date) ?? Date()
                }
                // Deduplicate by (date + problemId)
                if !moonLogs.contains(where: { $0.problemId == dto.problem.id && Calendar.current.isDate($0.date, inSameDayAs: date) }) {
                    let entry = MoonLogEntry(date: date,
                                             problemId: dto.problem.id,
                                             problemName: dto.problem.name,
                                             grade: dto.problem.grade,
                                             board: dto.problem.board ?? "",
                                             attempts: dto.attempts,
                                             sent: dto.sent)
                    modelContext.insert(entry)
                    imported += 1
                }
            }
            moonSyncMessage = "Imported \(imported) entries"
        } catch {
            moonSyncMessage = "Sync failed"
        }
        syncingMoon = false
    }
    
    private func handleAuthAction() {
        let email = authEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !email.isEmpty else {
            authStatusColor = .red
            authStatusMessage = "Please enter an email address."
            return
        }
        guard authPassword.count >= 6 else {
            authStatusColor = .red
            authStatusMessage = "Password must be at least 6 characters."
            return
        }
        isProcessingAuth = true
        authStatusMessage = ""
        if authMode == .signUp {
            Auth.auth().createUser(withEmail: email, password: authPassword) { result, error in
                handleAuthResult(user: result?.user, error: error, successMessage: "Account created successfully.")
            }
        } else {
            Auth.auth().signIn(withEmail: email, password: authPassword) { result, error in
                handleAuthResult(user: result?.user, error: error, successMessage: "Signed in successfully.")
            }
        }
    }
    
    private func handleAuthResult(user: FirebaseAuth.User?, error: Error?, successMessage: String) {
        DispatchQueue.main.async {
            self.isProcessingAuth = false
            if let error = error {
                self.authStatusColor = .red
                self.authStatusMessage = error.localizedDescription
                return
            }
            self.authStatusColor = .green
            self.authStatusMessage = successMessage
            self.authPassword = ""
            if let user = user {
                self.currentFirebaseUser = user
                self.authEmail = user.email ?? self.authEmail
                FirebaseSyncManager.shared.triggerFullSync()
            }
            self.authMode = .signIn
        }
    }
    
    private func signOut() {
        isProcessingAuth = true
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                self.isProcessingAuth = false
                self.currentFirebaseUser = nil
                self.authStatusColor = .secondary
                self.authStatusMessage = "Signed out."
                self.authPassword = ""
            }
        } catch {
            DispatchQueue.main.async {
                self.isProcessingAuth = false
                self.authStatusColor = .red
                self.authStatusMessage = error.localizedDescription
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
        deleteAll(MoonLogEntry.self)
        
        // Reset user settings
        if let settings = settings {
            settings.userName = ""
            settings.hasCompletedWelcome = false
            showingWelcome = true
        }
    }
    
    private func formatReminderTime(_ hours: Double) -> String {
        if hours == 1.0 {
            return "1 hour before"
        } else if hours < 1.0 {
            let minutes = Int(hours * 60)
            return "\(minutes) min before"
        } else {
            let wholeHours = Int(hours)
            let minutes = Int((hours - Double(wholeHours)) * 60)
            if minutes > 0 {
                return "\(wholeHours)h \(minutes)m before"
            } else {
                return String(format: "%.1f hours before", hours)
            }
        }
    }
    
    private func testNotification() {
        Task {
            // Request authorization if needed
            let authorized = await NotificationManager.shared.requestAuthorization()
            
            guard authorized else {
                print("Notification authorization denied")
                return
            }
            
            // Verify delegate is set
            if UNUserNotificationCenter.current().delegate == nil {
                UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
            }
            
            // Small delay to ensure everything is ready
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Check if we have any plans to base the test on
            let trainingDescriptor = FetchDescriptor<PlannedTraining>(sortBy: [SortDescriptor(\.date)])
            let runDescriptor = FetchDescriptor<PlannedRun>(sortBy: [SortDescriptor(\.date)])
            
            if let nextTraining = try? modelContext.fetch(trainingDescriptor).first {
                // Show test notification based on next training
                NotificationManager.shared.sendTestNotification(for: nextTraining)
            } else if let nextRun = try? modelContext.fetch(runDescriptor).first {
                // Show test notification based on next run
                NotificationManager.shared.sendTestNotification(for: nextRun)
            } else {
                // Send a generic test notification
                NotificationManager.shared.sendTestNotification()
            }
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

struct ExerciseGoalProgressView: View {
    let goal: ExerciseGoal
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.exerciseType.rawValue)
                    .font(.headline)
                Spacer()
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progress)
                .tint(progressColor)
            
            HStack {
                if goal.exerciseType == .hangboarding {
                    let currentDuration = Int(goal.getCurrentValue("duration") ?? 0)
                    let targetDuration = Int(goal.getTargetValue("duration") ?? 0)
                    Text("\(currentDuration)s / \(targetDuration)s")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if goal.exerciseType == .repeaters {
                    let currentReps = Int(goal.getCurrentValue("repetitions") ?? 0)
                    let targetReps = Int(goal.getTargetValue("repetitions") ?? 0)
                    Text("\(currentReps) / \(targetReps) reps")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let deadline = goal.deadline {
                    Text(deadline.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var progressColor: Color {
        switch progress {
        case 0..<0.5: return .red
        case 0.5..<0.8: return .orange
        case 0.8..<1.0: return .yellow
        default: return .green
        }
    }
}

struct CircularProgressView: View {
    let progress: Double
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text(String(format: "%.0f%%", progress * 100))
                        .font(.headline)
                    Text(title)
                        .font(.caption)
                }
            }
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WeightEntry.self, UserSettings.self, Item.self], inMemory: true)
}

