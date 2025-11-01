import Foundation
import CoreLocation
import Combine

// Live running stats for real-time GPS tracking
struct LiveRunningStats {
    var distance: Double = 0 // meters
    var duration: TimeInterval = 0
    var currentPace: Double = 0 // min/km
    var averagePace: Double = 0 // min/km
    var lastKmPace: Double = 0 // min/km
    var speed: Double = 0 // m/s
    var calories: Int = 0
    var elevationGain: Double = 0
    var elevationLoss: Double = 0
    
    var distanceInKm: Double {
        distance / 1000.0
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var formattedDistance: String {
        String(format: "%.2f", distanceInKm)
    }
    
    func formattedPace(_ pace: Double) -> String {
        guard pace > 0 && pace < 100 else { return "--:--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var location: CLLocation?
    @Published var isTracking = false
    
    // Running session tracking
    @Published var stats = LiveRunningStats()
    private var routeLocations: [CLLocation] = []
    private var lastLocation: CLLocation?
    private var startTime: Date?
    private var timer: Timer?
    private var isPaused = false
    private var pausedDuration: TimeInterval = 0
    private var pauseStartTime: Date?
    
    // For calculating pace over last km
    private var lastKmLocations: [CLLocation] = []
    private var lastKmStartDistance: Double = 0
    
    // For elevation tracking
    private var lastAltitude: Double?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
        locationManager.distanceFilter = 5 // Update every 5 meters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestAlwaysAuthorization()
    }
    
    func startTracking() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }
        
        isTracking = true
        isPaused = false
        routeLocations.removeAll()
        lastKmLocations.removeAll()
        lastLocation = nil
        lastAltitude = nil
        lastKmStartDistance = 0
        pausedDuration = 0
        
        stats = LiveRunningStats()
        startTime = Date()
        
        locationManager.startUpdatingLocation()
        
        // Start timer for duration updates
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDuration()
        }
    }
    
    func pauseTracking() {
        guard isTracking && !isPaused else { return }
        isPaused = true
        pauseStartTime = Date()
        locationManager.stopUpdatingLocation()
    }
    
    func resumeTracking() {
        guard isTracking && isPaused else { return }
        
        if let pauseStart = pauseStartTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
        }
        
        isPaused = false
        pauseStartTime = nil
        locationManager.startUpdatingLocation()
    }
    
    func stopTracking() -> (locations: [CLLocation], stats: LiveRunningStats) {
        isTracking = false
        isPaused = false
        locationManager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil
        
        // Calculate final stats
        if let start = startTime {
            stats.duration = Date().timeIntervalSince(start) - pausedDuration
        }
        
        return (routeLocations, stats)
    }
    
    private func updateDuration() {
        guard !isPaused, let start = startTime else { return }
        stats.duration = Date().timeIntervalSince(start) - pausedDuration
    }
    
    private func calculateDistance(from: CLLocation, to: CLLocation) -> Double {
        from.distance(from: to)
    }
    
    private func calculatePace(distance: Double, duration: TimeInterval) -> Double {
        guard distance > 0 else { return 0 }
        let distanceInKm = distance / 1000.0
        let durationInMinutes = duration / 60.0
        return durationInMinutes / distanceInKm // minutes per km
    }
    
    private func updateElevation(newLocation: CLLocation) {
        guard newLocation.verticalAccuracy >= 0 && newLocation.verticalAccuracy < 50 else { return }
        
        if let lastAlt = lastAltitude {
            let elevationChange = newLocation.altitude - lastAlt
            if elevationChange > 0 {
                stats.elevationGain += elevationChange
            } else {
                stats.elevationLoss += abs(elevationChange)
            }
        }
        
        lastAltitude = newLocation.altitude
    }
    
    private func estimateCalories(distance: Double, duration: TimeInterval) -> Int {
        // Simple estimation: ~60 calories per km for running
        // This can be made more sophisticated with user weight, heart rate, etc.
        let distanceInKm = distance / 1000.0
        return Int(distanceInKm * 60)
    }
    
    func getRouteCoordinates() -> [CLLocationCoordinate2D] {
        return routeLocations.map { $0.coordinate }
    }
    
    func getSplits() -> [Split] {
        var splits: [Split] = []
        var currentKm = 1
        var kmStartIndex = 0
        var kmDistance: Double = 0
        
        guard routeLocations.count > 1 else { return splits }
        
        for i in 1..<routeLocations.count {
            let distance = routeLocations[i].distance(from: routeLocations[i-1])
            kmDistance += distance
            
            if kmDistance >= 1000 {
                // Complete km
                let kmDuration = routeLocations[i].timestamp.timeIntervalSince(routeLocations[kmStartIndex].timestamp)
                let pace = calculatePace(distance: kmDistance, duration: kmDuration)
                
                let elevationChange = routeLocations[i].altitude - routeLocations[kmStartIndex].altitude
                
                splits.append(Split(
                    kmNumber: currentKm,
                    pace: pace,
                    duration: kmDuration,
                    elevation: elevationChange
                ))
                
                currentKm += 1
                kmStartIndex = i
                kmDistance = 0
            }
        }
        
        return splits
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last, isTracking, !isPaused else { return }
        
        // Filter out inaccurate locations - but be more lenient to handle GPS signal issues
        // Allow slightly less accurate readings (up to 100m) to handle signal loss/reconnection
        guard newLocation.horizontalAccuracy >= 0 && newLocation.horizontalAccuracy < 100 else {
            print("Location accuracy too poor: \(newLocation.horizontalAccuracy)m - skipping")
            return
        }
        
        location = newLocation
        routeLocations.append(newLocation)
        
        // Calculate distance and pace
        if let last = lastLocation {
            let distance = calculateDistance(from: last, to: newLocation)
            
            // Only count significant movements (> 2 meters to filter GPS noise)
            if distance > 2 {
                stats.distance += distance
                
                // Update speed and current pace
                let timeDiff = newLocation.timestamp.timeIntervalSince(last.timestamp)
                if timeDiff > 0 {
                    stats.speed = distance / timeDiff // m/s
                    stats.currentPace = calculatePace(distance: distance, duration: timeDiff)
                }
                
                // Calculate average pace
                if stats.duration > 0 {
                    stats.averagePace = calculatePace(distance: stats.distance, duration: stats.duration)
                }
                
                // Track last km pace
                lastKmLocations.append(newLocation)
                let lastKmDistance = stats.distance - lastKmStartDistance
                
                if lastKmDistance >= 1000 {
                    // Reset for next km
                    if let firstKmLocation = lastKmLocations.first {
                        let lastKmDuration = newLocation.timestamp.timeIntervalSince(firstKmLocation.timestamp)
                        stats.lastKmPace = calculatePace(distance: lastKmDistance, duration: lastKmDuration)
                    }
                    lastKmLocations.removeAll()
                    lastKmLocations.append(newLocation)
                    lastKmStartDistance = stats.distance
                } else if lastKmLocations.count > 1 {
                    // Update running last km pace
                    if let firstKmLocation = lastKmLocations.first {
                        let lastKmDuration = newLocation.timestamp.timeIntervalSince(firstKmLocation.timestamp)
                        stats.lastKmPace = calculatePace(distance: lastKmDistance, duration: lastKmDuration)
                    }
                }
                
                // Update elevation
                updateElevation(newLocation: newLocation)
                
                // Estimate calories
                stats.calories = estimateCalories(distance: stats.distance, duration: stats.duration)
            }
        }
        
        lastLocation = newLocation
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
        
        // Handle GPS signal loss gracefully - don't crash, just pause location updates
        if let clError = error as? CLError {
            switch clError.code {
            case .locationUnknown:
                // GPS signal lost but continue tracking time
                print("GPS signal lost - continuing to track time")
                // Don't stop tracking, just mark that GPS is unavailable
                // The timer will continue to update duration
                
            case .denied:
                // User denied location permission
                if isTracking {
                    isTracking = false
                    locationManager.stopUpdatingLocation()
                }
                
            case .network:
                // Network error - try to continue
                print("Location network error - continuing")
                
            case .headingFailure:
                // Not critical for running
                break
                
            default:
                // Other errors - log but don't crash
                print("Location error: \(clError.localizedDescription)")
            }
        }
        
        // Notify that location updates have issues but continue running
        // The app should continue tracking time even without GPS
    }
}

