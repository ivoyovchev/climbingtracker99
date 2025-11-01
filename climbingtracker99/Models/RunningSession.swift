import Foundation
import SwiftData
import CoreLocation

@Model
final class RunningSession {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var duration: TimeInterval // in seconds
    var distance: Double // in meters
    var averagePace: Double // minutes per km
    var calories: Int
    var elevationGain: Double // in meters
    var elevationLoss: Double // in meters
    var maxSpeed: Double // m/s
    var averageSpeed: Double // m/s
    var notes: String
    
    // Route data stored as JSON string
    @Attribute(.externalStorage) var routeDataJSON: Data?
    
    // Splits data (pace per km) stored as JSON
    var splitsDataJSON: Data?
    
    init(id: UUID = UUID(),
         startTime: Date = Date(),
         endTime: Date? = nil,
         duration: TimeInterval = 0,
         distance: Double = 0,
         averagePace: Double = 0,
         calories: Int = 0,
         elevationGain: Double = 0,
         elevationLoss: Double = 0,
         maxSpeed: Double = 0,
         averageSpeed: Double = 0,
         notes: String = "") {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.distance = distance
        self.averagePace = averagePace
        self.calories = calories
        self.elevationGain = elevationGain
        self.elevationLoss = elevationLoss
        self.maxSpeed = maxSpeed
        self.averageSpeed = averageSpeed
        self.notes = notes
    }
    
    // Computed properties
    var isActive: Bool {
        endTime == nil
    }
    
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
    
    var formattedPace: String {
        guard averagePace > 0 && averagePace < 100 else { return "--:--" }
        let minutes = Int(averagePace)
        let seconds = Int((averagePace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Route coordinates
    var routeCoordinates: [CLLocationCoordinate2D] {
        get {
            guard let data = routeDataJSON else { return [] }
            let decoder = JSONDecoder()
            if let locations = try? decoder.decode([LocationPoint].self, from: data) {
                return locations.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            }
            return []
        }
        set {
            let locations = newValue.map { LocationPoint(latitude: $0.latitude, longitude: $0.longitude) }
            let encoder = JSONEncoder()
            routeDataJSON = try? encoder.encode(locations)
        }
    }
    
    // Splits (pace per km)
    var splits: [Split] {
        get {
            guard let data = splitsDataJSON else { return [] }
            let decoder = JSONDecoder()
            return (try? decoder.decode([Split].self, from: data)) ?? []
        }
        set {
            let encoder = JSONEncoder()
            splitsDataJSON = try? encoder.encode(newValue)
        }
    }
}

// Helper structs for encoding/decoding
struct LocationPoint: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let timestamp: Date?
    
    init(latitude: Double, longitude: Double, altitude: Double? = nil, timestamp: Date? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
    }
}

struct Split: Codable, Identifiable {
    var id = UUID()
    let kmNumber: Int
    let pace: Double // minutes per km
    let duration: TimeInterval
    let elevation: Double?
    
    var formattedPace: String {
        guard pace > 0 && pace < 100 else { return "--:--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}

