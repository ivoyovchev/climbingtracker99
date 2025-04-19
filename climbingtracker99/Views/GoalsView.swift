import SwiftUI
import SwiftData

struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var goals: [Goals]
    
    @State private var targetTrainingsPerWeek: Int = 0
    @State private var targetWeight: Double = 0
    @State private var startingWeight: Double?
    
    var body: some View {
        Form {
            Section(header: Text("Training Goals")) {
                Stepper("Target Trainings per Week: \(targetTrainingsPerWeek)", value: $targetTrainingsPerWeek, in: 0...7)
            }
            
            Section(header: Text("Weight Goals")) {
                HStack {
                    Text("Starting Weight")
                    Spacer()
                    TextField("kg", value: $startingWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Target Weight")
                    Spacer()
                    TextField("kg", value: $targetWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .onAppear {
            if let goal = goals.first {
                targetTrainingsPerWeek = goal.targetTrainingsPerWeek
                targetWeight = goal.targetWeight
                startingWeight = goal.startingWeight
            }
        }
        .onDisappear {
            saveGoals()
        }
    }
    
    private func saveGoals() {
        let goal = goals.first ?? Goals()
        goal.targetTrainingsPerWeek = targetTrainingsPerWeek
        goal.targetWeight = targetWeight
        goal.startingWeight = startingWeight
        goal.lastUpdated = Date()
        
        if goals.isEmpty {
            modelContext.insert(goal)
        }
    }
} 