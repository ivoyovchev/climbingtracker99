import SwiftUI
import SwiftData
import PhotosUI
import AVKit

// Add color extension for TrainingFocus
extension TrainingFocus {
    var color: Color {
        switch self {
        case .strength:
            return .red
        case .power:
            return .orange
        case .endurance:
            return .green
        case .technique:
            return .blue
        case .mobility:
            return .purple
        }
    }
}

public struct TrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Training.date, order: .reverse) private var trainings: [Training]
    @State private var showingAddTraining = false
    @State private var showingRecordTraining = false
    @State private var trainingToEdit: Training?
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TabHeaderView(title: "Training") {
                    Menu {
                        Button(action: { showingAddTraining = true }) {
                            Label("Log Training", systemImage: "pencil")
                        }
                        
                        Button(action: { showingRecordTraining = true }) {
                            Label("Record Training", systemImage: "record.circle")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                    }
                }
                
                trainingList
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddTraining) {
                TrainingEditView()
            }
            .fullScreenCover(isPresented: $showingRecordTraining) {
                RecordTrainingView()
            }
            .sheet(item: $trainingToEdit) { training in
                TrainingEditView(training: training)
            }
        }
    }
    
    private var trainingList: some View {
        List {
            ForEach(trainings) { training in
                TrainingRow(training: training) {
                    trainingToEdit = training
                }
            }
            .onDelete(perform: deleteTrainings)
        }
    }
    
    private func deleteTrainings(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(trainings[index])
            }
        }
    }
}

struct TrainingRow: View {
    let training: Training
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Focus type colored stripe
            Rectangle()
                .fill(training.focus.color)
                .frame(width: 8)
            
            VStack(alignment: .leading, spacing: 8) {
                // Date, Time and Focus row
                HStack {
                    Text(training.date, style: .date)
                        .font(.headline)
                    Text(training.focus.rawValue)
                        .font(.subheadline)
                        .foregroundColor(training.focus.color)
                    Spacer()
                    Text(training.date, style: .time)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // Duration and Location row
                HStack {
                    Text("\(training.duration) min")
                        .font(.subheadline)
                    Spacer()
                    Text(training.location.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // Exercise thumbnails and Media count row
                if !training.recordedExercises.isEmpty || !training.media.isEmpty {
                    HStack(spacing: 8) {
                        // Exercise thumbnails
                        if !training.recordedExercises.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(training.recordedExercises) { recordedExercise in
                                        Image(recordedExercise.exercise.type.imageName)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 40, height: 30)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                }
                            }
                        }
                        
                        // Media count
                        if !training.media.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                Text("\(training.media.count)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .padding(.vertical, 12)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .listRowInsets(EdgeInsets())
        .animation(.easeInOut(duration: 0.3), value: training.recordedExercises)
        .animation(.easeInOut(duration: 0.3), value: training.media)
    }
}

struct TrainingEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [Exercise]
    
    @State private var date: Date = Date()
    @State private var duration: Int = 60
    @State private var location: TrainingLocation = .indoor
    @State private var focus: TrainingFocus = .strength
    @State private var selectedExercises: [Exercise] = []
    @State private var recordedExercises: [RecordedExercise] = []
    @State private var notes: String = ""
    @State private var selectedMedia: [Media] = []
    @State private var showingImagePicker = false
    @State private var showingVideoPicker = false
    @State private var selectedImageItems: [PhotosPickerItem] = []
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var exerciseToEdit: RecordedExercise?
    @State private var isEditingExercise: Bool = false
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    // Computed property for available exercises
    private var availableExercises: [Exercise] {
        let selectedExerciseIds = recordedExercises.map { $0.exercise.id }
        return exercises.filter { !selectedExerciseIds.contains($0.id) }
    }
    
    private func addExercise(_ exercise: Exercise) {
        // Create a new recorded exercise and initialize it with the exercise's default values
        let recordedExercise = RecordedExercise(exercise: exercise)
        
        // Copy all default values from the exercise
            recordedExercise.gripType = exercise.gripType
            recordedExercise.duration = exercise.duration
            recordedExercise.repetitions = exercise.repetitions
            recordedExercise.sets = exercise.sets
            recordedExercise.restDuration = exercise.restDuration
            recordedExercise.addedWeight = Int(exercise.addedWeight ?? 0)
        recordedExercise.weight = Int(exercise.weight ?? 0)
            recordedExercise.grade = exercise.grade
        recordedExercise.gradeTried = exercise.gradeTried
            recordedExercise.routes = exercise.routes
            recordedExercise.attempts = exercise.attempts
            recordedExercise.restBetweenRoutes = exercise.restBetweenRoutes
            recordedExercise.sessionDuration = exercise.sessionDuration
        recordedExercise.moves = exercise.moves
        recordedExercise.boardType = exercise.boardType
        recordedExercise.edgeSize = exercise.edgeSize
        recordedExercise.hamstrings = exercise.hamstrings
        recordedExercise.hips = exercise.hips
        recordedExercise.forearms = exercise.forearms
        recordedExercise.legs = exercise.legs
        
        recordedExercises.append(recordedExercise)
    }
    
    var training: Training?
    var isEditing: Bool { training != nil }
    
    var body: some View {
        NavigationView {
            Form {
                // Header section with three rows
                Section {
                    // Row 1: Date/Time
                    DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .font(.subheadline)
                    
                    // Row 2: Location/Focus
                    HStack(spacing: 20) {
                        Picker("Location", selection: $location) {
                            ForEach(TrainingLocation.allCases, id: \.self) { location in
                                Text(location.rawValue).tag(location)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, -8)
                        
                        Picker("Focus", selection: $focus) {
                            ForEach(TrainingFocus.allCases, id: \.self) { focus in
                                Text(focus.rawValue).tag(focus)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, -8)
                    }
                    
                    // Row 3: Duration
                    HStack {
                        Text("Duration")
                            .font(.subheadline)
                        Spacer()
                        Text("\(duration) min")
                            .font(.subheadline)
                        Stepper("", value: $duration, in: 15...240, step: 15)
                            .labelsHidden()
                    }
                }
                
                // Completed Exercises section
                if !recordedExercises.isEmpty {
                    Section(header: Text("Completed Exercises")) {
                        ForEach(recordedExercises) { recordedExercise in
                            Button(action: {
                                exerciseToEdit = recordedExercise
                                isEditingExercise = true
                            }) {
                                HStack(spacing: 16) {
                                    // Exercise Image
                                    Image(recordedExercise.exercise.type.imageName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(recordedExercise.exercise.type.rawValue)
                                            .font(.headline)
                                        
                                        ExerciseDetails(exercise: recordedExercise.exercise, recordedExercise: recordedExercise)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { indexSet in
                            recordedExercises.remove(atOffsets: indexSet)
                        }
                    }
                }
                
                // Available Exercises section
                Section(header: Text("Available Exercises")) {
                    AvailableExercisesGrid(
                        exercises: availableExercises,
                        onAddExercise: addExercise
                    )
                }
                
                // Media Section
                Section(header: Text("Media")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(selectedMedia) { media in
                                MediaThumbnail(media: media, onDelete: {
                                    selectedMedia.removeAll { $0.id == media.id }
                                })
                            }
                            
                            // Photos Picker
                            PhotosPicker(selection: $selectedImageItems, matching: .images) {
                                VStack {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 24))
                                    Text("Add Photos")
                                        .font(.caption)
                                }
                                .frame(width: 60, height: 60)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                            }
                            
                            // Video Picker
                            PhotosPicker(selection: $selectedVideoItem, matching: .videos) {
                                VStack {
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 24))
                                    Text("Add Video")
                                        .font(.caption)
                                }
                                .frame(width: 60, height: 60)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .onChange(of: selectedImageItems) { _, newItems in
                    Task {
                        for item in newItems {
                            await handleMediaSelection(item, type: .image)
                        }
                        selectedImageItems.removeAll()
                    }
                }
                .onChange(of: selectedVideoItem) { _, newItem in
                    Task {
                        if let item = newItem {
                            await handleMediaSelection(item, type: .video)
                            selectedVideoItem = nil
                        }
                    }
                }
                
                // Notes section at the bottom
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle(isEditing ? "Edit Training" : "New Training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        saveTraining()
                    }
                }
            }
            .overlay {
                if isEditingExercise, let exercise = exerciseToEdit {
                    ExerciseRecordView(recordedExercise: exercise, isPresented: $isEditingExercise)
                        .transition(.opacity)
                }
            }
            .onAppear {
                if let training = training {
                    date = training.date
                    duration = training.duration
                    location = training.location
                    focus = training.focus
                    recordedExercises = training.recordedExercises
                    notes = training.notes
                    selectedMedia = training.media
                }
            }
        }
    }
    
    private func handleMediaSelection(_ item: PhotosPickerItem, type: MediaType) async {
        do {
            print("Starting media selection handling")
            
            // Get the data from the PhotosPicker item
            if let data = try await item.loadTransferable(type: Data.self) {
                print("Successfully loaded media data")
                
                // Create a new Media object with the data
                let media: Media
                if type == .video {
                    media = Media(type: .video, videoData: data)
                    // Generate thumbnail for video
                    if let thumbnailData = try? await media.generateThumbnail() {
                        media.thumbnailData = thumbnailData
                    }
                } else {
                    media = Media(type: .image, imageData: data)
                }
                
                print("Created media object with data")
                
                // Add the media to the selected media array
                DispatchQueue.main.async {
                    if !selectedMedia.contains(where: { $0.id == media.id }) {
                        selectedMedia.append(media)
                        print("Added media to selectedMedia array. New count: \(selectedMedia.count)")
                    }
                }
            } else {
                print("Failed to load media data")
            }
        } catch {
            print("Error handling media selection: \(error)")
        }
    }
    
    private func saveTraining() {
        if let training = training {
            training.date = date
            training.duration = duration
            training.location = location
            training.focus = focus
            training.recordedExercises = recordedExercises
            training.notes = notes
            training.media = Array(selectedMedia)
        } else {
            let newTraining = Training(
                date: date,
                duration: duration,
                location: location,
                focus: focus,
                recordedExercises: recordedExercises,
                notes: notes,
                media: Array(selectedMedia)
            )
            modelContext.insert(newTraining)
        }
        dismiss()
    }
}

struct MediaThumbnail: View {
    let media: Media
    @State private var showingMediaViewer = false
    let onDelete: () -> Void
    
    var body: some View {
        Group {
            if let image = media.thumbnail {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            ZStack {
                Image(systemName: "photo.fill")
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
                    .padding(4)
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .padding(4)
                .offset(x: 20, y: -20)
            }
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingMediaViewer = true
            }
        }
        .sheet(isPresented: $showingMediaViewer) {
            MediaViewerView(media: media)
        }
        .animation(.easeInOut(duration: 0.3), value: media)
    }
}

struct MediaViewerView: View {
    let media: Media
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        NavigationView {
            Group {
                if media.type == .image, let image = media.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1), 4)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                }
                        )
                        .padding()
                } else if media.type == .video, let videoURL = media.videoURL {
                    VideoPlayer(player: player)
                        .onAppear {
                            player = AVPlayer(url: videoURL)
                            player?.play()
                        }
                        .onDisappear {
                            player?.pause()
                            player = nil
                        }
                } else {
                    Text("Unable to load media")
                        .foregroundColor(.gray)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct EdgePickupsParametersView: View {
    @ObservedObject var recordedExercise: RecordedExercise
    
    var body: some View {
        Section(header: Text("Parameters")) {
            Stepper("Edge Size: \(recordedExercise.edgeSize ?? recordedExercise.exercise.edgeSize ?? 20) mm", 
                   value: Binding(
                    get: { recordedExercise.edgeSize ?? recordedExercise.exercise.edgeSize ?? 20 },
                    set: { recordedExercise.updateEdgeSize($0) }
                   ),
                   in: 5...30)
            
            Stepper("Duration: \(recordedExercise.duration ?? recordedExercise.exercise.duration ?? 15) sec", 
                   value: Binding(
                    get: { recordedExercise.duration ?? recordedExercise.exercise.duration ?? 15 },
                    set: { recordedExercise.updateDuration($0) }
                   ),
                   in: 1...30)
            
            Stepper("Sets: \(recordedExercise.sets ?? recordedExercise.exercise.sets ?? 6)", 
                   value: Binding(
                    get: { recordedExercise.sets ?? recordedExercise.exercise.sets ?? 6 },
                    set: { recordedExercise.updateSets($0) }
                   ),
                   in: 1...12)
            
            Stepper("Rest Between Sets: \(recordedExercise.restDuration ?? recordedExercise.exercise.restDuration ?? 2) min", 
                   value: Binding(
                    get: { recordedExercise.restDuration ?? recordedExercise.exercise.restDuration ?? 2 },
                    set: { recordedExercise.updateRestDuration($0) }
                   ),
                   in: 1...10)
            
            Stepper("Added Weight: \(recordedExercise.addedWeight ?? Int(recordedExercise.exercise.addedWeight ?? 30)) kg", 
                   value: Binding(
                    get: { recordedExercise.addedWeight ?? Int(recordedExercise.exercise.addedWeight ?? 30) },
                    set: { recordedExercise.updateAddedWeight($0) }
                   ),
                   in: 0...60)
        }
    }
}

struct ExerciseRecordView: View {
    @ObservedObject var recordedExercise: RecordedExercise
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Exercise Image
                Image(recordedExercise.exercise.type.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                
                ExerciseFormView(exercise: recordedExercise.exercise, 
                               recordedExercise: recordedExercise,
                               isRecording: true)
            }
            .navigationTitle("Record Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct ExerciseTile: View {
    let exercise: Exercise
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(exercise.type.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.type.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    ExerciseDetails(exercise: exercise, recordedExercise: nil)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .aspectRatio(1.5, contentMode: .fit)
    }
}

struct ExerciseDetails: View {
    let exercise: Exercise
    let recordedExercise: RecordedExercise?
    
    init(exercise: Exercise, recordedExercise: RecordedExercise? = nil) {
        self.exercise = exercise
        self.recordedExercise = recordedExercise
    }
    
    private func getValue<T>(_ recorded: T?, _ fallback: T?) -> T? {
        recorded ?? fallback
    }
    
    var body: some View {
        Group {
            switch exercise.type {
            case .hangboarding:
                HangboardingDetails(exercise: exercise, recordedExercise: recordedExercise)
            case .repeaters:
                RepeatersDetails(exercise: exercise, recordedExercise: recordedExercise)
            case .limitBouldering:
                LimitBoulderingDetails(exercise: exercise, recordedExercise: recordedExercise)
            case .nxn:
                NxNDetails(exercise: exercise, recordedExercise: recordedExercise)
            case .boulderCampus:
                BoulderCampusDetails(exercise: exercise, recordedExercise: recordedExercise)
            case .deadlifts:
                DeadliftsDetails(exercise: exercise, recordedExercise: recordedExercise)
            case .shoulderLifts:
                ShoulderLiftsDetails(exercise: exercise, recordedExercise: recordedExercise)
            case .pullups:
                PullupsDetails(exercise: exercise, recordedExercise: recordedExercise)
            case .boardClimbing:
                BoardClimbingDetails(exercise: exercise, recordedExercise: recordedExercise)
            case .edgePickups:
                EdgePickupsDetails(exercise: exercise, recordedExercise: recordedExercise)
            case .flexibility:
                FlexibilityDetails(exercise: exercise, recordedExercise: recordedExercise)
            case .running:
                RunningDetails(exercise: exercise, recordedExercise: recordedExercise)
            case .warmup:
                WarmupDetails(exercise: exercise, recordedExercise: recordedExercise)
            }
        }
    }
}

// MARK: - Exercise Detail Components

struct HangboardingDetails: View {
    let exercise: Exercise
    let recordedExercise: RecordedExercise?
    
    var body: some View {
        let grip = recordedExercise?.gripType ?? exercise.gripType ?? .halfCrimp
        let edgeSize = recordedExercise?.edgeSize ?? exercise.edgeSize ?? 20
        let duration = recordedExercise?.duration ?? exercise.duration ?? 10
        let reps = recordedExercise?.repetitions ?? exercise.repetitions ?? 6
        let sets = recordedExercise?.sets ?? exercise.sets ?? 3
        let weight = recordedExercise?.addedWeight ?? Int(exercise.addedWeight ?? 0)
        
        Text("\(grip.rawValue) - \(edgeSize)mm × \(duration)s × \(reps)r × \(sets)s × \(weight)kg")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .lineLimit(1)
    }
}

struct RepeatersDetails: View {
    let exercise: Exercise
    let recordedExercise: RecordedExercise?
    
    var body: some View {
        let duration = recordedExercise?.duration ?? exercise.duration ?? 7
        let reps = recordedExercise?.repetitions ?? exercise.repetitions ?? 6
        let sets = recordedExercise?.sets ?? exercise.sets ?? 3
        let weight = recordedExercise?.addedWeight ?? Int(exercise.addedWeight ?? 0)
        
        Text("\(duration)s × \(reps)r × \(sets)s × \(weight)kg")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .lineLimit(1)
    }
}

struct LimitBoulderingDetails: View {
    let exercise: Exercise
    let recordedExercise: RecordedExercise?
    
    var body: some View {
        let grade = recordedExercise?.grade ?? exercise.grade ?? "V8"
        let routes = recordedExercise?.routes ?? exercise.routes ?? 5
        let attempts = recordedExercise?.attempts ?? exercise.attempts ?? 3
        let rest = recordedExercise?.restBetweenRoutes ?? exercise.restBetweenRoutes ?? 3
        let duration = recordedExercise?.sessionDuration ?? exercise.sessionDuration ?? 30
        
        Text("\(grade) × \(routes)r × \(attempts)a × \(rest)m × \(duration)m")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .lineLimit(1)
    }
}

struct NxNDetails: View {
    let exercise: Exercise
    let recordedExercise: RecordedExercise?
    
    var body: some View {
        let grade = recordedExercise?.grade ?? exercise.grade ?? "V5"
        let routes = recordedExercise?.routes ?? exercise.routes ?? 4
        let sets = recordedExercise?.sets ?? exercise.sets ?? 4
        
        Text("\(grade) × \(routes)r × \(sets)s")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .lineLimit(1)
    }
}

struct BoulderCampusDetails: View {
    let exercise: Exercise
    let recordedExercise: RecordedExercise?
    
    var body: some View {
        let moves = recordedExercise?.moves ?? exercise.moves ?? 15
        let sets = recordedExercise?.sets ?? exercise.sets ?? 3
        let rest = recordedExercise?.restDuration ?? exercise.restDuration ?? 2
        
        Text("\(moves)m × \(sets)s × \(rest)m")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .lineLimit(1)
    }
}

struct DeadliftsDetails: View {
    let exercise: Exercise
    let recordedExercise: RecordedExercise?
    
    var body: some View {
        let reps = recordedExercise?.repetitions ?? exercise.repetitions ?? 5
        let sets = recordedExercise?.sets ?? exercise.sets ?? 3
        let weight = recordedExercise?.weight ?? Int(exercise.weight ?? 50)
        
        Text("\(reps)r × \(sets)s × \(weight)kg")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .lineLimit(1)
    }
}

struct ShoulderLiftsDetails: View {
    let exercise: Exercise
    let recordedExercise: RecordedExercise?
    
    var body: some View {
        let reps = recordedExercise?.repetitions ?? exercise.repetitions ?? 20
        let sets = recordedExercise?.sets ?? exercise.sets ?? 3
        let weight = recordedExercise?.weight ?? Int(exercise.weight ?? 10)
        let rest = recordedExercise?.restDuration ?? exercise.restDuration ?? 2
        
        Text("\(reps)r × \(sets)s × \(weight)kg × \(rest)m")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .lineLimit(1)
    }
}

struct PullupsDetails: View {
    let exercise: Exercise
    let recordedExercise: RecordedExercise?
    
    var body: some View {
        let reps = recordedExercise?.repetitions ?? exercise.repetitions ?? 5
        let sets = recordedExercise?.sets ?? exercise.sets ?? 3
        let weight = recordedExercise?.addedWeight ?? Int(exercise.addedWeight ?? 0)
        
        Text("\(reps)r × \(sets)s × \(weight)kg")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .lineLimit(1)
    }
}

struct BoardClimbingDetails: View {
    let exercise: Exercise
    let recordedExercise: RecordedExercise?
    
    var body: some View {
        let board = recordedExercise?.boardType ?? exercise.boardType ?? .moonBoard
        let grade = recordedExercise?.grade ?? exercise.grade ?? "V6"
        let routes = recordedExercise?.routes ?? exercise.routes ?? 5
        
        Text("\(board.rawValue) - \(grade) × \(routes)r")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .lineLimit(1)
    }
}

struct EdgePickupsDetails: View {
    let exercise: Exercise
    let recordedExercise: RecordedExercise?
    
    var body: some View {
        let duration = recordedExercise?.duration ?? exercise.duration ?? 15
        let sets = recordedExercise?.sets ?? exercise.sets ?? 6
        let weight = recordedExercise?.addedWeight ?? Int(exercise.addedWeight ?? 30)
        let edgeSize = recordedExercise?.edgeSize ?? exercise.edgeSize ?? 20
        let rest = recordedExercise?.restDuration ?? exercise.restDuration ?? 2
        
        Text("\(duration)s × \(sets)s × \(weight)kg × \(edgeSize)mm × \(rest)m")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .lineLimit(1)
    }
}

struct MaxHangsDetails: View {
    let exercise: Exercise
    let recordedExercise: RecordedExercise?
    
    var body: some View {
        let duration = recordedExercise?.duration ?? exercise.duration ?? 15
        let weight = recordedExercise?.addedWeight ?? Int(exercise.addedWeight ?? 20)
        let edgeSize = recordedExercise?.edgeSize ?? exercise.edgeSize ?? 20
        
        Text("\(duration)s × \(weight)kg × \(edgeSize)mm")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .lineLimit(1)
    }
}

struct FlexibilityDetails: View {
    let exercise: Exercise
    let recordedExercise: RecordedExercise?
    
    var body: some View {
        let areas = [
            (recordedExercise?.hamstrings ?? exercise.hamstrings) ? "H" : nil,
            (recordedExercise?.hips ?? exercise.hips) ? "Hp" : nil,
            (recordedExercise?.forearms ?? exercise.forearms) ? "F" : nil,
            (recordedExercise?.legs ?? exercise.legs) ? "L" : nil
        ].compactMap { $0 }
        
        if !areas.isEmpty {
            Text(areas.joined(separator: ", "))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

struct RunningDetails: View {
    let exercise: Exercise
    let recordedExercise: RecordedExercise?
    
    var body: some View {
        let hours = recordedExercise?.hours ?? exercise.hours ?? 0
        let minutes = recordedExercise?.minutes ?? exercise.minutes ?? 30
        let distance = recordedExercise?.distance ?? exercise.distance ?? 5.0
        
        Text("\(hours)h \(minutes)m × \(String(format: "%.2f", distance))km")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .lineLimit(1)
    }
}

struct WarmupDetails: View {
    let exercise: Exercise
    let recordedExercise: RecordedExercise?
    
    var body: some View {
        if let recorded = recordedExercise, !recorded.selectedDetailOptions.isEmpty {
            Text(recorded.selectedDetailOptions.joined(separator: ", "))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
        } else {
            let duration = recordedExercise?.duration ?? exercise.duration ?? 10
            Text("\(duration) min")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

struct AvailableExercisesGrid: View {
    let exercises: [Exercise]
    let onAddExercise: (Exercise) -> Void
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 30),
            GridItem(.flexible(), spacing: 30)
        ], spacing: 4) {
            ForEach(exercises) { exercise in
                ExerciseTile(exercise: exercise, onTap: { onAddExercise(exercise) })
                    .frame(height: 200)
            }
        }
        .padding(8)
    }
}


