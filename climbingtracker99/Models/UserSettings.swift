import Foundation
import SwiftData

@Model
final class UserSettings {
    var userName: String
    var hasCompletedWelcome: Bool
    
    init(userName: String = "", hasCompletedWelcome: Bool = false) {
        self.userName = userName
        self.hasCompletedWelcome = hasCompletedWelcome
    }
} 