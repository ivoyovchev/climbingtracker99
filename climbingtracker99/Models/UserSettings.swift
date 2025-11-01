import Foundation
import SwiftData

@Model
final class UserSettings {
    var userName: String
    var hasCompletedWelcome: Bool
    var notificationsEnabled: Bool = true
    var notificationReminderHours: Double = 1.5 // Default: 1.5 hours before
    
    init(userName: String = "", hasCompletedWelcome: Bool = false) {
        self.userName = userName
        self.hasCompletedWelcome = hasCompletedWelcome
        self.notificationsEnabled = true
        self.notificationReminderHours = 1.5
    }
} 