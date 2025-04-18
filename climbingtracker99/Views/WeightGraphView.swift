import SwiftUI
import Charts
import SwiftData

struct WeightGraphView: View {
    let entries: [WeightEntry]
    
    private var yAxisRange: ClosedRange<Double> {
        guard !entries.isEmpty else { return 0...100 }
        
        let weights = entries.map { $0.weight }
        let minWeight = (weights.min() ?? 0) - 1
        let maxWeight = (weights.max() ?? 0) + 1
        
        return minWeight...maxWeight
    }
    
    var body: some View {
        VStack {
            if entries.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No Data")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .frame(maxHeight: .infinity)
            } else {
                Chart {
                    ForEach(entries.sorted(by: { $0.date < $1.date })) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weight)
                        )
                        .foregroundStyle(.blue)
                        
                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weight)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .chartYScale(domain: yAxisRange)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5))
                }
                .frame(height: 200)
                .padding()
            }
        }
    }
} 