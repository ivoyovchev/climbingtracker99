import SwiftUI
import AudioToolbox

enum CampusingHoldType: String, CaseIterable {
    case edgeSize = "Edge Size"
    case ballsSmall = "Balls (Small)"
    case ballsMedium = "Balls (Medium)"
}

struct CampusingView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var recordedExercise: RecordedExercise
    
    @State private var numberOfSets: Int = 3
    @State private var restTime: Int = 60 // seconds
    @State private var isActive = false
    @State private var currentSet: Int = 0
    @State private var isInPrep = false
    @State private var isInRest = false
    @State private var isInInput = false
    @State private var timeRemaining: TimeInterval = 15
    @State private var timer: Timer?
    @State private var startTime: Date?
    @State private var totalDuration: TimeInterval = 0
    
    // Set data collection
    @State private var setData: [CampusingSetData] = []
    @State private var currentHoldType: CampusingHoldType = .edgeSize
    @State private var currentEdgeSize: Int = 20
    @State private var selectedBars: Set<Int> = []
    
    struct CampusingSetData: Identifiable {
        let id = UUID()
        var holdType: CampusingHoldType
        var edgeSize: Int? // Only set if holdType is .edgeSize
        var bars: Set<Int>
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !isActive {
                    // Setup Phase
                    Form {
                        Section("Workout Settings") {
                            Stepper("Number of Sets: \(numberOfSets)", value: $numberOfSets, in: 1...20)
                            Stepper("Rest Time: \(restTime)s", value: $restTime, in: 10...300, step: 5)
                        }
                    }
                } else if isInInput {
                    // Input Phase - Enter set data
                    inputSetDataView
                } else {
                    // Active Workout Phase
                    activeWorkoutView
                }
            }
            .navigationTitle("Campusing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        stopWorkout()
                        dismiss()
                    }
                }
                
                if !isActive {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Start") {
                            startWorkout()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }
    
    // MARK: - Active Workout View
    
    private var activeWorkoutView: some View {
        VStack(spacing: 40) {
            // Set counter
            Text("Set \(currentSet + 1) of \(numberOfSets)")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Main timer display
            VStack(spacing: 20) {
                if isInPrep {
                    Text("GET READY")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    
                    Text("\(Int(timeRemaining))")
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    
                    Text("GO in...")
                        .font(.title3)
                        .foregroundColor(.secondary)
                } else if isInRest {
                    Text("REST")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    
                    Text(formatTime(timeRemaining))
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    
                    Text("Next set starts automatically")
                        .font(.title3)
                        .foregroundColor(.secondary)
                } else {
                    // Climbing phase
                    Text("GO!")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .padding(.top, 40)
                    
                    Text("Climb now")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text(formatTime(totalDuration))
                        .font(.title)
                        .foregroundColor(.secondary)
                        .padding(.top)
                    
                    Button {
                        setDone()
                    } label: {
                        Text("Set Done")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                }
            }
            
            // Progress indicator
            if numberOfSets > 1 {
                ProgressView(value: Double(currentSet), total: Double(numberOfSets))
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 8)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Input Set Data View
    
    private var inputSetDataView: some View {
        VStack(spacing: 0) {
            Form {
                Section("Set \(currentSet + 1) Data") {
                    // Hold type picker
                    Picker("Hold Type", selection: $currentHoldType) {
                        Text("Edge Size").tag(CampusingHoldType.edgeSize)
                        Text("Balls (Small)").tag(CampusingHoldType.ballsSmall)
                        Text("Balls (Medium)").tag(CampusingHoldType.ballsMedium)
                    }
                    .pickerStyle(.segmented)
                    
                    // Edge size input (only shown if edge size is selected)
                    if currentHoldType == .edgeSize {
                        Stepper("Edge Size: \(currentEdgeSize)mm", value: $currentEdgeSize, in: 10...40, step: 1)
                    }
                }
                
                Section {
                    Button {
                        saveSetData()
                    } label: {
                        Text("Save Set")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(selectedBars.isEmpty)
                }
            }
            
            // Campus bars selection - outside Form for better touch handling
            VStack(alignment: .leading, spacing: 12) {
                Text("Campus Bars Hit")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 16)
                
                // Grid of buttons for bars 1-9
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(1...9, id: \.self) { barNumber in
                        Button {
                            // Toggle bar selection
                            withAnimation {
                                if selectedBars.contains(barNumber) {
                                    selectedBars.remove(barNumber)
                                } else {
                                    selectedBars.insert(barNumber)
                                }
                            }
                        } label: {
                            Text("\(barNumber)")
                                .font(.system(size: 24, weight: .bold))
                                .frame(width: 60, height: 60)
                                .background(selectedBars.contains(barNumber) ? Color.green : Color(.systemGray5))
                                .foregroundColor(selectedBars.contains(barNumber) ? .white : .primary)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedBars.contains(barNumber) ? Color.green : Color.clear, lineWidth: 3)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                if !selectedBars.isEmpty {
                    Text("Selected: \(selectedBars.sorted().map { String($0) }.joined(separator: "-"))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - Functions
    
    private func startWorkout() {
        isActive = true
        currentSet = 0
        setData.removeAll()
        startTime = Date()
        totalDuration = 0
        startPrepTimer()
        startTotalTimer()
    }
    
    private func startPrepTimer() {
        isInPrep = true
        isInRest = false
        isInInput = false
        timeRemaining = 15
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            timeRemaining -= 1
            
            if timeRemaining <= 0 {
                timer?.invalidate()
                playSound()
                startClimbingPhase()
            } else if timeRemaining <= 3 {
                playSound()
            }
        }
    }
    
    private func startClimbingPhase() {
        isInPrep = false
        isInRest = false
        isInInput = false
        startTotalTimer()
    }
    
    private func setDone() {
        // Move to input phase
        isInInput = true
        isInPrep = false
        isInRest = false
        
        // Reset for this set
        currentHoldType = .edgeSize
        currentEdgeSize = 20
        selectedBars.removeAll()
    }
    
    private func saveSetData() {
        guard !selectedBars.isEmpty else { return }
        
        // Save data for this set
        setData.append(CampusingSetData(
            holdType: currentHoldType,
            edgeSize: currentHoldType == .edgeSize ? currentEdgeSize : nil,
            bars: selectedBars
        ))
        
        // Move to next set or finish
        if currentSet < numberOfSets - 1 {
            currentSet += 1
            startRestPhase()
        } else {
            finishWorkout()
        }
    }
    
    private func startRestPhase() {
        isInPrep = false
        isInRest = true
        isInInput = false
        timeRemaining = TimeInterval(restTime)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            timeRemaining -= 1
            
            if timeRemaining <= 0 {
                timer?.invalidate()
                playSound()
                // Rest complete, move to next set prep
                startPrepTimer()
            } else if timeRemaining <= 3 {
                playSound()
            }
        }
    }
    
    private func startTotalTimer() {
        // Total duration timer (runs separately)
        let totalTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let start = startTime {
                totalDuration = Date().timeIntervalSince(start)
            }
        }
        RunLoop.main.add(totalTimer, forMode: .common)
    }
    
    private func finishWorkout() {
        stopWorkout()
        
        // Save workout data to recordedExercise
        recordedExercise.duration = Int(totalDuration)
        recordedExercise.sets = numberOfSets
        recordedExercise.restDuration = restTime
        
        // Store set data in notes
        var setDetails: [String] = []
        for (index, set) in setData.enumerated() {
            let bars = set.bars.sorted().map { String($0) }.joined(separator: "-")
            var holdInfo = ""
            
            switch set.holdType {
            case .edgeSize:
                holdInfo = "\(set.edgeSize ?? 20)mm edge"
            case .ballsSmall:
                holdInfo = "Small balls"
            case .ballsMedium:
                holdInfo = "Medium balls"
            }
            
            setDetails.append("Set \(index + 1): \(holdInfo), bars \(bars)")
        }
        
        recordedExercise.updateNotes("Campusing: \(setDetails.joined(separator: "; "))")
        
        // Store edge size (average, only for edge size sets)
        let edgeSizeSets = setData.filter { $0.holdType == .edgeSize && $0.edgeSize != nil }
        if !edgeSizeSets.isEmpty {
            let avgEdgeSize = Int(edgeSizeSets.compactMap { $0.edgeSize }.map { Double($0) }.reduce(0, +) / Double(edgeSizeSets.count))
            recordedExercise.edgeSize = avgEdgeSize
        }
        
        dismiss()
    }
    
    private func stopWorkout() {
        timer?.invalidate()
        timer = nil
        isActive = false
        isInPrep = false
        isInRest = false
        isInInput = false
    }
    
    private func playSound() {
        AudioServicesPlaySystemSound(1016) // System sound
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

