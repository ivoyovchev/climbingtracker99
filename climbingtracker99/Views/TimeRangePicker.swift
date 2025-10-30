import SwiftUI

struct TimeRangePicker: View {
    @Binding var selectedRange: TimeRange
    @Binding var selectedDate: Date
    
    var body: some View {
        HStack {
            Picker("Time Range", selection: $selectedRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                .labelsHidden()
                .padding(.trailing)
        }
    }
} 