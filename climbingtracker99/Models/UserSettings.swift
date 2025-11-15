import Foundation
import SwiftData

@Model
final class UserSettings {
    var userName: String
    var handle: String
    var bio: String
    @Attribute(.externalStorage) var profileImageData: Data?
    var hasCompletedWelcome: Bool
    var notificationsEnabled: Bool = true
    var notificationReminderHours: Double = 1.5 // Default: 1.5 hours before
    var lastProfileUpdated: Date?
    
    init(userName: String = "", handle: String = "", bio: String = "", profileImageData: Data? = nil, hasCompletedWelcome: Bool = false) {
        self.userName = userName
        self.handle = handle
        self.bio = bio
        self.profileImageData = profileImageData
        self.hasCompletedWelcome = hasCompletedWelcome
        self.notificationsEnabled = true
        self.notificationReminderHours = 1.5
    }
} 