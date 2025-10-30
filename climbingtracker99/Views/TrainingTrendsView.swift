import SwiftUI
import SwiftData
import Charts

enum TrendsGranularity: String, CaseIterable {
    case weekly = "Weekly"
    case monthly = "Monthly"
}

struct TrainingTrendsView: View {
    let trainings: [Training]
    var weeklyTarget: Int? = nil
    @State private var granularity: TrendsGranularity = .weekly
    @State private var showMovingAverage: Bool = true
    @State private var showFocusMix: Bool = false
    
    // MARK: - Metrics
    private var totalMinutes: Int {
        trainings.map { $0.duration }.reduce(0, +)
    }
    
    private var longestSessionMinutes: Int {
        trainings.map { $0.duration }.max() ?? 0
    }
    
    private var currentStreakDays: Int {
        // Count consecutive days ending today (or yesterday if no training today)
        let cal = Calendar.current
        let daySet = Set(trainings.map { cal.startOfDay(for: $0.date) })
        guard !daySet.isEmpty else { return 0 }
        let today = cal.startOfDay(for: Date())
        let start = daySet.contains(today) ? today : cal.date(byAdding: .day, value: -1, to: today)!
        var streak = 0
        var cursor = start
        while daySet.contains(cursor) {
            streak += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
        }
        return streak
    }
    
    private var longestStreakDays: Int {
        let cal = Calendar.current
        let days = trainings
            .map { cal.startOfDay(for: $0.date) }
            .sorted()
        guard !days.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for i in 1..<days.count {
            if let prev = cal.date(byAdding: .day, value: 1, to: days[i - 1]), prev == days[i] {
                current += 1
                longest = max(longest, current)
            } else if days[i] != days[i - 1] {
                current = 1
            }
        }
        return longest
    }
    
    private var maxWorkoutsInAWeek: Int {
        weeklyBuckets(last: 256).map { $0.count }.max() ?? 0
    }
    
    private var maxWorkoutsInAMonth: Int {
        monthlyBuckets(last: 256).map { $0.count }.max() ?? 0
    }
    
    // MARK: - Aggregation
    private func weekKey(for date: Date) -> (year: Int, week: Int) {
        let cal = Calendar.iso8601
        let year = cal.component(.yearForWeekOfYear, from: date)
        let week = cal.component(.weekOfYear, from: date)
        return (year, week)
    }
    
    private func monthKey(for date: Date) -> (year: Int, month: Int) {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        return (y, m)
    }
    
    private func startOfWeek(year: Int, week: Int) -> Date? {
        var comps = DateComponents()
        comps.weekOfYear = week
        comps.yearForWeekOfYear = year
        comps.weekday = 2 // Monday
        return Calendar.iso8601.date(from: comps)
    }
    
    private func startOfMonth(year: Int, month: Int) -> Date? {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        return Calendar.current.date(from: comps)
    }
    
    private func weeklyBuckets(last n: Int = 12) -> [(date: Date, count: Int)] {
        // Group counts by ISO week
        var grouped: [String: Int] = [:]
        var dateMap: [String: Date] = [:]
        for t in trainings {
            let key = weekKey(for: t.date)
            if let d = startOfWeek(year: key.year, week: key.week) {
                let id = "\(key.year)-W\(key.week)"
                grouped[id, default: 0] += 1
                dateMap[id] = d
            }
        }
        let sorted = dateMap
            .map { ($0.value, grouped[$0.key] ?? 0) }
            .sorted { $0.0 < $1.0 }
        let sliced = sorted.suffix(n)
        return Array(sliced)
    }
    
    private func monthlyBuckets(last n: Int = 12) -> [(date: Date, count: Int)] {
        var grouped: [String: Int] = [:]
        var dateMap: [String: Date] = [:]
        for t in trainings {
            let key = monthKey(for: t.date)
            if let d = startOfMonth(year: key.year, month: key.month) {
                let id = "\(key.year)-\(key.month)"
                grouped[id, default: 0] += 1
                dateMap[id] = d
            }
        }
        let sorted = dateMap
            .map { ($0.value, grouped[$0.key] ?? 0) }
            .sorted { $0.0 < $1.0 }
        let sliced = sorted.suffix(n)
        return Array(sliced)
    }
    
    private func movingAverage(values: [Int], window: Int) -> [Double] {
        guard window > 1, values.count >= window else { return [] }
        var result: [Double] = []
        var sum = values[0..<window].reduce(0, +)
        result.append(Double(sum) / Double(window))
        if values.count == window { return result }
        for i in window..<values.count {
            sum += values[i]
            sum -= values[i - window]
            result.append(Double(sum) / Double(window))
        }
        return result
    }
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Training Trends")
                    .font(.title2)
                    .fontWeight(.bold)
                Picker("", selection: $granularity) {
                    ForEach(TrendsGranularity.allCases, id: \.self) { g in
                        Text(g.rawValue).tag(g)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
                Spacer()
            }
            .padding(.horizontal)
            
            // Metrics row: streaks, totals, PR badges
            MetricsRow(
                currentStreakDays: currentStreakDays,
                longestStreakDays: longestStreakDays,
                totalMinutes: totalMinutes,
                longestSessionMinutes: longestSessionMinutes,
                maxWeekCount: maxWorkoutsInAWeek,
                maxMonthCount: maxWorkoutsInAMonth
            )
            .padding(.horizontal)
            
            let data: [(date: Date, count: Int)] = {
                switch granularity {
                case .weekly: return weeklyBuckets(last: 16)
                case .monthly: return monthlyBuckets(last: 12)
                }
            }()
            
            if data.isEmpty {
                Text("No training data yet")
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                Chart {
                    if granularity == .weekly && showFocusMix {
                        // Replace totals with stacked focus bars when Focus mix is on
                        let focusPoints = weeklyFocusPoints(weeks: data.map { $0.date })
                        ForEach(focusPoints, id: \.id) { p in
                            BarMark(
                                x: .value("Week", p.date),
                                y: .value("Count", p.count),
                                stacking: .standard
                            )
                            .foregroundStyle(by: .value("Focus", p.focus.rawValue))
                        }
                    } else {
                        // Default: totals per period
                        ForEach(data, id: \.date) { point in
                            BarMark(
                                x: .value("Period", point.date),
                                y: .value("Workouts", point.count)
                            )
                            .foregroundStyle(Color.blue.opacity(0.7))
                        }
                    }
                    
                    if showMovingAverage {
                        let counts = data.map { $0.count }
                        let window = granularity == .weekly ? 4 : 3
                        let ma = movingAverage(values: counts, window: window)
                        if ma.count > 0 {
                            ForEach(Array(ma.enumerated()), id: \.offset) { idx, val in
                                // Align MA points to the last dates in the window
                                let xDate = data[idx + (window - 1)].date
                                LineMark(
                                    x: .value("Period", xDate),
                                    y: .value("MA", val)
                                )
                                .foregroundStyle(Color.orange)
                                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                                PointMark(
                                    x: .value("Period", xDate),
                                    y: .value("MA", val)
                                )
                                .foregroundStyle(Color.orange)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: data.map { $0.date }) { value in
                        AxisGridLine()
                        AxisValueLabel() {
                            if let date = value.as(Date.self) {
                                if granularity == .weekly {
                                    let initial = monthInitial(for: date)
                                    let wom = Calendar.current.component(.weekOfMonth, from: date)
                                    Text("\(initial)\(wom)")
                                } else {
                                    let initial = monthInitial(for: date)
                                    Text(initial)
                                }
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 220)
                .padding(.horizontal)
                
                HStack(spacing: 16) {
                    Toggle(isOn: $showMovingAverage) { Text("Moving average") }
                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                    if granularity == .weekly {
                        Toggle(isOn: $showFocusMix) { Text("Focus mix") }
                            .toggleStyle(SwitchToggleStyle(tint: .purple))
                    }
                    Spacer()
                    if let total = data.map({ $0.count }).reduce(0, +) as Int? {
                        Text("Total: \(total)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
            }
            
            // 12-week heatmap
            TrainingHeatmapView(trainings: trainings, weeklyTarget: weeklyTarget)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
    }
}

// Build weekly focus points aligned to specific week-start dates
private struct FocusOverlayPoint {
    let id = UUID()
    let date: Date
    let focus: TrainingFocus
    let count: Int
}

private extension TrainingTrendsView {
    func weeklyFocusPoints(weeks: [Date]) -> [FocusOverlayPoint] {
        // Map week start -> focus counts
        var map: [Date: [TrainingFocus: Int]] = [:]
        for t in trainings {
            let weekStart = Calendar.iso8601.startOfWeek(for: t.date)
            var inner = map[weekStart] ?? [:]
            inner[t.focus, default: 0] += 1
            map[weekStart] = inner
        }
        var points: [FocusOverlayPoint] = []
        for week in weeks {
            if let entries = map[week] {
                for (focus, cnt) in entries {
                    points.append(FocusOverlayPoint(date: week, focus: focus, count: cnt))
                }
            }
        }
        return points
    }
}

private extension Calendar {
    static var iso8601: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2 // Monday
        cal.minimumDaysInFirstWeek = 4
        return cal
    }
    
    func startOfWeek(for date: Date) -> Date {
        let comps = Self.iso8601.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return Self.iso8601.date(from: comps) ?? startOfDay(for: date)
    }
}

#Preview {
    struct Wrapper: View {
        @State var sample: [Training] = {
            var items: [Training] = []
            let cal = Calendar.current
            for i in 0..<40 {
                if let d = cal.date(byAdding: .day, value: -i * 2, to: Date()) {
                    items.append(Training(date: d))
                }
            }
            return items
        }()
        var body: some View {
            TrainingTrendsView(trainings: sample)
        }
    }
    return Wrapper()
}

// MARK: - Subviews

private struct MetricsRow: View {
    let currentStreakDays: Int
    let longestStreakDays: Int
    let totalMinutes: Int
    let longestSessionMinutes: Int
    let maxWeekCount: Int
    let maxMonthCount: Int
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                MetricCard(title: "Current Streak", value: "\(currentStreakDays)d", color: .green)
                MetricCard(title: "Longest Streak", value: "\(longestStreakDays)d", color: .blue)
                MetricCard(title: "Total Minutes", value: "\(totalMinutes)", color: .orange)
                MetricCard(title: "Longest Session", value: "\(longestSessionMinutes)m", color: .purple)
                MetricCard(title: "PR Week", value: "\(maxWeekCount)", color: .pink)
                MetricCard(title: "PR Month", value: "\(maxMonthCount)", color: .mint)
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.headline).foregroundColor(color)
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
}

// FocusMixChart removed; replaced by overlay in main chart

private struct TrainingHeatmapView: View {
    let trainings: [Training]
    var weeklyTarget: Int? = nil
    @State private var selectedWeek: WeekSelection?
    @State private var tooltip: TooltipData?
    
    private struct WeekSelection: Identifiable {
        let id = UUID()
        let weekStart: Date
    }
    
    private struct TooltipData: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let x: CGFloat
        let y: CGFloat
    }
    
    private func dayCountsAll() -> [Date: Int] {
        let cal = Calendar.current
        var counts: [Date: Int] = [:]
        for t in trainings {
            let d = cal.startOfDay(for: t.date)
            counts[d, default: 0] += 1
        }
        return counts
    }
    
    private func color(for count: Int) -> Color {
        switch count {
        case 0: return Color.gray.opacity(0.15)
        case 1: return Color.green.opacity(0.4)
        case 2: return Color.green.opacity(0.6)
        case 3: return Color.green.opacity(0.8)
        default: return Color.green
        }
    }
    
    private func isWeekAchieved(weekStart: Date, target: Int?) -> Bool {
        guard let target = target, target > 0 else { return false }
        let cal = Calendar.current
        let start = cal.startOfDay(for: weekStart)
        let end = cal.startOfDay(for: Calendar.iso8601.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart)
        let count = trainings.filter { $0.date >= start && $0.date <= end }.count
        return count >= target
    }
    
    var body: some View {
        let counts = dayCountsAll()
        // Determine range: from first training week to current week
        let allDays = counts.keys.sorted()
        VStack(alignment: .leading, spacing: 6) {
            Text("Training Calendar")
                .font(.headline)
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    HStack(alignment: .top, spacing: 6) {
                    // Weekday labels
                    let boxSize: CGFloat = 16
                    VStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { i in
                            let labels = ["M","T","W","T","F","S","S"]
                            Text(labels[i])
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: boxSize, height: boxSize, alignment: .center)
                        }
                    }
                    // Grid columns for each week
                    if let firstDay = allDays.first {
                        let firstWeekStart = Calendar.iso8601.startOfWeek(for: firstDay)
                        let thisWeekStart = Calendar.iso8601.startOfWeek(for: Date())
                        let weekCount = Calendar.iso8601.dateComponents([.weekOfYear], from: firstWeekStart, to: thisWeekStart).weekOfYear ?? 0
                        let totalWeeks = max(1, weekCount + 1)
                        let spacing: CGFloat = 4
                        let labelWidth: CGFloat = boxSize + 6
                        let columnWidth = boxSize
                        ScrollView(.horizontal, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 6) {
                                // Top month-week labels row
                                HStack(spacing: spacing) {
                                    ForEach(0..<totalWeeks, id: \.self) { w in
                                        if let weekStart = Calendar.iso8601.date(byAdding: .weekOfYear, value: w, to: firstWeekStart) {
                                            let monthInitial = monthInitial(for: weekStart)
                                            let weekOfMonth = Calendar.current.component(.weekOfMonth, from: weekStart)
                                            Text("\(monthInitial)\(weekOfMonth)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .frame(width: columnWidth, alignment: .center)
                                        }
                                    }
                                }
                                // Grid
                                HStack(alignment: .top, spacing: spacing) {
                                    ForEach(0..<totalWeeks, id: \.self) { w in
                                        if let weekStart = Calendar.iso8601.date(byAdding: .weekOfYear, value: w, to: firstWeekStart) {
                                            let achieved = isWeekAchieved(weekStart: weekStart, target: weeklyTarget)
                                            VStack(spacing: 4) {
                                                ForEach(0..<7, id: \.self) { offset in
                                                    if let day = Calendar.iso8601.date(byAdding: .day, value: offset, to: weekStart) {
                                                        Rectangle()
                                                            .fill(color(for: counts[day] ?? 0))
                                                            .frame(width: columnWidth, height: columnWidth)
                                                            .cornerRadius(2)
                                                            .contentShape(Rectangle())
                                                            .onTapGesture {
                                                                selectedWeek = WeekSelection(weekStart: weekStart)
                                                                    // Build tooltip near top of the tapped column
                                                                    let weekEnd = Calendar.iso8601.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
                                                                    let title = "\(weekStart.formatted(date: .abbreviated, time: .omitted)) - \(weekEnd.formatted(date: .abbreviated, time: .omitted))"
                                                                    let cal = Calendar.current
                                                                    let start = cal.startOfDay(for: weekStart)
                                                                    let end = cal.startOfDay(for: weekEnd)
                                                                    let daysCount = Set(trainings
                                                                        .filter { $0.date >= start && $0.date <= end }
                                                                        .map { cal.startOfDay(for: $0.date) }).count
                                                                    let subtitle = "Training days: \(daysCount)"
                                                                    let x = labelWidth + CGFloat(w) * (columnWidth + spacing)
                                                                    let y: CGFloat = 0
                                                                    withAnimation {
                                                                        tooltip = TooltipData(title: title, subtitle: subtitle, x: x, y: y)
                                                                    }
                                                            }
                                                    }
                                                }
                                            }
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(achieved ? Color.yellow : Color.clear, lineWidth: achieved ? 2 : 0)
                                                    .frame(width: columnWidth, height: columnWidth * 7 + 6 * 4)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        Spacer()
                    }
                    }
                    if let tip = tooltip {
                        TooltipView(title: tip.title, subtitle: tip.subtitle)
                            .offset(x: tip.x, y: tip.y)
                            .transition(.opacity)
                            .onTapGesture { withAnimation { tooltip = nil } }
                    }
                }
            }
            .frame(height: 110)
        }
        .onTapGesture { if tooltip != nil { withAnimation { tooltip = nil } } }
    }
}

private struct WeekSummaryView: View, Identifiable {
    let id = UUID()
    let weekStart: Date
    let trainings: [Training]
    
    private var weekEnd: Date {
        Calendar.iso8601.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
    }
    
    private var trainingDaysCount: Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: weekStart)
        let end = cal.startOfDay(for: weekEnd)
        let days = Set(trainings
            .filter { $0.date >= start && $0.date <= end }
            .map { cal.startOfDay(for: $0.date) })
        return days.count
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("\(weekStart.formatted(date: .abbreviated, time: .omitted)) - \(weekEnd.formatted(date: .abbreviated, time: .omitted))")
                    .font(.headline)
                Text("Training days: \(trainingDaysCount)")
                    .font(.title3)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding()
            .navigationTitle("Week Summary")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private func monthInitial(for date: Date) -> String {
    let m = Calendar.current.component(.month, from: date)
    let initials = ["", "J","F","M","A","M","J","J","A","S","O","N","D"]
    return initials.indices.contains(m) ? initials[m] : "?"
}

private struct TooltipView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.primary)
            Text(subtitle).font(.caption2).foregroundColor(.secondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}


