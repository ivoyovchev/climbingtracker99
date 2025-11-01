import SwiftUI
import MapKit
import SwiftData

struct RunSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let session: RunningSession
    
    @State private var cameraPosition: MapCameraPosition
    @State private var showingShareSheet = false
    @State private var notes: String
    
    init(session: RunningSession) {
        self.session = session
        _notes = State(initialValue: session.notes)
        
        // Calculate map region from route
        if let firstCoord = session.routeCoordinates.first, !session.routeCoordinates.isEmpty {
            let coords = session.routeCoordinates
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
            
            let region = MKCoordinateRegion(center: center, span: span)
            _cameraPosition = State(initialValue: .region(region))
        } else {
            _cameraPosition = State(initialValue: .automatic)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Map with route
                    Map(position: $cameraPosition, interactionModes: []) {
                        if !session.routeCoordinates.isEmpty {
                            // Start marker
                            if let start = session.routeCoordinates.first {
                                Annotation("Start", coordinate: start) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 16, height: 16)
                                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                                }
                            }
                            
                            // Route line
                            MapPolyline(coordinates: session.routeCoordinates)
                                .stroke(.blue, lineWidth: 4)
                            
                            // End marker
                            if let end = session.routeCoordinates.last {
                                Annotation("Finish", coordinate: end) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 16, height: 16)
                                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                                }
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .frame(height: 300)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 5)
                    .padding(.horizontal)
                    
                    // Main stats card
                    VStack(spacing: 16) {
                        Text("Run Complete! 🎉")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 20) {
                            MainStatCard(
                                icon: "figure.run",
                                title: "Distance",
                                value: String(format: "%.2f", session.distanceInKm),
                                unit: "km",
                                color: .blue
                            )
                            
                            MainStatCard(
                                icon: "clock",
                                title: "Duration",
                                value: formatDurationComponents(session.duration).main,
                                unit: formatDurationComponents(session.duration).unit,
                                color: .green
                            )
                            
                            MainStatCard(
                                icon: "speedometer",
                                title: "Avg Pace",
                                value: formatPaceComponents(session.averagePace).main,
                                unit: formatPaceComponents(session.averagePace).unit,
                                color: .orange
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 5)
                    .padding(.horizontal)
                    
                    // Additional stats grid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Statistics")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            RunStatCard(title: "Calories", value: "\(session.calories)", unit: "kcal", icon: "flame.fill", color: .red)
                            RunStatCard(title: "Avg Speed", value: String(format: "%.1f", session.averageSpeed * 3.6), unit: "km/h", icon: "gauge.high", color: .purple)
                            RunStatCard(title: "Elevation Gain", value: String(format: "%.0f", session.elevationGain), unit: "m", icon: "arrow.up.right", color: .green)
                            RunStatCard(title: "Elevation Loss", value: String(format: "%.0f", session.elevationLoss), unit: "m", icon: "arrow.down.right", color: .blue)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Splits section
                    if !session.splits.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Splits")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                // Header
                                HStack {
                                    Text("KM")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .frame(width: 40, alignment: .leading)
                                    Text("Pace")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("Time")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .frame(width: 60, alignment: .trailing)
                                    if session.splits.first?.elevation != nil {
                                        Text("Elevation")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .frame(width: 70, alignment: .trailing)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color(.secondarySystemBackground))
                                
                                ForEach(session.splits) { split in
                                    SplitRow(split: split, averagePace: session.averagePace)
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Notes section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        TextEditor(text: $notes)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.separator), lineWidth: 1)
                            )
                            .padding(.horizontal)
                    }
                    
                    // Session info
                    VStack(spacing: 4) {
                        Text("Run completed on")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(session.endTime ?? Date(), style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(session.endTime ?? Date(), style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 20)
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        session.notes = notes
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Done")
                        }
                        .foregroundColor(.green)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }
    
    private func formatDurationComponents(_ duration: TimeInterval) -> (main: String, unit: String) {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        
        if hours > 0 {
            return ("\(hours)h \(minutes)m", "")
        } else {
            return ("\(minutes)", "min")
        }
    }
    
    private func formatPaceComponents(_ pace: Double) -> (main: String, unit: String) {
        guard pace > 0 && pace < 100 else { return ("--", "min/km") }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return (String(format: "%d:%02d", minutes, seconds), "min/km")
    }
}

// MARK: - Supporting Views

struct MainStatCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct RunStatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3)
    }
}

struct SplitRow: View {
    let split: Split
    let averagePace: Double
    
    var paceColor: Color {
        if split.pace < averagePace {
            return .green
        } else if split.pace > averagePace * 1.1 {
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
                .frame(width: 40, alignment: .leading)
            
            HStack(spacing: 4) {
                Text(split.formattedPace)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(paceColor)
                
                if split.pace < averagePace {
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
            
            Text(formatDuration(split.duration))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
            
            if let elevation = split.elevation {
                HStack(spacing: 2) {
                    Image(systemName: elevation >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption)
                        .foregroundColor(elevation >= 0 ? .green : .blue)
                    Text(String(format: "%.0f", abs(elevation)))
                        .font(.caption)
                }
                .frame(width: 70, alignment: .trailing)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

