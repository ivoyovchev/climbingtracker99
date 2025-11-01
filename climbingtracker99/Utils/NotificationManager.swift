import Foundation
import UserNotifications

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private init() {
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.authorizationStatus = granted ? .authorized : .denied
            }
            return granted
        } catch {
            print("Failed to request notification authorization: \(error)")
            return false
        }
    }
    
    // Get notification settings from UserDefaults or default values
    private var notificationsEnabled: Bool {
        // Try to get from UserSettings via a query, but fallback to UserDefaults for now
        UserDefaults.standard.bool(forKey: "notificationsEnabled")
    }
    
    private var reminderHours: Double {
        UserDefaults.standard.object(forKey: "notificationReminderHours") as? Double ?? 1.5
    }
    
    // Update settings (called from SettingsView)
    func updateSettings(enabled: Bool, reminderHours: Double) {
        UserDefaults.standard.set(enabled, forKey: "notificationsEnabled")
        UserDefaults.standard.set(reminderHours, forKey: "notificationReminderHours")
        checkAuthorizationStatus()
    }
    
    // Schedule notification for a planned training
    func scheduleTrainingNotification(for training: PlannedTraining) {
        guard notificationsEnabled else { return }
        scheduleNotification(
            for: training.date,
            estimatedTime: training.estimatedTimeOfDay,
            identifier: "training-\(training.persistentModelID.hashValue)",
            title: "Training Reminder",
            body: buildTrainingBody(training, hoursBefore: reminderHours),
            hoursBefore: reminderHours
        )
    }
    
    // Schedule notification for a planned run
    func scheduleRunNotification(for run: PlannedRun) {
        guard notificationsEnabled else { return }
        scheduleNotification(
            for: run.date,
            estimatedTime: run.estimatedTimeOfDay,
            identifier: "run-\(run.persistentModelID.hashValue)",
            title: "Run Reminder",
            body: buildRunBody(run, hoursBefore: reminderHours),
            hoursBefore: reminderHours
        )
    }
    
    // Remove notification for a planned training
    func removeTrainingNotification(for training: PlannedTraining) {
        let identifier = "training-\(training.persistentModelID.hashValue)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    // Remove notification for a planned run
    func removeRunNotification(for run: PlannedRun) {
        let identifier = "run-\(run.persistentModelID.hashValue)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    // Private helper to schedule notification
    private func scheduleNotification(
        for date: Date,
        estimatedTime: Date,
        identifier: String,
        title: String,
        body: String,
        hoursBefore: Double
    ) {
        let calendar = Calendar.current
        
        // Combine date and time
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: estimatedTime)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        
        guard let scheduledDate = calendar.date(from: combinedComponents) else {
            print("Failed to create scheduled date")
            return
        }
        
        // Calculate notification time (hoursBefore hours before scheduled time)
        // hoursBefore = 1.5 means 1 hour and 30 minutes before
        guard let notificationDate = calendar.date(
            byAdding: .minute,
            value: -Int(hoursBefore * 60),
            to: scheduledDate
        ) else {
            print("Failed to calculate notification date")
            return
        }
        
        // Only schedule if notification time is in the future
        guard notificationDate > Date() else {
            print("Notification time is in the past, skipping")
            return
        }
        
        let notificationComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: notificationComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            } else {
                print("Scheduled notification: \(identifier) for \(notificationDate)")
            }
        }
    }
    
    private func buildTrainingBody(_ training: PlannedTraining, hoursBefore: Double) -> String {
        let hoursText = formatHoursBefore(hoursBefore)
        if training.exerciseTypes.count == 1 {
            return "You have \(training.exerciseTypes.first?.displayName ?? "training") scheduled in \(hoursText) (\(formatTime(training.estimatedTimeOfDay)))"
        } else {
            return "You have \(training.exerciseTypes.count) exercises scheduled in \(hoursText) (\(formatTime(training.estimatedTimeOfDay)))"
        }
    }
    
    private func buildRunBody(_ run: PlannedRun, hoursBefore: Double) -> String {
        let hoursText = formatHoursBefore(hoursBefore)
        return "You have a \(run.runningType.rawValue) (\(String(format: "%.1f", run.estimatedDistance)) km) scheduled in \(hoursText) (\(formatTime(run.estimatedTimeOfDay)))"
    }
    
    private func formatHoursBefore(_ hours: Double) -> String {
        if hours == 1.0 {
            return "1 hour"
        } else if hours < 1.0 {
            let minutes = Int(hours * 60)
            return "\(minutes) minutes"
        } else {
            let wholeHours = Int(hours)
            let minutes = Int((hours - Double(wholeHours)) * 60)
            if minutes > 0 {
                return "\(wholeHours)h \(minutes)m"
            } else {
                return "\(wholeHours) hours"
            }
        }
    }
    
    // Send test notification immediately
    func sendTestNotification() {
        // Remove only test notifications (those starting with "test-notification-")
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let testIdentifiers = requests.filter { $0.identifier.hasPrefix("test-notification") }.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: testIdentifiers)
        }
        
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let testIdentifiers = notifications.filter { $0.request.identifier.hasPrefix("test-notification") }.map { $0.request.identifier }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: testIdentifiers)
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Training Reminder"
        content.body = "This is a test notification. Your training reminders will appear like this."
        content.sound = .default
        content.badge = 1
        
        // Use 1 second delay for reliable delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let identifier = "test-notification-\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to send test notification: \(error.localizedDescription)")
                } else {
                    print("Test notification scheduled successfully with identifier: \(identifier)")
                }
            }
        }
    }
    
    // Send test notification based on a training plan
    func sendTestNotification(for training: PlannedTraining) {
        // Remove only test notifications
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let testIdentifiers = requests.filter { $0.identifier.hasPrefix("test-notification") }.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: testIdentifiers)
        }
        
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let testIdentifiers = notifications.filter { $0.request.identifier.hasPrefix("test-notification") }.map { $0.request.identifier }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: testIdentifiers)
        }
        
        let hoursBefore = reminderHours
        let content = UNMutableNotificationContent()
        content.title = "Training Reminder"
        content.body = buildTrainingBody(training, hoursBefore: hoursBefore)
        content.sound = .default
        content.badge = 1
        
        // Use 1 second delay for reliable delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let identifier = "test-notification-\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to send test notification: \(error.localizedDescription)")
                } else {
                    print("Test notification scheduled successfully with identifier: \(identifier)")
                }
            }
        }
    }
    
    // Send test notification based on a run plan
    func sendTestNotification(for run: PlannedRun) {
        // Remove only test notifications
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let testIdentifiers = requests.filter { $0.identifier.hasPrefix("test-notification") }.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: testIdentifiers)
        }
        
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let testIdentifiers = notifications.filter { $0.request.identifier.hasPrefix("test-notification") }.map { $0.request.identifier }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: testIdentifiers)
        }
        
        let hoursBefore = reminderHours
        let content = UNMutableNotificationContent()
        content.title = "Run Reminder"
        content.body = buildRunBody(run, hoursBefore: hoursBefore)
        content.sound = .default
        content.badge = 1
        
        // Use 1 second delay for reliable delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let identifier = "test-notification-\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to send test notification: \(error.localizedDescription)")
                } else {
                    print("Test notification scheduled successfully with identifier: \(identifier)")
                }
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Reschedule all notifications (useful after migration or when re-enabling notifications)
    func rescheduleAllNotifications(trainings: [PlannedTraining], runs: [PlannedRun]) {
        guard notificationsEnabled else {
            // Remove all if disabled
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return
        }
        
        // Remove all existing notifications first
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Schedule new ones
        for training in trainings {
            scheduleTrainingNotification(for: training)
        }
        
        for run in runs {
            scheduleRunNotification(for: run)
        }
    }
    
    // Update settings from UserSettings model
    func syncSettings(enabled: Bool, reminderHours: Double) {
        updateSettings(enabled: enabled, reminderHours: reminderHours)
    }
}

