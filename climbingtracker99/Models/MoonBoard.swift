import Foundation
import SwiftData

@Model
final class MoonLogEntry {
    var id: UUID
    var date: Date
    var problemId: String
    var problemName: String
    var grade: String
    var board: String
    var attempts: Int
    var sent: Bool
    
    init(id: UUID = UUID(), date: Date, problemId: String, problemName: String, grade: String, board: String, attempts: Int, sent: Bool) {
        self.id = id
        self.date = date
        self.problemId = problemId
        self.problemName = problemName
        self.grade = grade
        self.board = board
        self.attempts = attempts
        self.sent = sent
    }
}


