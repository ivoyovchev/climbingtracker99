import SwiftUI

struct StatsRowView: View {
    let trainings: [Training]
    
    private var totalDuration: Int {
        trainings.reduce(0) { $0 + $1.duration }
    }
    
    private var averageDuration: Int {
        guard !trainings.isEmpty else { return 0 }
        return totalDuration / trainings.count
    }
    
    private var totalExercises: Int {
        trainings.reduce(0) { $0 + $1.recordedExercises.count }
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                StatCard(
                    title: "Total Time",
                    value: "\(totalDuration) min",
                    icon: "clock",
                    color: .blue
                )
                
                StatCard(
                    title: "Avg Duration",
                    value: "\(averageDuration) min",
                    icon: "timer",
                    color: .blue
                )
                
                StatCard(
                    title: "Exercises",
                    value: "\(totalExercises)",
                    icon: "figure.climbing",
                    color: .blue
                )
            }
            .padding(.horizontal)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 100, height: 100)
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(15)
    }
} 