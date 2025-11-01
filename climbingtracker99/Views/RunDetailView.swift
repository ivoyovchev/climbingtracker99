import SwiftUI
import SwiftData
import MapKit

struct RunDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let run: RunningSession
    
    @State private var cameraPosition: MapCameraPosition
    @State private var showingSplits = false
    
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
            }
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

