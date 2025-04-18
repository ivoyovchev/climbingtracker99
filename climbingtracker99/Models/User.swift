import Foundation

struct User: Identifiable, Codable {
    let id: String
    var name: String
    var longTermGoal: String
    var shortTermGoal: String
    var trainingFrequency: Int
    var weightGoal: Double?
    
    enum TrainingType: String, CaseIterable, Identifiable, Codable {
        case climbing = "climbing"
        case strength = "strength"
        case flexibility = "flexibility"
        case cardio = "cardio"
        case rest = "rest"
        
        var id: String { self.rawValue }
    }
} 