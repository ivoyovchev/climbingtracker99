import SwiftUI
import SwiftData

struct NutritionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var nutritionEntries: [NutritionEntry]
    @State private var showingAddEntry = false
    @State private var selectedEntry: NutritionEntry?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabHeaderView(title: "Nutrition") {
                    Button(action: { showingAddEntry = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                    }
                }
                
                List {
                    ForEach(nutritionEntries) { entry in
                        NutritionEntryRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEntry = entry
                            }
                    }
                    .onDelete(perform: deleteEntries)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddEntry) {
                NutritionEntryEditView()
            }
            .sheet(item: $selectedEntry) { entry in
                NutritionEntryEditView(entry: entry)
            }
        }
    }
    
    private func deleteEntries(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(nutritionEntries[index])
            }
        }
    }
}

struct NutritionEntryRow: View {
    let entry: NutritionEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.date, style: .date)
                .font(.headline)
            
            if let meal = entry.meal {
                Text(meal.name)
                    .font(.subheadline)
            }
            
            HStack {
                Text("\(Int(entry.calories)) cal")
                Spacer()
                Text("P: \(Int(entry.protein))g")
                Text("C: \(Int(entry.carbs))g")
                Text("F: \(Int(entry.fat))g")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct NutritionEntryEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var meals: [Meal]
    
    @State private var date: Date
    @State private var selectedMeal: Meal?
    @State private var calories: Double
    @State private var protein: Double
    @State private var carbs: Double
    @State private var fat: Double
    
    private var entry: NutritionEntry?
    
    init(entry: NutritionEntry? = nil) {
        self.entry = entry
        _date = State(initialValue: entry?.date ?? Date())
        _selectedMeal = State(initialValue: entry?.meal)
        _calories = State(initialValue: entry?.calories ?? 0)
        _protein = State(initialValue: entry?.protein ?? 0)
        _carbs = State(initialValue: entry?.carbs ?? 0)
        _fat = State(initialValue: entry?.fat ?? 0)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Date")) {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                
                Section(header: Text("Meal")) {
                    Picker("Select Meal", selection: $selectedMeal) {
                        Text("None").tag(nil as Meal?)
                        ForEach(meals) { meal in
                            Text(meal.name).tag(meal as Meal?)
                        }
                    }
                }
                
                Section(header: Text("Nutritional Information")) {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("Calories", value: $calories, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Protein (g)")
                        Spacer()
                        TextField("Protein", value: $protein, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Carbs (g)")
                        Spacer()
                        TextField("Carbs", value: $carbs, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Fat (g)")
                        Spacer()
                        TextField("Fat", value: $fat, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle(entry == nil ? "Add Entry" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEntry()
                    }
                }
            }
        }
    }
    
    private func saveEntry() {
        if let entry = entry {
            entry.date = date
            entry.meal = selectedMeal
            entry.calories = calories
            entry.protein = protein
            entry.carbs = carbs
            entry.fat = fat
        } else {
            let newEntry = NutritionEntry(
                date: date,
                meal: selectedMeal,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat
            )
            modelContext.insert(newEntry)
        }
        dismiss()
    }
} 