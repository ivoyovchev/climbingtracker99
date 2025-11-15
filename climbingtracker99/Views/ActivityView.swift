import SwiftUI
import SwiftData
import MapKit
import FirebaseFirestore
import AVKit

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
        NavigationStack {
            VStack {
                Picker("", selection: $selectedSegment) {
                    ForEach(ActivitySegment.allCases, id: \.self) { segment in
                        Text(segment.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 12)
                
                let activities = filteredActivities
                if activities.isEmpty {
                    Spacer()
                    EmptyActivityView(segment: selectedSegment)
                        .padding(.horizontal)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(activities) { item in
                                switch item {
                                case .training(let training):
                                    TrainingActivityCard(training: training)
                                        .padding(.horizontal, 16)
                                        .onTapGesture {
                                            selectedTraining = training
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                deleteTraining(training)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                case .running(let run):
                                    RunningActivityCard(run: run)
                                        .padding(.horizontal, 16)
                                        .onTapGesture {
                                            selectedRun = run
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                deleteRun(run)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .background(Color(.systemGroupedBackground))
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
    var author: FirebaseActivityItem? = nil
    
    private var exerciseCount: Int { training.recordedExercises.count }
    private var focusLabel: String { training.focus.rawValue.uppercased() }
    private var isRecordedLabel: String { training.isRecorded ? "Recorded" : "Logged" }
    private var focusColor: Color { training.focus.color }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Author header (if present)
            if let author {
                authorHeader(for: author)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    .background(Color(.systemBackground))
                }
                
            // Header with date
                    HStack {
                VStack(alignment: .leading, spacing: 2) {
                        Text(training.date, style: .date)
                        .font(.system(size: 16, weight: .semibold))
                        Text(training.date, style: .time)
                        .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                Spacer()
                
                Image(systemName: "figure.climbing")
                    .font(.title2)
                    .foregroundColor(focusColor)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            
            // Main stats row (Strava-style)
            HStack(spacing: 0) {
                // Duration - Largest
                VStack(spacing: 4) {
                            Text("\(training.duration)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                            Text("min")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                .frame(maxWidth: .infinity)
                        
                Divider()
                    .frame(height: 40)
                        
                // Exercise count
                VStack(spacing: 4) {
                            Text("\(max(exerciseCount, 0))")
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                            Text(exerciseCount == 1 ? "exercise" : "exercises")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                .frame(maxWidth: .infinity)
                        
                Divider()
                    .frame(height: 40)
                        
                // Focus
                VStack(spacing: 4) {
                            Text(focusLabel)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("focus")
                        .font(.caption)
                                .foregroundColor(.secondary)
                        }
                .frame(maxWidth: .infinity)
                    }
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
                    
            // Secondary stats
            HStack(spacing: 20) {
                        StatBadge(icon: training.location == .indoor ? "building.2" : "tree",
                                  value: training.location.rawValue,
                                  unit: "")
                        StatBadge(icon: "dot.radiowaves.left.and.right",
                                  value: isRecordedLabel,
                                  unit: "")
                        if !training.media.isEmpty {
                            StatBadge(icon: "photo.fill", value: "\(training.media.count)", unit: "")
                        }
                    }
            .padding(.horizontal)
            .padding(.bottom, 8)
                    
            // Notes (if available)
                    if !training.notes.isEmpty {
                        Text(training.notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    .padding(.horizontal)
                    .padding(.bottom, training.media.isEmpty ? 8 : 0)
            }

            // Media gallery
            if !training.media.isEmpty {
                if let remoteItems = RemoteMediaItem.items(from: training.media), !remoteItems.isEmpty {
                    RemoteMediaGallery(items: remoteItems)
                        .padding(8)
                } else {
                    TrainingMediaGallery(media: training.media)
                        .padding(8)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(focusColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func authorHeader(for author: FirebaseActivityItem) -> some View {
        HStack(alignment: .center, spacing: 8) {
            ProfileAvatarView(imageData: author.profileImageData, displayName: author.displayName)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(author.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                if !author.username.isEmpty {
                    Text("@\(author.username)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
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
            .padding(.vertical, 8)
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
            .padding(.vertical, 12)
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
            .padding(.bottom, 8)
            
            // Route preview (if available)
            if !run.routeCoordinates.isEmpty {
                RoutePreview(coordinates: run.routeCoordinates)
                    .frame(height: 120)
                    .cornerRadius(0)
            }
            
            // Media gallery
            if !run.media.isEmpty {
                if let remoteItems = RemoteMediaItem.items(from: run.media), !remoteItems.isEmpty {
                    RemoteMediaGallery(items: remoteItems)
                        .padding(8)
                } else {
                    TrainingMediaGallery(media: run.media)
                        .padding(8)
                }
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
    var author: FirebaseActivityItem? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let author {
                authorHeader(for: author)
            }
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 50, height: 50)
                    Image(systemName: "figure.run")
                        .font(.title3)
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(run.startTime, style: .date)
                            .font(.headline)
                        Spacer()
                        Text(run.startTime, style: .time)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Text(String(format: "%.2f", run.distanceInKm))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Text("km")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider().frame(height: 20)
                        
                        HStack(spacing: 4) {
                            Text(formatTime(run.duration))
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            Text("time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider().frame(height: 20)
                        
                        HStack(spacing: 4) {
                            Text(run.formattedPace)
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            Text("pace")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
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
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !run.media.isEmpty {
                if let remoteItems = RemoteMediaItem.items(from: run.media), !remoteItems.isEmpty {
                    RemoteMediaGallery(items: remoteItems)
                } else {
                    TrainingMediaGallery(media: run.media)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: Color.green.opacity(0.15), radius: 12, x: 0, y: 6)
    }
    
    private func authorHeader(for author: FirebaseActivityItem) -> some View {
        HStack(alignment: .center, spacing: 8) {
            ProfileAvatarView(imageData: author.profileImageData, displayName: author.displayName)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(author.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                if !author.username.isEmpty {
                    Text("@\(author.username)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
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

struct TrainingMediaGallery: View {
    let media: [Media]
    @State private var selectedMedia: Media?
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        if media.isEmpty {
            EmptyView()
        } else {
            TabView {
                ForEach(Array(media.enumerated()), id: \.element.id) { index, item in
                    ZStack {
                        TrainingMediaContent(media: item)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(Color.black.opacity(item.type == .video ? 0.15 : 0.05))
                            .overlay(alignment: .center) {
                                if item.type == .video {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(.white)
                                        .shadow(radius: 8)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedMedia = item
                            }
                            .overlay(alignment: .bottomTrailing) {
                                Text("\(index + 1)/\(media.count)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .padding(12)
                            }
                            .overlay(alignment: .topLeading) {
                                // Upload status indicator
                                uploadStatusBadge(for: item)
                                    .padding(12)
                            }
                    }
                }
            }
            .frame(height: 240)
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.35)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .allowsHitTesting(false)
            )
            .padding(.top, 8)
            .sheet(item: $selectedMedia) { media in
                if let remoteItem = RemoteMediaItem(media: media) {
                    RemoteMediaViewer(item: remoteItem)
                } else {
                    MediaFullView(media: media)
                }
            }
        }
    }
    
    @ViewBuilder
    private func uploadStatusBadge(for media: Media) -> some View {
        switch media.uploadStateEnum {
        case .uploading:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(.white)
                if let progress = media.uploadProgress {
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
            .padding(6)
            .background(Color.blue.opacity(0.85))
            .clipShape(Capsule())
        case .uploaded:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(6)
                .background(Color.green.opacity(0.85))
                .clipShape(Circle())
        case .failed:
            Button {
                Task {
                    await FirebaseSyncManager.shared.retryMediaUpload(media: media, context: modelContext)
                }
            } label: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.red.opacity(0.85))
                    .clipShape(Circle())
            }
        case .pending:
            if !media.isUploaded {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.orange.opacity(0.85))
                    .clipShape(Circle())
            }
        }
    }
}

private extension RemoteMediaItem {
    init?(media: Media) {
        guard let remote = media.remoteURL else { return nil }
        
        self.id = media.id.uuidString
        self.type = media.type
        
        // Check if it's base64 or URL
        if remote.hasPrefix("base64:") {
            let base64String = String(remote.dropFirst(7))
            self.base64 = base64String
            self.url = nil
        } else if let url = URL(string: remote) {
        self.url = url
            self.base64 = nil
        } else {
            return nil
        }
        
        // Handle thumbnail
        if let thumbString = media.remoteThumbnailURL {
            if thumbString.hasPrefix("base64:") {
                self.thumbnailBase64 = String(thumbString.dropFirst(7))
                self.thumbnailURL = nil
            } else if let thumbURL = URL(string: thumbString) {
            self.thumbnailURL = thumbURL
                self.thumbnailBase64 = nil
        } else {
            self.thumbnailURL = nil
                self.thumbnailBase64 = nil
            }
        } else {
            self.thumbnailURL = nil
            self.thumbnailBase64 = nil
        }
    }
    
    static func items(from media: [Media]) -> [RemoteMediaItem]? {
        let converted = media.compactMap { RemoteMediaItem(media: $0) }
        return converted.isEmpty ? nil : converted
    }
}

private struct TrainingMediaContent: View {
    let media: Media
    
    var body: some View {
        Group {
            if let image = media.image {
                image
                    .resizable()
                    .scaledToFill()
            } else if let thumbnail = media.thumbnail {
                thumbnail
                    .resizable()
                    .scaledToFill()
            } else if let remote = media.remoteURL {
                // Check for base64 first
                if remote.hasPrefix("base64:") {
                    let base64String = String(remote.dropFirst(7))
                    if let data = Data(base64Encoded: base64String), let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        placeholder
                    }
                } else if let remoteThumb = media.remoteThumbnailURL {
                    // Check thumbnail for base64
                    if remoteThumb.hasPrefix("base64:") {
                        let base64String = String(remoteThumb.dropFirst(7))
                        if let data = Data(base64Encoded: base64String), let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            placeholder
                        }
                    } else if let url = URL(string: remoteThumb) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        ZStack {
                            Color.gray.opacity(0.1)
                            ProgressView()
                        }
                    @unknown default:
                        placeholder
                    }
                }
                    } else {
                        placeholder
                    }
                } else if let url = URL(string: remote) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        ZStack {
                            Color.gray.opacity(0.1)
                            ProgressView()
                        }
                    @unknown default:
                        placeholder
                    }
                    }
                } else {
                    placeholder
                }
            } else {
                placeholder
            }
        }
    }
    
    private var placeholder: some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: media.type == .video ? "video.fill" : "photo")
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

