import SwiftUI
import SwiftData
import MapKit
import PhotosUI

struct RunDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let run: RunningSession
    
    @State private var cameraPosition: MapCameraPosition
    @State private var showingSplits = false
    @State private var selectedImageItems: [PhotosPickerItem] = []
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var isProcessingMedia = false
    @State private var showingDeleteConfirmation = false
    
    init(run: RunningSession) {
        self.run = run
        
        // Calculate map region from route
        if let firstCoord = run.routeCoordinates.first, !run.routeCoordinates.isEmpty {
            let coords = run.routeCoordinates
            let latitudes = coords.map { $0.latitude }
            let longitudes = coords.map { $0.longitude }
            
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
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Map with route (Strava-style full-width header)
                    Map(position: .constant(cameraPosition), interactionModes: []) {
                        if !run.routeCoordinates.isEmpty {
                            // Route line
                            MapPolyline(coordinates: run.routeCoordinates)
                                .stroke(.green, lineWidth: 6)
                            
                            // Start marker
                            if let start = run.routeCoordinates.first {
                                Annotation("Start", coordinate: start) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 16, height: 16)
                                            .shadow(color: .black.opacity(0.3), radius: 2)
                                        Circle()
                                            .stroke(Color.white, lineWidth: 3)
                                            .frame(width: 16, height: 16)
                                    }
                                }
                            }
                            
                            // End marker
                            if let end = run.routeCoordinates.last {
                                Annotation("Finish", coordinate: end) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 16, height: 16)
                                            .shadow(color: .black.opacity(0.3), radius: 2)
                                        Circle()
                                            .stroke(Color.white, lineWidth: 3)
                                            .frame(width: 16, height: 16)
                                    }
                                }
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .frame(height: 280)
                    
                    // Main stats section (Strava-style)
                    VStack(spacing: 0) {
                        // Primary stats - Large and prominent
                        HStack(spacing: 20) {
                            // Distance - Hero stat
                            VStack(spacing: 6) {
                                Text(String(format: "%.2f", run.distanceInKm))
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("kilometers")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            
                            Divider()
                                .frame(height: 60)
                            
                            // Duration
                            VStack(spacing: 6) {
                                Text(formatDuration(run.duration))
                                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                                Text("time")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            
                            Divider()
                                .frame(height: 60)
                            
                            // Pace
                            VStack(spacing: 6) {
                                Text(run.formattedPace)
                                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                                Text("pace")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 24)
                        .background(Color(.systemBackground))
                        
                        Divider()
                        
                        // Secondary stats grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 1) {
                            if run.calories > 0 {
                                StatTile(icon: "flame.fill", title: "Calories", value: "\(run.calories)", unit: "kcal", color: .red)
                            }
                            
                            StatTile(icon: "speedometer", title: "Avg Speed", value: String(format: "%.1f", run.averageSpeed * 3.6), unit: "km/h", color: .blue)
                            
                            if run.elevationGain > 0 {
                                StatTile(icon: "arrow.up", title: "Elevation Gain", value: String(format: "%.0f", run.elevationGain), unit: "m", color: .green)
                            }
                            
                            if run.elevationLoss > 0 {
                                StatTile(icon: "arrow.down", title: "Elevation Loss", value: String(format: "%.0f", run.elevationLoss), unit: "m", color: .orange)
                            }
                        }
                        .background(Color(.secondarySystemBackground))
                        
                        Divider()
                            .padding(.top, 12)
                        
                        mediaSection
                            .padding(.top, 16)
                    }
                    
                    // Splits section
                    if !run.splits.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Splits")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                                
                                Spacer()
                                
                                Button(action: { showingSplits.toggle() }) {
                                    Text(showingSplits ? "Hide" : "Show")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.top)
                            
                            if showingSplits {
                                VStack(spacing: 0) {
                                    // Header
                                    HStack {
                                        Text("KM")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .frame(width: 50, alignment: .leading)
                                        Text("Pace")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text("Time")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .frame(width: 70, alignment: .trailing)
                                        if run.splits.first?.elevation != nil {
                                            Text("Elev.")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .frame(width: 60, alignment: .trailing)
                                        }
                                    }
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    
                                    // Split rows
                                    ForEach(run.splits) { split in
                                        SplitDetailRow(split: split, averagePace: run.averagePace)
                                        
                                        if split.id != run.splits.last?.id {
                                            Divider()
                                                .padding(.leading)
                                        }
                                    }
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                    
                    // Date and time
                    VStack(spacing: 4) {
                        Text(run.startTime, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(run.startTime, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Run Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .onChange(of: selectedImageItems) { oldValue, newValue in
                guard !newValue.isEmpty else { return }
                Task {
                    await setProcessing(true)
                    for item in newValue {
                        await handleMediaSelection(item, type: .image)
                    }
                    await MainActor.run {
                        selectedImageItems.removeAll()
                    }
                    await setProcessing(false)
                    FirebaseSyncManager.shared.triggerFullSync()
                }
            }
            .onChange(of: selectedVideoItem) { oldValue, newValue in
                guard let item = newValue else { return }
                Task {
                    await setProcessing(true)
                    await handleMediaSelection(item, type: .video)
                    await MainActor.run {
                        selectedVideoItem = nil
                    }
                    await setProcessing(false)
                    FirebaseSyncManager.shared.triggerFullSync()
                }
            }
        }
        .alert("Delete Run?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(run)
                do {
                    try modelContext.save()
                } catch {
                    print("Failed to delete run: \(error.localizedDescription)")
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the run and its media from your history.")
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
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

// MARK: - Media Management

extension RunDetailView {
    @ViewBuilder
    fileprivate var mediaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Media")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                if isProcessingMedia {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if run.media.isEmpty {
                Text("Add photos or videos to capture highlights from this run.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(run.media) { media in
                            MediaCard(media: media) {
                                removeMedia(media)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            HStack(spacing: 16) {
                PhotosPicker(selection: $selectedImageItems, matching: .images) {
                    mediaAddButton(icon: "photo.on.rectangle.angled", title: "Add Photos")
                }
                PhotosPicker(selection: $selectedVideoItem, matching: .videos) {
                    mediaAddButton(icon: "video.fill", title: "Add Video")
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func mediaAddButton(icon: String, title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
            Text(title)
                .font(.caption)
        }
        .frame(width: 70, height: 70)
        .background(Color.blue.opacity(0.12))
        .foregroundColor(.blue)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    private func setProcessing(_ value: Bool) async {
        await MainActor.run {
            isProcessingMedia = value
        }
    }
    
    private func handleMediaSelection(_ item: PhotosPickerItem, type: MediaType) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            var newMedia: Media
            if type == .video {
                newMedia = Media(type: .video, videoData: data)
                if let thumb = try await newMedia.generateThumbnail() {
                    newMedia.thumbnailData = thumb
                }
            } else {
                newMedia = Media(type: .image, imageData: data)
            }
            await MainActor.run {
                appendMedia(newMedia)
            }
        } catch {
            print("Error handling media selection: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func appendMedia(_ media: Media) {
        media.runningSession = run
        if !run.media.contains(where: { $0.id == media.id }) {
            run.media.append(media)
        }
        modelContext.insert(media)
        do {
            try modelContext.save()
            // Upload immediately to Firebase
            Task {
                await FirebaseSyncManager.shared.uploadMediaImmediately(media: media, context: modelContext)
            }
            // Also trigger full sync to update activity feed
            FirebaseSyncManager.shared.triggerFullSync()
        } catch {
            print("Error saving media: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func removeMedia(_ media: Media) {
        if let index = run.media.firstIndex(where: { $0.id == media.id }) {
            run.media.remove(at: index)
        }
        modelContext.delete(media)
        Task {
            await FirebaseSyncManager.shared.deleteRemoteMediaIfNeeded(media: media)
        }
        do {
            try modelContext.save()
            FirebaseSyncManager.shared.triggerFullSync()
        } catch {
            print("Error removing media: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Views

struct StatTile: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
    }
}

struct SplitDetailRow: View {
    let split: Split
    let averagePace: Double
    
    var paceColor: Color {
        if split.pace < averagePace * 0.95 {
            return .green
        } else if split.pace > averagePace * 1.05 {
            return .red
        } else {
            return .primary
        }
    }
    
    var body: some View {
        HStack {
            Text("\(split.kmNumber)")
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)
                .frame(width: 50, alignment: .leading)
            
            HStack(spacing: 4) {
                Text(split.formattedPace)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(paceColor)
                
                if split.pace < averagePace * 0.95 {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if split.pace > averagePace * 1.05 {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(formatTime(split.duration))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
            
            if let elevation = split.elevation {
                HStack(spacing: 2) {
                    Image(systemName: elevation >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption)
                        .foregroundColor(elevation >= 0 ? .green : .blue)
                    Text(String(format: "%.0f", abs(elevation)))
                        .font(.caption)
                }
                .frame(width: 60, alignment: .trailing)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

