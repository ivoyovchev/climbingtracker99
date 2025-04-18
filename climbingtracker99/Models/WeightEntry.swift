import Foundation
import SwiftData

@Model
final class WeightEntry: Identifiable {
    var id: String { "\(date.timeIntervalSince1970)" }
    var weight: Double
    var date: Date
    var note: String
    
    init(weight: Double, date: Date = Date(), note: String = "") {
        self.weight = weight
        self.date = date
        self.note = note
    }
} 