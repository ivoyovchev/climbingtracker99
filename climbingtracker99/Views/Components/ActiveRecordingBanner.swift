import SwiftUI

struct ActiveRecordingBanner: View {
    let snapshot: ActiveRecordingSnapshot
    let onResume: () -> Void
    let onCancel: () -> Void
    
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var elapsed: TimeInterval {
        max(0, now.timeIntervalSince(snapshot.startTime))
    }
    
    private var exerciseSummary: String {
        let activeCount = snapshot.activeExercises.count
        let completedCount = snapshot.completedExercises.count
        if activeCount > 0 {
            return "\(activeCount) active • \(completedCount) completed"
        } else {
            return "\(completedCount) completed"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Training in progress")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                HStack(spacing: 8) {
                    Label(formatTime(elapsed), systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if !snapshot.completedExercises.isEmpty || !snapshot.activeExercises.isEmpty {
                        Label(exerciseSummary, systemImage: "figure.climbing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            Button(action: onResume) {
                HStack(spacing: 6) {
                    Image(systemName: "play.circle.fill")
                    Text("Resume")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .onReceive(timer) { value in
            now = value
        }
        .onDisappear {
            timer.upstream.connect().cancel()
        }
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

