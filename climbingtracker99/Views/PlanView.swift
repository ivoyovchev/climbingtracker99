import SwiftUI
import SwiftData
import UserNotifications

struct PlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlannedTraining.date) private var plannedTrainings: [PlannedTraining]
    @Query(sort: \PlannedRun.date) private var plannedRuns: [PlannedRun]
    @Query(sort: \PlannedBenchmark.date) private var plannedBenchmarks: [PlannedBenchmark]
    @Query private var exercises: [Exercise]
    
    @State private var selectedDate: Date = Date()
    @State private var showingAddPlan = false
    @State private var planType: PlanType = .training
    
    enum PlanType {
        case training
        case run
        case benchmark
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Calendar View
                CalendarView(
                    selectedDate: $selectedDate,
                    plannedTrainings: plannedTrainings,
                    plannedRuns: plannedRuns,
                    plannedBenchmarks: plannedBenchmarks
                )
                    .padding()
                    .background(Color(.systemBackground))
                
                Divider()
                
                // Plans for selected date
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        let plansForDate = getPlansForDate(selectedDate)
                        
                        if plansForDate.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("No plans for this date")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("Tap the + button to add a plan")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        } else {
                            ForEach(plansForDate) { plan in
                                PlanCard(plan: plan)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Plan")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            planType = .training
                            showingAddPlan = true
                        }) {
                            Label("Add Training", systemImage: "figure.climbing")
                        }
                        
                        Button(action: {
                            planType = .run
                            showingAddPlan = true
                        }) {
                            Label("Add Run", systemImage: "figure.run")
                        }
                        
                        Button(action: {
                            planType = .benchmark
                            showingAddPlan = true
                        }) {
                            Label("Add Benchmark", systemImage: "chart.line.uptrend.xyaxis")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                    }
                }
            }
            .sheet(isPresented: $showingAddPlan) {
                if planType == .training {
                    AddPlannedTrainingView(date: selectedDate)
                } else if planType == .run {
                    AddPlannedRunView(date: selectedDate)
                } else {
                    AddPlannedBenchmarkView(date: selectedDate)
                }
            }
            .onAppear {
                migrateExistingPlans()
                setupNotifications()
            }
        }
    }
    
    // Helper to format time
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Migrate existing plans to have default time (5:30 PM)
    private func migrateExistingPlans() {
        var needsSave = false
        
        // Set default time for trainings without time
        for training in plannedTrainings where training.estimatedTime == nil {
            training.estimatedTime = PlannedTraining.defaultTime
            needsSave = true
        }
        
        // Set default time for runs without time
        for run in plannedRuns where run.estimatedTime == nil {
            run.estimatedTime = PlannedRun.defaultTime
            needsSave = true
        }
        
        if needsSave {
            do {
                try modelContext.save()
            } catch {
                print("Failed to migrate plan times: \(error.localizedDescription)")
            }
        }
    }
    
    // Setup notifications for all existing plans
    private func setupNotifications() {
        // Check if notifications are enabled first
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        if let userSettings = try? modelContext.fetch(settingsDescriptor).first,
           !userSettings.notificationsEnabled {
            return // Don't schedule if disabled
        }
        
        Task {
            // Request authorization
            _ = await NotificationManager.shared.requestAuthorization()
            
            // Schedule notifications for all existing plans
            for training in plannedTrainings {
                NotificationManager.shared.scheduleTrainingNotification(for: training)
            }
            
            for run in plannedRuns {
                NotificationManager.shared.scheduleRunNotification(for: run)
            }
            
            for benchmark in plannedBenchmarks {
                NotificationManager.shared.scheduleBenchmarkNotification(for: benchmark)
            }
        }
    }
    
    private func getPlansForDate(_ date: Date) -> [PlanItem] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        var plans: [PlanItem] = []
        
        // Add planned trainings
        for training in plannedTrainings where training.date >= startOfDay && training.date < endOfDay {
            plans.append(.training(training))
        }
        
        // Add planned runs
        for run in plannedRuns where run.date >= startOfDay && run.date < endOfDay {
            plans.append(.run(run))
        }
        
        // Add planned benchmarks
        for benchmark in plannedBenchmarks where benchmark.date >= startOfDay && benchmark.date < endOfDay {
            plans.append(.benchmark(benchmark))
        }
        
        // Sort by date
        return plans.sorted { plan1, plan2 in
            let date1 = plan1.date
            let date2 = plan2.date
            return date1 < date2
        }
    }
}

enum PlanItem: Identifiable {
    case training(PlannedTraining)
    case run(PlannedRun)
    case benchmark(PlannedBenchmark)
    
    var id: String {
        switch self {
        case .training(let t):
            return "training-\(t.persistentModelID.hashValue)"
        case .run(let r):
            return "run-\(r.persistentModelID.hashValue)"
        case .benchmark(let b):
            return "benchmark-\(b.persistentModelID.hashValue)"
        }
    }
    
    var date: Date {
        switch self {
        case .training(let t):
            return t.date
        case .run(let r):
            return r.date
        case .benchmark(let b):
            return b.date
        }
    }
}

struct PlanCard: View {
    let plan: PlanItem
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Group {
            switch plan {
            case .training(let training):
                TrainingPlanCard(training: training)
            case .run(let run):
                RunPlanCard(run: run)
            case .benchmark(let benchmark):
                BenchmarkPlanCard(benchmark: benchmark)
            }
        }
    }
}

struct TrainingPlanCard: View {
    let training: PlannedTraining
    @Environment(\.modelContext) private var modelContext
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    
    // Helper to format time
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.climbing")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                if training.exerciseTypes.count == 1 {
                    Text(training.exerciseTypes.first?.displayName ?? "Training")
                        .font(.headline)
                } else {
                    Text("\(training.exerciseTypes.count) Exercises")
                        .font(.headline)
                    
                    Text(training.exerciseTypes.prefix(3).map { $0.displayName }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 12) {
                    Label("\(training.estimatedDuration) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label(formatTime(training.estimatedTimeOfDay), systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Menu {
                Button(action: {
                    showingEdit = true
                }) {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive, action: {
                    showingDeleteAlert = true
                }) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showingEdit) {
            EditPlannedTrainingView(training: training)
        }
        .alert("Delete Plan", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                NotificationManager.shared.removeTrainingNotification(for: training)
                modelContext.delete(training)
            }
        } message: {
            Text("Are you sure you want to delete this planned training?")
        }
    }
}

struct RunPlanCard: View {
    let run: PlannedRun
    @Environment(\.modelContext) private var modelContext
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    
    // Helper to format time
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.title2)
                .foregroundColor(.green)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(run.runningType.rawValue)
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Label(String(format: "%.1f km", run.estimatedDistance), systemImage: "map")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let tempo = run.estimatedTempo {
                        Label(String(format: "%.1f min/km", tempo), systemImage: "gauge")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Label("\(run.estimatedDuration) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label(formatTime(run.estimatedTimeOfDay), systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Menu {
                Button(action: {
                    showingEdit = true
                }) {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive, action: {
                    showingDeleteAlert = true
                }) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showingEdit) {
            EditPlannedRunView(run: run)
        }
        .alert("Delete Plan", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                NotificationManager.shared.removeRunNotification(for: run)
                modelContext.delete(run)
            }
        } message: {
            Text("Are you sure you want to delete this planned run?")
        }
    }
}

struct BenchmarkPlanCard: View {
    let benchmark: PlannedBenchmark
    @Environment(\.modelContext) private var modelContext
    @State private var showingEdit = false
    @State private var showingRecordResults = false
    @State private var showingDeleteAlert = false
    
    // Helper to format time
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: benchmark.benchmarkType.iconName)
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(benchmark.benchmarkType.displayName)
                        .font(.headline)
                    
                    if benchmark.completed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                HStack(spacing: 12) {
                    Label(formatTime(benchmark.estimatedTimeOfDay), systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if benchmark.completed, let value1 = benchmark.resultValue1 {
                        let unit = benchmark.benchmarkType.unit
                        if benchmark.benchmarkType.requiresTwoHands, let value2 = benchmark.resultValue2 {
                            Label("Left: \(String(format: "%.1f", value1)) \(unit), Right: \(String(format: "%.1f", value2)) \(unit)", systemImage: "checkmark")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Label("\(String(format: "%.1f", value1)) \(unit)", systemImage: "checkmark")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            Spacer()
            
            Menu {
                if !benchmark.completed {
                    Button(action: {
                        showingRecordResults = true
                    }) {
                        Label("Record Results", systemImage: "pencil")
                    }
                }
                
                Button(action: {
                    showingEdit = true
                }) {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive, action: {
                    showingDeleteAlert = true
                }) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showingEdit) {
            EditPlannedBenchmarkView(benchmark: benchmark)
        }
        .sheet(isPresented: $showingRecordResults) {
            RecordBenchmarkResultsView(benchmark: benchmark)
        }
        .alert("Delete Benchmark", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                NotificationManager.shared.removeBenchmarkNotification(for: benchmark)
                modelContext.delete(benchmark)
            }
        } message: {
            Text("Are you sure you want to delete this benchmark?")
        }
    }
}

struct EditPlannedBenchmarkView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let benchmark: PlannedBenchmark
    @State private var selectedBenchmarkType: BenchmarkType
    @State private var estimatedTime: Date
    @State private var notes: String
    
    init(benchmark: PlannedBenchmark) {
        self.benchmark = benchmark
        _selectedBenchmarkType = State(initialValue: benchmark.benchmarkType)
        _estimatedTime = State(initialValue: benchmark.estimatedTimeOfDay)
        _notes = State(initialValue: benchmark.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Benchmark Details")) {
                    Picker("Benchmark Type", selection: $selectedBenchmarkType) {
                        ForEach(BenchmarkType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.iconName)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    
                    Text(selectedBenchmarkType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    
                    DatePicker("Estimated Time", selection: $estimatedTime, displayedComponents: .hourAndMinute)
                }
                
                Section(header: Text("Notes")) {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button("Save Changes") {
                        saveChanges()
                    }
                }
            }
            .navigationTitle("Edit Benchmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveChanges() {
        benchmark.benchmarkType = selectedBenchmarkType
        benchmark.estimatedTime = estimatedTime
        benchmark.notes = notes.isEmpty ? nil : notes
        
        // Reschedule notification when editing
        NotificationManager.shared.removeBenchmarkNotification(for: benchmark)
        Task {
            NotificationManager.shared.scheduleBenchmarkNotification(for: benchmark)
        }
        
        dismiss()
    }
}

// Calendar View Component
struct CalendarView: View {
    @Binding var selectedDate: Date
    @State private var currentMonth: Date = Date()
    let plannedTrainings: [PlannedTraining]
    let plannedRuns: [PlannedRun]
    let plannedBenchmarks: [PlannedBenchmark]
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button(action: {
                    withAnimation {
                        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)!
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(currentMonth, format: .dateTime.month().year())
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth)!
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                }
            }
            
            // Weekday headers (Monday first)
            HStack(spacing: 0) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(daysInMonth, id: \.self) { date in
                    DayView(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                        hasPlans: hasPlansForDate(date)
                    ) {
                        selectedDate = date
                    }
                }
            }
        }
    }
    
    private var daysInMonth: [Date] {
        guard let firstDay = calendar.dateInterval(of: .month, for: currentMonth)?.start else {
            return []
        }
        
        let firstDayWeekday = calendar.component(.weekday, from: firstDay)
        let daysToSubtract = (firstDayWeekday + 5) % 7 // Convert to Monday-based week
        
        guard let startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: firstDay) else {
            return []
        }
        
        var days: [Date] = []
        for i in 0..<42 { // 6 weeks
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func hasPlansForDate(_ date: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let hasTraining = plannedTrainings.contains { training in
            training.date >= startOfDay && training.date < endOfDay
        }
        
        let hasRun = plannedRuns.contains { run in
            run.date >= startOfDay && run.date < endOfDay
        }
        
        let hasBenchmark = plannedBenchmarks.contains { benchmark in
            benchmark.date >= startOfDay && benchmark.date < endOfDay
        }
        
        return hasTraining || hasRun || hasBenchmark
    }
}

struct DayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let hasPlans: Bool
    let action: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .white : (isCurrentMonth ? .primary : .secondary))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.blue : (isToday ? Color.blue.opacity(0.2) : Color.clear))
                    )
                
                // Dot indicator for plans
                if hasPlans {
                    Circle()
                        .fill(isSelected ? Color.white : Color.blue)
                        .frame(width: 4, height: 4)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
    }
}

