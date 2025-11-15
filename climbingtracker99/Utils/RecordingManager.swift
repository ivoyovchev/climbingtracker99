import Foundation
import SwiftData

struct ActiveRecordingSnapshot {
    var training: Training?
    var location: TrainingLocation
    var focus: TrainingFocus
    var startTime: Date
    var notes: String
    var activeExercises: [RecordedExercise]
    var completedExercises: [RecordedExercise]
    var originalExerciseIDs: Set<PersistentIdentifier>
}

final class RecordingManager: ObservableObject {
    static let shared = RecordingManager()
    @Published var snapshot: ActiveRecordingSnapshot?
    private init() {}
}

