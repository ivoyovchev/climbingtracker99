import Foundation
import SwiftData

@Model
final class WeightEntry: Identifiable {
    var id: String { "\(date.timeIntervalSince1970)" }
    var syncIdentifier: String?
    var weight: Double
    var date: Date
    var note: String
    
    init(weight: Double, date: Date = Date(), note: String = "", syncIdentifier: String? = nil) {
        self.syncIdentifier = syncIdentifier ?? UUID().uuidString
        self.weight = weight
        self.date = date
        self.note = note
    }
} 