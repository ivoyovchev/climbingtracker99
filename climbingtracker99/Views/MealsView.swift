import SwiftUI
import SwiftData

struct MealsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var meals: [Meal]
    @State private var showingAddMeal = false
    @State private var selectedMeal: Meal?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(meals) { meal in
                    MealRow(meal: meal)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedMeal = meal
                        }
                }
                .onDelete(perform: deleteMeals)
            }
            .navigationTitle("Meals")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddMeal = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddMeal) {
                MealEditView()
            }
            .sheet(item: $selectedMeal) { meal in
                MealEditView(meal: meal)
            }
        }
    }
    
    private func deleteMeals(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(meals[index])
            }
        }
    }
}

struct MealRow: View {
    let meal: Meal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(meal.name)
                .font(.headline)
            
            HStack {
                Text("\(Int(meal.calories)) cal")
                Spacer()
                Text("P: \(Int(meal.protein))g")
                Text("C: \(Int(meal.carbs))g")
                Text("F: \(Int(meal.fat))g")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct MealEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var calories: Double = 0
    @State private var protein: Double = 0
    @State private var carbs: Double = 0
    @State private var fat: Double = 0
    
    var meal: Meal?
    var isEditing: Bool { meal != nil }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Meal Details")) {
                    TextField("Name", text: $name)
                }
                
                Section(header: Text("Nutritional Information")) {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("Calories", value: $calories, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Protein (g)")
                        Spacer()
                        TextField("Protein", value: $protein, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Carbs (g)")
                        Spacer()
                        TextField("Carbs", value: $carbs, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Fat (g)")
                        Spacer()
                        TextField("Fat", value: $fat, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Meal" : "New Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Add") {
                        saveMeal()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let meal = meal {
                    name = meal.name
                    calories = meal.calories
                    protein = meal.protein
                    carbs = meal.carbs
                    fat = meal.fat
                }
            }
        }
    }
    
    private func saveMeal() {
        if let meal = meal {
            meal.name = name
            meal.calories = calories
            meal.protein = protein
            meal.carbs = carbs
            meal.fat = fat
        } else {
            let newMeal = Meal(
                name: name,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat
            )
            modelContext.insert(newMeal)
        }
        dismiss()
    }
} 