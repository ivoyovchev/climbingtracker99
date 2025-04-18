import Foundation
import SwiftData

@Model
final class Goals {
    var id: UUID
    var targetTrainingsPerWeek: Int
    var targetWeight: Double
    var lastUpdated: Date
    
    init(id: UUID = UUID(), targetTrainingsPerWeek: Int = 3, targetWeight: Double = 0.0) {
        self.id = id
        self.targetTrainingsPerWeek = targetTrainingsPerWeek
        self.targetWeight = targetWeight
        self.lastUpdated = Date()
    }
} 