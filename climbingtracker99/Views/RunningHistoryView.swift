import SwiftUI
import SwiftData

struct RunningHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RunningSession.startTime, order: .reverse) private var runningSessions: [RunningSession]
    @State private var selectedSession: RunningSession?
    @State private var showingDetail = false
    
    var body: some View {
        NavigationView {
            Group {
                if runningSessions.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "figure.run.circle")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        
                        Text("No Running Sessions Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Start your first run from the Dashboard!")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    List {
                        ForEach(runningSessions) { session in
                            RunningSessionRow(session: session)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedSession = session
                                    showingDetail = true
                                }
                        }
                        .onDelete(perform: deleteSessions)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Running History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !runningSessions.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingDetail) {
                if let session = selectedSession {
                    RunSummaryView(session: session)
                }
            }
        }
    }
    
    private func deleteSessions(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(runningSessions[index])
            }
        }
    }
}

struct RunningSessionRow: View {
    let session: RunningSession
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "figure.run")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
            }
            
            // Session details
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(session.startTime, style: .date)
                        .font(.headline)
                    Spacer()
                    Text(session.startTime, style: .time)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 16) {
                    // Distance
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(String(format: "%.2f km", session.distanceInKm))
                            .font(.subheadline)
                    }
                    
                    // Duration
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text(session.formattedDuration)
                            .font(.subheadline)
                    }
                    
                    // Pace
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(session.formattedPace)
                            .font(.subheadline)
                    }
                }
                
                // Calories and elevation
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                        Text("\(session.calories) kcal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if session.elevationGain > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text(String(format: "%.0f m", session.elevationGain))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    RunningHistoryView()
        .modelContainer(for: [RunningSession.self], inMemory: true)
}

