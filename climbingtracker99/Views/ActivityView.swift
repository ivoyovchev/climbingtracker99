import SwiftUI
import SwiftData
import MapKit

struct ActivityView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Training.date, order: .reverse) private var trainings: [Training]
    @Query(sort: \RunningSession.startTime, order: .reverse) private var runningSessions: [RunningSession]
    
    @State private var selectedSegment: ActivitySegment = .all
    @State private var selectedTraining: Training?
    @State private var selectedRun: RunningSession?
    
    enum ActivitySegment: String, CaseIterable {
        case all = "All"
        case training = "Training"
        case running = "Running"
    }
    
    private func deleteTraining(_ training: Training) {
        withAnimation {
            modelContext.delete(training)
        }
    }
    
    private func deleteRun(_ run: RunningSession) {
        withAnimation {
            modelContext.delete(run)
        }
    }
    
    // Combine and sort all activities by date
    private var allActivities: [ActivityItem] {
        var items: [ActivityItem] = []
        
        // Add trainings
        for training in trainings {
            items.append(.training(training))
        }
        
        // Add runs
        for run in runningSessions {
            items.append(.running(run))
        }
        
        // Sort by date (most recent first)
        return items.sorted { item1, item2 in
            let date1 = item1.date
            let date2 = item2.date
            return date1 > date2
        }
    }
    
    private var filteredActivities: [ActivityItem] {
        switch selectedSegment {
        case .all:
            return allActivities
        case .training:
            return allActivities.filter { if case .training = $0 { return true }; return false }
        case .running:
            return allActivities.filter { if case .running = $0 { return true }; return false }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Segment control
                Picker("", selection: $selectedSegment) {
                    ForEach(ActivitySegment.allCases, id: \.self) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Activity list
                if filteredActivities.isEmpty {
                    EmptyActivityView(segment: selectedSegment)
                } else {
                    List {
                        ForEach(filteredActivities) { item in
                            Group {
                                switch item {
                                case .training(let training):
                                    TrainingActivityCard(training: training)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedTraining = training
                                        }
                                    
                                case .running(let run):
                                    CompactRunningCard(run: run)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedRun = run
                                        }
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    switch item {
                                    case .training(let training):
                                        deleteTraining(training)
                                    case .running(let run):
                                        deleteRun(run)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedTraining) { training in
                TrainingDetailView(training: training)
            }
            .sheet(item: $selectedRun) { run in
                RunDetailView(run: run)
            }
        }
    }
}

// MARK: - Activity Item Enum

enum ActivityItem: Identifiable {
    case training(Training)
    case running(RunningSession)
    
    var id: String {
        switch self {
        case .training(let training):
            // Use persistentModelID.hashValue for unique identification
            return "training-\(training.persistentModelID.hashValue)-\(training.date.timeIntervalSince1970)"
        case .running(let run):
            return "running-\(run.persistentModelID.hashValue)-\(run.startTime.timeIntervalSince1970)"
        }
    }
    
    var date: Date {
        switch self {
        case .training(let training):
            return training.date
        case .running(let run):
            return run.startTime
        }
    }
}

// MARK: - Empty State View

struct EmptyActivityView: View {
    let segment: ActivityView.ActivitySegment
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: segment == .running ? "figure.run" : segment == .training ? "figure.climbing" : "tray")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(segment == .running ? "No Runs Yet" : segment == .training ? "No Trainings Yet" : "No Activities Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(segment == .running ? "Start a run from the Dashboard to see it here." : segment == .training ? "Log or record a training session to see it here." : "Start tracking your activities to see them here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Training Activity Card

struct TrainingActivityCard: View {
    let training: Training
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with date and focus
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(training.date, style: .date)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(training.date, style: .time)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Focus badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(training.focus.color)
                        .frame(width: 8, height: 8)
                    Text(training.focus.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(training.focus.color)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(training.focus.color.opacity(0.15))
                .cornerRadius(12)
            }
            
            // Exercise summary
            if !training.recordedExercises.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exercises")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(training.recordedExercises.prefix(5)) { exercise in
                                ExerciseMiniCard(exercise: exercise)
                            }
                        }
                    }
                }
            }
            
            // Stats row
            HStack(spacing: 16) {
                StatBadge(icon: "clock", value: "\(training.duration)", unit: "min")
                StatBadge(icon: training.location == .indoor ? "building.2" : "tree", value: training.location.rawValue, unit: "")
                if !training.media.isEmpty {
                    StatBadge(icon: "photo.fill", value: "\(training.media.count)", unit: "")
                }
            }
            
            // Notes preview
            if !training.notes.isEmpty {
                Text(training.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Running Activity Card (Strava-style)

struct RunningActivityCard: View {
    let run: RunningSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with date
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(run.startTime, style: .date)
                        .font(.system(size: 16, weight: .semibold))
                    Text(run.startTime, style: .time)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "figure.run")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            // Main stats row (Strava-style)
            HStack(spacing: 0) {
                // Distance - Largest
                VStack(spacing: 4) {
                    Text(String(format: "%.2f", run.distanceInKm))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("km")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 40)
                
                // Duration
                VStack(spacing: 4) {
                    Text(formatTime(run.duration))
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                    Text("time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 40)
                
                // Pace
                VStack(spacing: 4) {
                    Text(run.formattedPace)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                    Text("pace")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            
            // Secondary stats
            HStack(spacing: 20) {
                if run.calories > 0 {
                    StatBadge(icon: "flame.fill", value: "\(run.calories)", unit: "kcal")
                }
                if run.elevationGain > 0 {
                    StatBadge(icon: "arrow.up", value: String(format: "%.0f", run.elevationGain), unit: "m")
                }
                if !run.splits.isEmpty {
                    StatBadge(icon: "chart.bar.fill", value: "\(run.splits.count)", unit: "km splits")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            
            // Route preview (if available)
            if !run.routeCoordinates.isEmpty {
                RoutePreview(coordinates: run.routeCoordinates)
                    .frame(height: 120)
                    .cornerRadius(0)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Compact Running Card

struct CompactRunningCard: View {
    let run: RunningSession
    
    var body: some View {
        HStack(spacing: 12) {
            // Run icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "figure.run")
                    .font(.title3)
                    .foregroundColor(.green)
            }
            
            // Main content
            VStack(alignment: .leading, spacing: 6) {
                // Date and time
                HStack {
                    Text(run.startTime, style: .date)
                        .font(.headline)
                    Spacer()
                    Text(run.startTime, style: .time)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Stats row - compact
                HStack(spacing: 16) {
                    // Distance
                    HStack(spacing: 4) {
                        Text(String(format: "%.2f", run.distanceInKm))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("km")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                        .frame(height: 20)
                    
                    // Duration
                    HStack(spacing: 4) {
                        Text(formatTime(run.duration))
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        Text("time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                        .frame(height: 20)
                    
                    // Pace
                    HStack(spacing: 4) {
                        Text(run.formattedPace)
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        Text("pace")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Secondary stats (if available)
                if run.calories > 0 || run.elevationGain > 0 {
                    HStack(spacing: 12) {
                        if run.calories > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                Text("\(run.calories) kcal")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if run.elevationGain > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                Text(String(format: "%.0f m", run.elevationGain))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Supporting Views

struct StatBadge: View {
    let icon: String
    let value: String
    let unit: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
            if !unit.isEmpty {
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ExerciseMiniCard: View {
    let exercise: RecordedExercise
    
    var body: some View {
        VStack(spacing: 4) {
            Image(exercise.exercise.type.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(exercise.exercise.type.displayName)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 60)
    }
}

struct RoutePreview: View {
    let coordinates: [CLLocationCoordinate2D]
    
    @State private var cameraPosition: MapCameraPosition
    
    init(coordinates: [CLLocationCoordinate2D]) {
        self.coordinates = coordinates
        
        // Calculate region from coordinates
        if let firstCoord = coordinates.first, !coordinates.isEmpty {
            let latitudes = coordinates.map { $0.latitude }
            let longitudes = coordinates.map { $0.longitude }
            
            let maxLat = latitudes.max() ?? firstCoord.latitude
            let minLat = latitudes.min() ?? firstCoord.latitude
            let maxLon = longitudes.max() ?? firstCoord.longitude
            let minLon = longitudes.min() ?? firstCoord.longitude
            
            let center = CLLocationCoordinate2D(
                latitude: (maxLat + minLat) / 2,
                longitude: (maxLon + minLon) / 2
            )
            
            let span = MKCoordinateSpan(
                latitudeDelta: (maxLat - minLat) * 1.3,
                longitudeDelta: (maxLon - minLon) * 1.3
            )
            
            _cameraPosition = State(initialValue: .region(MKCoordinateRegion(center: center, span: span)))
        } else {
            _cameraPosition = State(initialValue: .automatic)
        }
    }
    
    var body: some View {
        Map(position: .constant(cameraPosition), interactionModes: []) {
            if !coordinates.isEmpty {
                MapPolyline(coordinates: coordinates)
                    .stroke(.green, lineWidth: 4)
                
                // Start marker
                if let start = coordinates.first {
                    Annotation("Start", coordinate: start) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    }
                }
                
                // End marker
                if let end = coordinates.last {
                    Annotation("Finish", coordinate: end) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
    }
}

