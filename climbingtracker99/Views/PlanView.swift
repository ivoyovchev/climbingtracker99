import SwiftUI
import SwiftData
import UserNotifications

struct PlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlannedTraining.date) private var plannedTrainings: [PlannedTraining]
    @Query(sort: \PlannedRun.date) private var plannedRuns: [PlannedRun]
    @Query private var exercises: [Exercise]
    
    @State private var selectedDate: Date = Date()
    @State private var showingAddPlan = false
    @State private var planType: PlanType = .training
    
    enum PlanType {
        case training
        case run
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Calendar View
                CalendarView(
                    selectedDate: $selectedDate,
                    plannedTrainings: plannedTrainings,
                    plannedRuns: plannedRuns
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
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                    }
                }
            }
            .sheet(isPresented: $showingAddPlan) {
                if planType == .training {
                    AddPlannedTrainingView(date: selectedDate)
                } else {
                    AddPlannedRunView(date: selectedDate)
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
    
    var id: String {
        switch self {
        case .training(let t):
            return "training-\(t.persistentModelID.hashValue)"
        case .run(let r):
            return "run-\(r.persistentModelID.hashValue)"
        }
    }
    
    var date: Date {
        switch self {
        case .training(let t):
            return t.date
        case .run(let r):
            return r.date
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

// Calendar View Component
struct CalendarView: View {
    @Binding var selectedDate: Date
    @State private var currentMonth: Date = Date()
    let plannedTrainings: [PlannedTraining]
    let plannedRuns: [PlannedRun]
    
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
            
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
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
        
        return hasTraining || hasRun
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

