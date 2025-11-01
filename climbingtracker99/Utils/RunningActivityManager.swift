import Foundation
import ActivityKit

@available(iOS 16.1, *)
class RunningActivityManager {
    static let shared = RunningActivityManager()
    private var activity: Activity<RunningActivityAttributes>?
    
    private init() {}
    
    func startActivity(startTime: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return
        }
        
        let attributes = RunningActivityAttributes(startTime: startTime)
        let initialState = RunningActivityAttributes.ContentState(
            distance: 0.0,
            duration: 0,
            averagePace: 0.0,
            currentPace: 0.0,
            calories: 0,
            isPaused: false
        )
        
        let content = ActivityContent(state: initialState, staleDate: nil)
        
        do {
            let newActivity = try Activity<RunningActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            activity = newActivity
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
    
    func updateActivity(
        distance: Double,
        duration: TimeInterval,
        averagePace: Double,
        currentPace: Double,
        calories: Int,
        isPaused: Bool
    ) {
        guard let activity = activity else { return }
        
        let updatedState = RunningActivityAttributes.ContentState(
            distance: distance,
            duration: duration,
            averagePace: averagePace,
            currentPace: currentPace,
            calories: calories,
            isPaused: isPaused
        )
        
        let content = ActivityContent(state: updatedState, staleDate: nil)
        
        Task {
            await activity.update(content)
        }
    }
    
    func stopActivity() {
        guard let activity = activity else { return }
        
        let finalState = RunningActivityAttributes.ContentState(
            distance: activity.content.state.distance,
            duration: activity.content.state.duration,
            averagePace: activity.content.state.averagePace,
            currentPace: activity.content.state.currentPace,
            calories: activity.content.state.calories,
            isPaused: activity.content.state.isPaused
        )
        
        let content = ActivityContent(state: finalState, staleDate: nil)
        
        Task {
            await activity.end(content, dismissalPolicy: .immediate)
        }
        
        self.activity = nil
    }
}

