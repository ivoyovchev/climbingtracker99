import SwiftUI
import SwiftData
import Charts

enum TrendsGranularity: String, CaseIterable {
    case weekly = "Weekly"
    case monthly = "Monthly"
}

struct TrainingTrendsView: View {
    let trainings: [Training]
    let runs: [RunningSession]
    var weeklyTarget: Int? = nil
    @State private var granularity: TrendsGranularity = .weekly
    @State private var showMovingAverage: Bool = true
    @State private var showFocusMix: Bool = false
    
    // MARK: - Metrics
    private var totalMinutes: Int {
        let trainingMinutes = trainings.map { $0.duration }.reduce(0, +)
        let runMinutes = runs.map { Int($0.duration / 60.0) }.reduce(0, +)
        return trainingMinutes + runMinutes
    }
    
    private var longestSessionMinutes: Int {
        let trainingMax = trainings.map { $0.duration }.max() ?? 0
        let runMax = runs.map { Int($0.duration / 60.0) }.max() ?? 0
        return max(trainingMax, runMax)
    }
    
    private var allSessionDays: [Date] {
        let cal = Calendar.current
        let trainingDays = trainings.map { cal.startOfDay(for: $0.date) }
        let runDays = runs.map { cal.startOfDay(for: $0.startTime) }
        return trainingDays + runDays
    }

    private var currentStreakDays: Int {
        // Count consecutive days ending today (or yesterday if no training today)
        let cal = Calendar.current
        let daySet = Set(allSessionDays)
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
        let days = allSessionDays.sorted()
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
        weeklyBuckets(last: 256).map { $0.totalCount }.max() ?? 0
    }
    
    private var maxWorkoutsInAMonth: Int {
        monthlyBuckets(last: 256).map { $0.totalCount }.max() ?? 0
    }
    
    // MARK: - Aggregation

    private struct PeriodData {
        let date: Date
        let trainingCount: Int
        let runCount: Int
        var totalCount: Int { trainingCount + runCount }
    }

    private struct IndexedPeriod {
        let index: Int
        let period: PeriodData
    }

    private func weeklyBuckets(last n: Int = 12) -> [PeriodData] {
        var grouped: [Date: (training: Int, run: Int)] = [:]
        for training in trainings {
            let weekStart = Calendar.iso8601.startOfWeek(for: training.date)
            var counts = grouped[weekStart] ?? (0, 0)
            counts.training += 1
            grouped[weekStart] = counts
        }
        for run in runs {
            let weekStart = Calendar.iso8601.startOfWeek(for: run.startTime)
            var counts = grouped[weekStart] ?? (0, 0)
            counts.run += 1
            grouped[weekStart] = counts
        }
        let sortedKeys = grouped.keys.sorted()
        let periods = sortedKeys.map { key in
            let counts = grouped[key] ?? (0, 0)
            return PeriodData(date: key, trainingCount: counts.training, runCount: counts.run)
        }
        return Array(periods.suffix(n))
    }

    private func monthlyBuckets(last n: Int = 12) -> [PeriodData] {
        func startOfMonth(for date: Date) -> Date {
            let comps = Calendar.current.dateComponents([.year, .month], from: date)
            return Calendar.current.date(from: comps) ?? date
        }
        var grouped: [Date: (training: Int, run: Int)] = [:]
        for training in trainings {
            let monthStart = startOfMonth(for: training.date)
            var counts = grouped[monthStart] ?? (0, 0)
            counts.training += 1
            grouped[monthStart] = counts
        }
        for run in runs {
            let monthStart = startOfMonth(for: run.startTime)
            var counts = grouped[monthStart] ?? (0, 0)
            counts.run += 1
            grouped[monthStart] = counts
        }
        let sortedKeys = grouped.keys.sorted()
        let periods = sortedKeys.map { key in
            let counts = grouped[key] ?? (0, 0)
            return PeriodData(date: key, trainingCount: counts.training, runCount: counts.run)
        }
        return Array(periods.suffix(n))
    }

    private func periods(for granularity: TrendsGranularity) -> [PeriodData] {
        switch granularity {
        case .weekly:
            return weeklyBuckets(last: 16)
        case .monthly:
            return monthlyBuckets(last: 12)
        }
    }

    private func movingAverageSeries(indexedPeriods: [IndexedPeriod], granularity: TrendsGranularity) -> [(index: Int, value: Double)] {
        let counts = indexedPeriods.map { $0.period.totalCount }
        let window = granularity == .weekly ? 4 : 3
        let values = movingAverage(values: counts, window: window)
        guard values.count > 0 else { return [] }
        return values.enumerated().map { idx, value in
            let periodIdx = idx + max(0, window - 1)
            let clampedIdx = min(periodIdx, indexedPeriods.count - 1)
            return (index: indexedPeriods[clampedIdx].index, value: value)
        }
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
            
            let periods = periods(for: granularity)
            let indexedPeriods = periods.enumerated().map { IndexedPeriod(index: $0.offset, period: $0.element) }
            let shouldShowFocusMix = granularity == .weekly && showFocusMix
            let activityPoints = shouldShowFocusMix ? weeklyActivityPoints(indexedPeriods: indexedPeriods) : []
            let movingAverageValues = showMovingAverage ? movingAverageSeries(indexedPeriods: indexedPeriods, granularity: granularity) : []
            let focusStyleScale: KeyValuePairs<String, Color> = shouldShowFocusMix ? [
                ActivityCategory.training.rawValue: Color.blue.opacity(0.75),
                ActivityCategory.run.rawValue: Color.green.opacity(0.75)
            ] : [:]
            
            if periods.isEmpty {
                Text("No training data yet")
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                Chart {
                    barContent(indexedPeriods: indexedPeriods, shouldShowFocusMix: shouldShowFocusMix, activityPoints: activityPoints)
                    movingAverageContent(entries: movingAverageValues)
                }
                .chartForegroundStyleScale(focusStyleScale)
                .chartXAxis {
                    let values = indexedPeriods.map { Double($0.index) }
                    AxisMarks(values: values) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                let idx = Int(doubleValue.rounded())
                                if let period = indexedPeriods.first(where: { $0.index == idx }) {
                                    Text(periodLabel(for: period.period, granularity: granularity))
                                }
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXScale(domain: xDomain(for: indexedPeriods))
                .chartPlotStyle { plotArea in
                    plotArea.frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 220)
                .padding(.horizontal)
                
                let totalCount = periods.map { $0.totalCount }.reduce(0, +)
                HStack(spacing: 16) {
                    Toggle(isOn: $showMovingAverage) { Text("Avg.") }
                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                    if granularity == .weekly {
                        Toggle(isOn: $showFocusMix) {
                            Text("Details")
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                    }
                    Spacer()
                    Text("Total: \(totalCount)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            
            // 12-week heatmap
            TrainingHeatmapView(trainings: trainings, runs: runs, weeklyTarget: weeklyTarget)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
    }
}

// Build weekly activity points aligned to specific week-start dates
private enum ActivityCategory: String, CaseIterable {
    case training = "Training"
    case run = "Runs"
}

private struct ActivityPoint {
    let id = UUID()
    let index: Int
    let date: Date
    let category: ActivityCategory
    let count: Int
}

private extension TrainingTrendsView {
    var currentWeekCounts: (training: Int, runs: Int) {
        let cal = Calendar.iso8601
        let start = cal.startOfWeek(for: Date())
        let end = cal.date(byAdding: .day, value: 7, to: start) ?? start
        let trainingCount = trainings.filter { $0.date >= start && $0.date < end }.count
        let runCount = runs.filter { $0.startTime >= start && $0.startTime < end }.count
        return (trainingCount, runCount)
    }
    
    private func weeklyActivityPoints(indexedPeriods: [IndexedPeriod]) -> [ActivityPoint] {
        indexedPeriods.flatMap { item -> [ActivityPoint] in
            var points: [ActivityPoint] = []
            if item.period.trainingCount > 0 {
                points.append(ActivityPoint(index: item.index, date: item.period.date, category: .training, count: item.period.trainingCount))
            }
            if item.period.runCount > 0 {
                points.append(ActivityPoint(index: item.index, date: item.period.date, category: .run, count: item.period.runCount))
            }
            return points
        }
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
        @State var sampleRuns: [RunningSession] = {
            var runs: [RunningSession] = []
            let cal = Calendar.current
            for i in 0..<12 {
                if let d = cal.date(byAdding: .day, value: -i * 5, to: Date()) {
                    let session = RunningSession(startTime: d, duration: 45 * 60, distance: 8000)
                    runs.append(session)
                }
            }
            return runs
        }()
        var body: some View {
            TrainingTrendsView(trainings: sample, runs: sampleRuns)
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
    let runs: [RunningSession]
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
        for run in runs {
            let d = cal.startOfDay(for: run.startTime)
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
        let end = cal.startOfDay(for: Calendar.iso8601.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart)
        let trainingCount = trainings.filter { $0.date >= start && $0.date < end }.count
        let runCount = runs.filter { $0.startTime >= start && $0.startTime < end }.count
        let count = trainingCount + runCount
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
                        Spacer()
                            .frame(height: boxSize + 6)
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
                                                                    let end = cal.date(byAdding: .day, value: 7, to: start) ?? start
                                                                    let trainingDays = trainings
                                                                        .filter { $0.date >= start && $0.date < end }
                                                                        .map { cal.startOfDay(for: $0.date) }
                                                                    let runDays = runs
                                                                        .filter { $0.startTime >= start && $0.startTime < end }
                                                                        .map { cal.startOfDay(for: $0.startTime) }
                                                                    let daysCount = Set(trainingDays + runDays).count
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

private extension TrainingTrendsView {
    @ChartContentBuilder
    private func barContent(indexedPeriods: [IndexedPeriod], shouldShowFocusMix: Bool, activityPoints: [ActivityPoint]) -> some ChartContent {
        if shouldShowFocusMix {
            ForEach(activityPoints, id: \.id) { point in
                BarMark(
                    x: .value("Week", Double(point.index)),
                    y: .value("Count", point.count)
                )
                .position(by: .value("Type", point.category.rawValue))
                .foregroundStyle(by: .value("Type", point.category.rawValue))
            }
        } else {
            ForEach(indexedPeriods, id: \.index) { item in
                BarMark(
                    x: .value("Period", Double(item.index)),
                    y: .value("Workouts", item.period.totalCount)
                )
                .foregroundStyle(Color.blue.opacity(0.7))
            }
        }
    }
    
    @ChartContentBuilder
    private func movingAverageContent(entries: [(index: Int, value: Double)]) -> some ChartContent {
        ForEach(entries, id: \.index) { entry in
            LineMark(
                x: .value("Period", Double(entry.index)),
                y: .value("MA", entry.value)
            )
            .foregroundStyle(Color.orange)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            PointMark(
                x: .value("Period", Double(entry.index)),
                y: .value("MA", entry.value)
            )
            .foregroundStyle(Color.orange)
            .symbolSize(32)
        }
    }
    
    private func periodLabel(for period: PeriodData, granularity: TrendsGranularity) -> String {
        switch granularity {
        case .weekly:
            let initial = monthInitial(for: period.date)
            let wom = Calendar.current.component(.weekOfMonth, from: period.date)
            return "\(initial)\(wom)"
        case .monthly:
            return monthInitial(for: period.date)
        }
    }
    
    private func xDomain(for indexedPeriods: [IndexedPeriod]) -> ClosedRange<Double> {
        guard let last = indexedPeriods.last else {
            return -0.5...0.5
        }
        let upper = Double(last.index) + 0.5
        return -0.5...upper
    }
}


