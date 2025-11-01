import SwiftUI
import SwiftData

struct UpcomingBenchmarksView: View {
    let benchmarks: [PlannedBenchmark]
    
    private var upcomingBenchmarks: [PlannedBenchmark] {
        let now = Date()
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 30, to: now)!
        
        return benchmarks
            .filter { !$0.completed && $0.date >= now && $0.date <= endDate }
            .sorted { $0.date < $1.date }
            .prefix(5)
            .map { $0 }
    }
    
    private var groupedByDate: [Date: [PlannedBenchmark]] {
        let calendar = Calendar.current
        return Dictionary(grouping: upcomingBenchmarks) { benchmark in
            calendar.startOfDay(for: benchmark.date)
        }
    }
    
    var body: some View {
        if !upcomingBenchmarks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Upcoming Benchmarks")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.horizontal)
                
                VStack(spacing: 8) {
                    ForEach(Array(groupedByDate.keys.sorted()), id: \.self) { date in
                        if let benchmarksForDate = groupedByDate[date] {
                            BenchmarkDateCard(date: date, benchmarks: benchmarksForDate)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

struct BenchmarkDateCard: View {
    let date: Date
    let benchmarks: [PlannedBenchmark]
    
    private let calendar = Calendar.current
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if calendar.isDateInToday(date) {
                    Text("Today")
                        .font(.headline)
                        .foregroundColor(.orange)
                } else if calendar.isDateInTomorrow(date) {
                    Text("Tomorrow")
                        .font(.headline)
                        .foregroundColor(.orange)
                } else {
                    Text(dateFormatter.string(from: date))
                        .font(.headline)
                }
                Spacer()
            }
            
            ForEach(benchmarks, id: \.persistentModelID) { benchmark in
                HStack(spacing: 12) {
                    Image(systemName: benchmark.benchmarkType.iconName)
                        .font(.body)
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(benchmark.benchmarkType.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 8) {
                            Label(timeFormatter.string(from: benchmark.estimatedTimeOfDay), systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

