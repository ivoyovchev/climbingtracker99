import SwiftUI
import SwiftData

struct WeightEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var weight: String = ""
    @State private var date: Date = Date()
    @State private var note: String = ""
    
    var entry: WeightEntry?
    var isEditing: Bool { entry != nil }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Weight Details")) {
                    HStack {
                        TextField("Weight", text: $weight)
                            .keyboardType(.decimalPad)
                        Text("kg")
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $note)
                        .frame(height: 100)
                }
            }
            .navigationTitle(isEditing ? "Edit Weight" : "Add Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        saveEntry()
                    }
                    .disabled(weight.isEmpty)
                }
            }
            .onAppear {
                if let entry = entry {
                    weight = String(entry.weight)
                    date = entry.date
                    note = entry.note
                }
            }
        }
    }
    
    private func saveEntry() {
        guard let weightValue = Double(weight) else { return }
        
        if let entry = entry {
            entry.weight = weightValue
            entry.date = date
            entry.note = note
        } else {
            let newEntry = WeightEntry(weight: weightValue, date: date, note: note)
            modelContext.insert(newEntry)
        }
        
        dismiss()
    }
} 