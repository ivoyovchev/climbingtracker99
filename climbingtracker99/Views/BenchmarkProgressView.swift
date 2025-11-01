import SwiftUI
import SwiftData
import Charts

struct BenchmarkProgressView: View {
    @Query(sort: \PlannedBenchmark.date) private var allBenchmarks: [PlannedBenchmark]
    
    private var completedBenchmarks: [PlannedBenchmark] {
        allBenchmarks.filter { $0.completed && $0.resultValue1 != nil }
    }
    
    private var benchmarksByType: [BenchmarkType: [PlannedBenchmark]] {
        Dictionary(grouping: completedBenchmarks) { $0.benchmarkType }
            .filter { $0.value.count >= 2 } // Only show types with 2+ results
    }
    
    var body: some View {
        if benchmarksByType.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 16) {
                Text("Benchmark Progress")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(benchmarksByType.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { type in
                            BenchmarkProgressCard(
                                benchmarkType: type,
                                benchmarks: benchmarksByType[type] ?? []
                            )
                            .frame(width: 280)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

struct BenchmarkProgressCard: View {
    let benchmarkType: BenchmarkType
    let benchmarks: [PlannedBenchmark]
    
    private var sortedBenchmarks: [PlannedBenchmark] {
        benchmarks.sorted(by: { $0.date < $1.date })
    }
    
    private var chartData: [(date: Date, value: Double, value2: Double?)] {
        sortedBenchmarks.compactMap { benchmark in
            guard let value1 = benchmark.resultValue1 else { return nil }
            // Use completedDate if available (actual recording date), otherwise use planned date
            let dataDate = benchmark.completedDate ?? benchmark.date
            return (date: dataDate, value: value1, value2: benchmark.resultValue2)
        }
    }
    
    private var yAxisRange: ClosedRange<Double> {
        guard !chartData.isEmpty else { return 0...100 }
        
        let allValues = chartData.flatMap { [$0.value, $0.value2].compactMap { $0 } }
        guard !allValues.isEmpty else { return 0...100 }
        
        let minValue = (allValues.min() ?? 0) * 0.9
        let maxValue = (allValues.max() ?? 0) * 1.1
        
        return max(0, minValue)...maxValue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: benchmarkType.iconName)
                    .foregroundColor(.orange)
                Text(benchmarkType.displayName)
                    .font(.headline)
                Spacer()
            }
            
            if chartData.isEmpty {
                Text("No data")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 150)
            } else {
                Chart {
                    if benchmarkType.requiresTwoHands {
                        // Show both left and right hand values
                        ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                            LineMark(
                                x: .value("Date", data.date),
                                y: .value("Value", data.value)
                            )
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)
                            
                            PointMark(
                                x: .value("Date", data.date),
                                y: .value("Value", data.value)
                            )
                            .foregroundStyle(.blue)
                            .symbolSize(60)
                            
                            if let value2 = data.value2 {
                                LineMark(
                                    x: .value("Date", data.date),
                                    y: .value("Value", value2)
                                )
                                .foregroundStyle(.red)
                                .interpolationMethod(.catmullRom)
                                
                                PointMark(
                                    x: .value("Date", data.date),
                                    y: .value("Value", value2)
                                )
                                .foregroundStyle(.red)
                                .symbolSize(60)
                            }
                        }
                    } else {
                        // Single value line
                        ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                            LineMark(
                                x: .value("Date", data.date),
                                y: .value("Value", data.value)
                            )
                            .foregroundStyle(.orange)
                            .interpolationMethod(.catmullRom)
                            
                            PointMark(
                                x: .value("Date", data.date),
                                y: .value("Value", data.value)
                            )
                            .foregroundStyle(.orange)
                            .symbolSize(60)
                        }
                    }
                }
                .chartYScale(domain: yAxisRange)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4))
                }
                .chartXAxis {
                    // Show axis marks with dates for each data point
                    AxisMarks(values: chartData.map { $0.date }) { value in
                        AxisGridLine()
                        AxisTick()
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(formatChartDate(date))
                                    .font(.caption2)
                                    .rotationEffect(.degrees(-45))
                            }
                        }
                    }
                }
                .frame(height: 200) // Increased height to accommodate rotated labels
                
                // Show latest result
                if let latest = sortedBenchmarks.last,
                   let value1 = latest.resultValue1 {
                    HStack {
                        Text("Latest: \(formatValue(value1, unit: benchmarkType.unit))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if benchmarkType.requiresTwoHands, let value2 = latest.resultValue2 {
                            Text("• R: \(formatValue(value2, unit: benchmarkType.unit))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if sortedBenchmarks.count >= 2,
                           let first = sortedBenchmarks.first,
                           let firstValue = first.resultValue1 {
                            let change = value1 - firstValue
                            let percentChange = firstValue > 0 ? (change / firstValue) * 100 : 0
                            Text(String(format: "%+.1f%%", percentChange))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(change >= 0 ? .green : .red)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func formatValue(_ value: Double, unit: String) -> String {
        if unit == "seconds" {
            return String(format: "%.0f", value) + "s"
        } else if unit == "kg" {
            return String(format: "%.1f", value) + " kg"
        } else {
            return String(format: "%.0f", value) + " " + unit
        }
    }
    
    private func formatChartDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

