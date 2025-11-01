import SwiftUI
import MapKit
import SwiftData
import ActivityKit

struct RunningView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    
    @State private var isPaused = false
    @State private var stopPressTimer: Timer?
    @State private var stopHoldProgress: Double = 0.0
    @State private var isHoldingStop = false
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var activityUpdateTimer: Timer?
    @State private var runStartTime: Date?
    @State private var autoSaveTimer: Timer?
    
    // Computed properties for button state
    private var buttonIcon: String {
        if locationManager.isTracking && !isPaused {
            return "pause.fill"
        } else if locationManager.isTracking && isPaused {
            return "play.fill"
        } else {
            return "play.fill"
        }
    }
    
    private var buttonText: String {
        if locationManager.isTracking && !isPaused {
            return "Pause"
        } else if locationManager.isTracking && isPaused {
            return "Resume"
        } else {
            return "Start"
        }
    }
    
    private var buttonColor: Color {
        if locationManager.isTracking && !isPaused {
            return .orange
        } else {
            return .green
        }
    }
    
    var body: some View {
        ZStack {
            // Map background
            Map(position: $cameraPosition) {
                UserAnnotation()
                
                // Draw route if exists
                if !locationManager.getRouteCoordinates().isEmpty {
                    MapPolyline(coordinates: locationManager.getRouteCoordinates())
                        .stroke(.blue, lineWidth: 4)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top stats card
                VStack(spacing: 12) {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 2)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Main stats
                    HStack(spacing: 20) {
                        StatBox(
                            title: "Distance",
                            value: locationManager.stats.formattedDistance,
                            unit: "km",
                            color: .blue
                        )
                        
                        StatBox(
                            title: "Duration",
                            value: locationManager.stats.formattedDuration,
                            unit: "",
                            color: .green
                        )
                        
                        StatBox(
                            title: "Pace",
                            value: locationManager.stats.formattedPace(locationManager.stats.averagePace),
                            unit: "min/km",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.7), Color.black.opacity(0.4)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                Spacer()
                
                // Bottom control panel
                VStack(spacing: 16) {
                    // Current pace and last km pace
                    HStack(spacing: 30) {
                        VStack(spacing: 4) {
                            Text("Current Pace")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(locationManager.stats.formattedPace(locationManager.stats.currentPace))
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("min/km")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                            .frame(height: 40)
                        
                        VStack(spacing: 4) {
                            Text("Last 1km")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(locationManager.stats.formattedPace(locationManager.stats.lastKmPace))
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("min/km")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 5)
                    
                    // Additional stats
                    HStack(spacing: 20) {
                        SmallStatBox(title: "Calories", value: "\(locationManager.stats.calories)", unit: "kcal")
                        SmallStatBox(title: "Elevation ↑", value: String(format: "%.0f", locationManager.stats.elevationGain), unit: "m")
                        SmallStatBox(title: "Elevation ↓", value: String(format: "%.0f", locationManager.stats.elevationLoss), unit: "m")
                    }
                    
                    // Control buttons - Always show Start and Stop
                    HStack(spacing: 20) {
                        // Start/Pause button
                        Button(action: handleStartPause) {
                            HStack {
                                Image(systemName: buttonIcon)
                                Text(buttonText)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(buttonColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(locationManager.isTracking && isPaused && stopHoldProgress > 0)
                        
                        // Stop button with long press
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background button
                                Button(action: {}) {
                                    HStack {
                                        Image(systemName: "stop.fill")
                                        Text(isHoldingStop ? "Hold to Stop" : "Stop")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { _ in
                                            startStopHold()
                                        }
                                        .onEnded { _ in
                                            cancelStopHold()
                                        }
                                )
                                
                                // Progress overlay
                                if isHoldingStop {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.5))
                                        .frame(width: geometry.size.width * (1.0 - stopHoldProgress))
                                        .animation(.linear(duration: 0.05), value: stopHoldProgress)
                                }
                            }
                        }
                        .frame(height: 50)
                        .disabled(!locationManager.isTracking || isPaused)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .shadow(color: .black.opacity(0.2), radius: 10)
            }
        }
        .onAppear {
            locationManager.requestPermission()
        }
        .onDisappear {
            cancelStopHold()
            stopActivityUpdateTimer()
            // Don't stop Live Activity or auto-save here - let them continue if run is still active
            // This allows the run to continue even if user backgrounds the app
        }
    }
    
    private func handleStartPause() {
        if !locationManager.isTracking {
            // Start tracking
            let startTime = Date()
            runStartTime = startTime
            locationManager.startTracking()
            isPaused = false
            
            // Start Live Activity if available
            if #available(iOS 16.1, *) {
                RunningActivityManager.shared.startActivity(startTime: startTime)
                startActivityUpdateTimer()
            }
            
            // Start periodic auto-save (every 30 seconds) to prevent data loss
            startAutoSave()
        } else if isPaused {
            // Resume tracking
            locationManager.resumeTracking()
            isPaused = false
            
            // Resume Live Activity updates
            if #available(iOS 16.1, *) {
                startActivityUpdateTimer()
                updateLiveActivity()
            }
        } else {
            // Pause tracking
            locationManager.pauseTracking()
            isPaused = true
            
            // Pause Live Activity updates
            stopActivityUpdateTimer()
            if #available(iOS 16.1, *) {
                updateLiveActivity()
            }
        }
    }
    
    private func startStopHold() {
        guard locationManager.isTracking && !isPaused else { return }
        
        if !isHoldingStop {
            isHoldingStop = true
            stopHoldProgress = 0.0
            
            // Start timer for 3 seconds
            let totalDuration: TimeInterval = 3.0
            let updateInterval: TimeInterval = 0.05 // Update every 50ms for smooth animation
            
            stopPressTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { timer in
                stopHoldProgress += updateInterval / totalDuration
                
                if stopHoldProgress >= 1.0 {
                    timer.invalidate()
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    stopRun()
                }
            }
        }
    }
    
    private func cancelStopHold() {
        stopPressTimer?.invalidate()
        stopPressTimer = nil
        isHoldingStop = false
        stopHoldProgress = 0.0
    }
    
    private func stopRun() {
        cancelStopHold()
        stopActivityUpdateTimer()
        stopAutoSave()
        
        // Stop Live Activity
        if #available(iOS 16.1, *) {
            RunningActivityManager.shared.stopActivity()
        }
        
        // Ensure we have valid data before saving
        let stats = locationManager.stats
        guard stats.duration > 0 else {
            print("Invalid duration - cannot save run")
            dismiss()
            return
        }
        
        // Save final run
        saveRunFinal()
        
        // Dismiss back to main app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
    
    private func startActivityUpdateTimer() {
        stopActivityUpdateTimer() // Stop any existing timer
        
        activityUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateLiveActivity()
        }
        if let timer = activityUpdateTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopActivityUpdateTimer() {
        activityUpdateTimer?.invalidate()
        activityUpdateTimer = nil
    }
    
    private func updateLiveActivity() {
        guard #available(iOS 16.1, *) else { return }
        
        let stats = locationManager.stats
        RunningActivityManager.shared.updateActivity(
            distance: stats.distanceInKm,
            duration: stats.duration,
            averagePace: stats.averagePace,
            currentPace: stats.currentPace,
            calories: stats.calories,
            isPaused: isPaused
        )
    }
    
    // Periodic auto-save to prevent data loss on crash
    private func startAutoSave() {
        stopAutoSave() // Stop any existing timer
        
        // Auto-save every 30 seconds to UserDefaults as backup
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            saveRunProgressToUserDefaults()
        }
        if let timer = autoSaveTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }
    
    private func saveRunProgressToUserDefaults() {
        guard let startTime = runStartTime else { return }
        
        let stats = locationManager.stats
        let locations = locationManager.getRouteCoordinates()
        
        // Save partial run data to UserDefaults as backup
        let runBackup: [String: Any] = [
            "startTime": startTime.timeIntervalSince1970,
            "distance": stats.distance,
            "duration": stats.duration,
            "averagePace": stats.averagePace,
            "calories": stats.calories,
            "elevationGain": stats.elevationGain,
            "elevationLoss": stats.elevationLoss,
            "locationCount": locations.count,
            "isPaused": isPaused
        ]
        
        UserDefaults.standard.set(runBackup, forKey: "runningSessionBackup")
        UserDefaults.standard.synchronize()
        print("Run progress auto-saved")
    }
    
    // Save final run data
    private func saveRunFinal() {
        guard let startTime = runStartTime else { return }
        
        let (locations, finalStats) = locationManager.stopTracking()
        
        // Clear backup after successful save
        UserDefaults.standard.removeObject(forKey: "runningSessionBackup")
        
        // Save running session
        let session = RunningSession(
            startTime: startTime,
            endTime: Date(),
            duration: finalStats.duration,
            distance: finalStats.distance,
            averagePace: finalStats.averagePace,
            calories: finalStats.calories,
            elevationGain: finalStats.elevationGain,
            elevationLoss: finalStats.elevationLoss,
            maxSpeed: finalStats.speed,
            averageSpeed: finalStats.duration > 0 ? finalStats.distance / finalStats.duration : 0
        )
        
        session.routeCoordinates = locations.map { $0.coordinate }
        session.splits = locationManager.getSplits()
        
        // Add note if GPS data is incomplete
        if locations.isEmpty {
            session.notes = "Note: GPS signal was lost during this run. Time tracked: \(finalStats.formattedDuration)."
        } else if locations.count < 10 {
            session.notes = "Note: Limited GPS data recorded (\(locations.count) points)."
        }
        
        do {
            modelContext.insert(session)
            try modelContext.save()
            print("Run saved successfully")
        } catch {
            print("Error saving run: \(error.localizedDescription)")
            // If save fails, restore backup to UserDefaults for recovery
            let runBackup: [String: Any] = [
                "startTime": startTime.timeIntervalSince1970,
                "distance": finalStats.distance,
                "duration": finalStats.duration,
                "averagePace": finalStats.averagePace,
                "calories": finalStats.calories,
                "elevationGain": finalStats.elevationGain,
                "elevationLoss": finalStats.elevationLoss,
                "locationCount": locations.count,
                "isPaused": false
            ]
            UserDefaults.standard.set(runBackup, forKey: "runningSessionBackup")
            UserDefaults.standard.set(true, forKey: "hasUnrecoveredRun")
        }
    }
}

// MARK: - Supporting Views

struct StatBox: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(unit)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.3))
        .cornerRadius(12)
    }
}

struct SmallStatBox: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            HStack(spacing: 2) {
                Text(value)
                    .font(.footnote)
                    .fontWeight(.semibold)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// Helper extension for custom corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

