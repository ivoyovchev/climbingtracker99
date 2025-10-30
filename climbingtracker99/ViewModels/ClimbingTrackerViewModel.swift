import SwiftUI
import SwiftData

@MainActor
class ClimbingTrackerViewModel: ObservableObject {
    @Published var trainings: [Training] = []
    @Published var goals: Goals = Goals()
    
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    
    init() {
        do {
            modelContainer = try ModelContainer(for: Training.self, Goals.self)
            modelContext = ModelContext(modelContainer)
            loadData()
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    private func loadData() {
        do {
            let descriptor = FetchDescriptor<Training>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            trainings = try modelContext.fetch(descriptor)
            
            let goalsDescriptor = FetchDescriptor<Goals>()
            if let fetchedGoals = try modelContext.fetch(goalsDescriptor).first {
                goals = fetchedGoals
            } else {
                // Create default goals if none exist
                goals = Goals()
                modelContext.insert(goals)
                try modelContext.save()
            }
        } catch {
            print("Error loading data: \(error)")
        }
    }
    
    func addTraining(_ training: Training) {
        modelContext.insert(training)
        trainings.insert(training, at: 0)
        save()
    }
    
    func updateGoals(_ newGoals: Goals) {
        goals = newGoals
        save()
    }
    
    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
} 