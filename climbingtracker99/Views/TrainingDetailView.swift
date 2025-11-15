import SwiftUI
import SwiftData
import AVKit
import PhotosUI

struct TrainingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingExerciseManager = false
    @State private var showingContinueSession = false
    @State private var continueSnapshot: ActiveRecordingSnapshot?
    @State private var selectedImageItems: [PhotosPickerItem] = []
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var isProcessingMedia = false
    @State private var showingDeleteConfirmation = false
    let training: Training
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(training.date, style: .date)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text(training.date, style: .time)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Focus badge
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(training.focus.color)
                                    .frame(width: 10, height: 10)
                                Text(training.focus.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(training.focus.color)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(training.focus.color.opacity(0.15))
                            .cornerRadius(16)
                        }
                        
                        // Location and duration
                        HStack(spacing: 16) {
                            DetailStat(icon: training.location == .indoor ? "building.2.fill" : "tree.fill",
                                      title: training.location.rawValue,
                                      color: .blue)
                            
                            DetailStat(icon: "clock.fill",
                                      title: "\(training.duration) min",
                                      color: .green)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    
                    if training.isRecorded {
                        Button(action: {
                            if let snapshot = RecordingManager.shared.snapshot {
                                continueSnapshot = snapshot
                                RecordingManager.shared.snapshot = nil
                            } else {
                                continueSnapshot = nil
                            }
                            showingContinueSession = true
                        }) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                Text("Continue Training")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Exercises Summary
                    if !training.recordedExercises.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Exercises Completed")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            ForEach(training.recordedExercises) { exercise in
                                ExerciseDetailCard(exercise: exercise)
                            }
                        }
                    }
                    
                    mediaSection
                    
                    // Notes
                    if !training.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notes")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            Text(training.notes)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
                .onChange(of: selectedImageItems) { _, newItems in
                    handleSelectedImages(newItems)
                }
                .onChange(of: selectedVideoItem) { _, newItem in
                    handleSelectedVideo(newItem)
                }
            }
            .navigationTitle("Training Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        if let snapshot = RecordingManager.shared.snapshot {
                            continueSnapshot = snapshot
                            RecordingManager.shared.snapshot = nil
                        } else {
                            continueSnapshot = nil
                        }
                        showingContinueSession = true
                    } label: {
                        Image(systemName: "play.circle.fill")
                    }
                    Button {
                        showingExerciseManager = true
                    } label: {
                        Label("Manage Exercises", systemImage: "square.and.pencil")
                    }
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    Button("Done") {
                        do {
                            try modelContext.save()
                        } catch {
                            print("Error saving training changes: \(error.localizedDescription)")
                        }
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingExerciseManager) {
                ManageTrainingExercisesView(training: training)
            }
            .sheet(isPresented: $showingContinueSession, onDismiss: {
                continueSnapshot = nil
            }) {
                if let snapshot = continueSnapshot {
                    RecordTrainingView(training: snapshot.training ?? training, snapshot: snapshot)
                } else {
                    RecordTrainingView(training: training)
                }
            }
        }
        .alert("Delete Training?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(training)
                do {
                    try modelContext.save()
                } catch {
                    print("Failed to delete training: \(error.localizedDescription)")
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the training and its media from your history.")
        }
    }
}

// MARK: - Media Management

extension TrainingDetailView {
    @ViewBuilder
    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Media")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                if isProcessingMedia {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if training.media.isEmpty {
                Text("No media yet. Add photos or videos to capture the session.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(training.media) { media in
                            MediaCard(media: media) {
                                removeMedia(media)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack(spacing: 16) {
                PhotosPicker(selection: $selectedImageItems, matching: .images) {
                    mediaAddButton(icon: "photo.on.rectangle.angled", title: "Add Photos")
                }
                PhotosPicker(selection: $selectedVideoItem, matching: .videos) {
                    mediaAddButton(icon: "video.fill", title: "Add Video")
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    @ViewBuilder
    private func mediaAddButton(icon: String, title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
            Text(title)
                .font(.caption)
        }
        .frame(width: 70, height: 70)
        .background(Color.blue.opacity(0.12))
        .foregroundColor(.blue)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func handleSelectedImages(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            await setProcessing(true)
            for item in items {
                await handleMediaSelection(item, type: .image)
            }
            await MainActor.run {
                selectedImageItems.removeAll()
            }
            await setProcessing(false)
            FirebaseSyncManager.shared.triggerFullSync()
        }
    }

    private func handleSelectedVideo(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            await setProcessing(true)
            await handleMediaSelection(item, type: .video)
            await MainActor.run {
                selectedVideoItem = nil
            }
            await setProcessing(false)
            FirebaseSyncManager.shared.triggerFullSync()
        }
    }

    private func setProcessing(_ value: Bool) async {
        await MainActor.run {
            isProcessingMedia = value
        }
    }

    private func handleMediaSelection(_ item: PhotosPickerItem, type: MediaType) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            var newMedia: Media
            if type == .video {
                newMedia = Media(type: .video, videoData: data)
                if let thumb = try await newMedia.generateThumbnail() {
                    newMedia.thumbnailData = thumb
                }
            } else {
                newMedia = Media(type: .image, imageData: data)
            }
            await MainActor.run {
                appendMedia(newMedia)
            }
        } catch {
            print("Error handling media selection: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func appendMedia(_ media: Media) {
        media.training = training
        if !training.media.contains(where: { $0.id == media.id }) {
            training.media.append(media)
        }
        modelContext.insert(media)
        do {
            try modelContext.save()
            // Upload immediately to Firebase
            Task {
                await FirebaseSyncManager.shared.uploadMediaImmediately(media: media, context: modelContext)
            }
            // Also trigger full sync to update activity feed
            FirebaseSyncManager.shared.triggerFullSync()
        } catch {
            print("Error saving media: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func removeMedia(_ media: Media) {
        if let index = training.media.firstIndex(where: { $0.id == media.id }) {
            training.media.remove(at: index)
        }
        modelContext.delete(media)
        Task {
            await FirebaseSyncManager.shared.deleteRemoteMediaIfNeeded(media: media)
        }
        do {
            try modelContext.save()
            FirebaseSyncManager.shared.triggerFullSync()
        } catch {
            print("Error removing media: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Views

struct DetailStat: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
        .cornerRadius(12)
    }
}

struct ExerciseDetailCard: View {
    let exercise: RecordedExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Exercise image
                Image(exercise.exercise.type.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.exercise.type.displayName)
                        .font(.headline)
                    
                    if let focus = exercise.exercise.focus {
                         Text(focus.rawValue)
                            .font(.caption)
                            .foregroundColor(focus.color)
                    }
                }
                
                Spacer()
            }
            
            // Exercise details based on type
            RecordedExerciseDetailsView(exercise: exercise)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Manage Exercises

private struct ManageTrainingExercisesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allExercises: [Exercise]
    @Bindable var training: Training
    @State private var editingExercise: RecordedExercise?
    @State private var continuingExercise: RecordedExercise?
    @State private var showingExerciseSelection = false
    @State private var saveError: String?
    
    private var recordedExercises: [RecordedExercise] {
        training.recordedExercises
            .sorted { lhs, rhs in
                lhs.exercise.type < rhs.exercise.type
            }
    }
    
    private var selectableExercises: [Exercise] {
        allExercises.sorted { $0.type < $1.type }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if let message = saveError {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                if recordedExercises.isEmpty {
                    Section {
                        VStack(spacing: 8) {
                            Image(systemName: "figure.climbing")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No recorded exercises yet.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Tap + to add exercises to this training session.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                    }
                } else {
                    Section {
                        ForEach(recordedExercises) { recorded in
                            ManageRecordedExerciseRow(
                                recordedExercise: recorded,
                                onEdit: { editingExercise = recorded },
                                onContinue: { beginContinuation(for: recorded) },
                                onDelete: { deleteExercise(recorded) }
                            )
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    beginContinuation(for: recorded)
                                } label: {
                                    Label("Continue", systemImage: "play.circle")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteExercise(recorded)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    editingExercise = recorded
                                } label: {
                                    Label("Edit", systemImage: "square.and.pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Manage Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { saveAndDismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !selectableExercises.isEmpty {
                        Button {
                            showingExerciseSelection = true
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingExerciseSelection) {
                ExerciseSelectionSheet(exercises: selectableExercises) { exercise in
                    addExercise(exercise)
                    showingExerciseSelection = false
                }
            }
            .sheet(item: $editingExercise) { recorded in
                RecordedExerciseEditView(recordedExercise: recorded)
            }
            .sheet(item: $continuingExercise) { recorded in
                ContinueRecordedExerciseView(recordedExercise: recorded)
            }
        }
        .onDisappear {
            try? modelContext.save()
        }
    }
    
    private func saveAndDismiss() {
        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
    
    private func addExercise(_ exercise: Exercise) {
        let recorded = RecordedExercise(exercise: exercise)
        recorded.recordedStartTime = Date()
        recorded.isCompleted = false
        training.recordedExercises.append(recorded)
        modelContext.insert(recorded)
        beginContinuation(for: recorded)
    }
    
    private func deleteExercise(_ recorded: RecordedExercise) {
        if let index = training.recordedExercises.firstIndex(where: { $0.persistentModelID == recorded.persistentModelID }) {
            training.recordedExercises.remove(at: index)
        }
        modelContext.delete(recorded)
    }
    
    private func beginContinuation(for recorded: RecordedExercise) {
        recorded.recordedStartTime = Date()
        recorded.recordedEndTime = nil
        recorded.pausedDuration = 0
        recorded.isCompleted = false
        continuingExercise = recorded
    }
}

private struct ManageRecordedExerciseRow: View {
    let recordedExercise: RecordedExercise
    let onEdit: () -> Void
    let onContinue: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(recordedExercise.exercise.type.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 52, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text(recordedExercise.exercise.type.displayName)
                    .font(.headline)
                if let duration = recordedExercise.recordedDuration {
                    Text("Duration: \(formatDuration(duration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let notes = recordedExercise.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Menu {
                Button(action: onContinue) {
                    Label("Continue", systemImage: "play.circle")
                }
                Button(action: onEdit) {
                    Label("Edit", systemImage: "square.and.pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

private struct RecordedExerciseEditView: View {
    @ObservedObject var recordedExercise: RecordedExercise
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ExerciseFormView(
                exercise: recordedExercise.exercise,
                recordedExercise: recordedExercise,
                isRecording: true
            )
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ContinueRecordedExerciseView: View {
    @ObservedObject var recordedExercise: RecordedExercise
    @Environment(\.dismiss) private var dismiss
    @State private var isPresented = true
    
    var body: some View {
        NavigationStack {
            ExerciseRecordView(recordedExercise: recordedExercise, isPresented: $isPresented)
        }
        .onChange(of: isPresented) { _, newValue in
            if !newValue {
                finalizeContinuation()
                dismiss()
            }
        }
    }
    
    private func finalizeContinuation() {
        recordedExercise.isCompleted = true
        recordedExercise.recordedEndTime = Date()
    }
}

struct RecordedExerciseDetailsView: View {
    let exercise: RecordedExercise
    
    // Helper to format duration - convert seconds to minutes if > 60
    private func formatDuration(_ seconds: Int) -> String {
        if seconds >= 60 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds > 0 {
                return "\(minutes)m \(remainingSeconds)s"
            } else {
                return "\(minutes) min"
            }
        } else {
            return "\(seconds)s"
        }
    }
    
    // Campusing sets view - parses notes for set details
    @ViewBuilder
    private var campusingSetsView: some View {
        if let notes = exercise.notes, !notes.isEmpty {
            let setsDetail = String(notes.dropFirst("Campusing: ".count))
            let sets = Array(setsDetail.split(separator: ";"))
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Sets Breakdown")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                ForEach(sets.indices, id: \.self) { index in
                    Text(sets[index].trimmingCharacters(in: .whitespaces))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch exercise.exercise.type {
            case .hangboarding:
                if let grip = exercise.gripType,
                   let edgeSize = exercise.edgeSize,
                   let sets = exercise.sets {
                    DetailRow(label: "Grip", value: grip.rawValue)
                    DetailRow(label: "Edge Size", value: "\(edgeSize)mm")
                    if let duration = exercise.recordedDuration ?? exercise.duration {
                        DetailRow(label: "Duration", value: formatDuration(duration))
                    }
                    DetailRow(label: "Sets", value: "\(sets)")
                    if let weight = exercise.addedWeight, weight > 0 {
                        DetailRow(label: "Added Weight", value: "\(weight)kg")
                    }
                    
                    // Show detailed sets if maxHangsSetsData exists
                    if !exercise.maxHangsSetsData.isEmpty {
                        if let sets = parseMaxHangsSets() {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Sets Breakdown")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                                    HStack {
                                        Text("Set \(index + 1)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(set.duration)s × \(set.edgeSize)mm")
                                            .font(.caption)
                                        if set.addedWeight > 0 {
                                            Text("+\(set.addedWeight)kg")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                
            case .repeaters:
                if let duration = exercise.duration,
                   let reps = exercise.repetitions,
                   let sets = exercise.sets {
                    DetailRow(label: "Hang Time", value: formatDuration(duration))
                    DetailRow(label: "Repetitions", value: "\(reps)")
                    DetailRow(label: "Sets", value: "\(sets)")
                    if let weight = exercise.addedWeight, weight > 0 {
                        DetailRow(label: "Added Weight", value: "\(weight)kg")
                    }
                    
                    // Show detailed sets if repeatersSetsData exists
                    if !exercise.repeatersSetsData.isEmpty {
                        if let sets = parseRepeatersSets() {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Sets Breakdown")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                                    HStack {
                                        Text("Set \(index + 1)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(set.hangTime)s hang / \(set.restTime)s rest")
                                            .font(.caption)
                                        Text("× \(set.repeats) reps")
                                            .font(.caption)
                                        if set.addedWeight > 0 {
                                            Text("+\(set.addedWeight)kg")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                
            case .edgePickups:
                if let duration = exercise.duration,
                   let sets = exercise.sets {
                    DetailRow(label: "Hang Time", value: formatDuration(duration))
                    DetailRow(label: "Sets", value: "\(sets)")
                    if let edgeSize = exercise.edgeSize {
                        DetailRow(label: "Edge Size", value: "\(edgeSize)mm")
                    }
                    if let grip = exercise.gripType {
                        DetailRow(label: "Grip Type", value: grip.rawValue)
                    }
                    if let weight = exercise.addedWeight, weight > 0 {
                        DetailRow(label: "Added Weight", value: "\(weight)kg")
                    }
                    
                    // Show detailed sets if edgePickupsSetsData exists
                    if !exercise.edgePickupsSetsData.isEmpty {
                        if let sets = parseEdgePickupsSets() {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Sets Breakdown")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                                    HStack {
                                        Text("Set \(index + 1)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(set.hangTime)s / \(set.restTime)s × \(set.repeats)")
                                            .font(.caption)
                                        Text(set.gripType)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if set.addedWeight > 0 {
                                            Text("+\(set.addedWeight)kg")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                
            case .running:
                if let distance = exercise.distance {
                    DetailRow(label: "Distance", value: String(format: "%.2f km", distance))
                }
                if let hours = exercise.hours, let minutes = exercise.minutes {
                    DetailRow(label: "Duration", value: "\(hours)h \(minutes)m")
                }
                if let recordedDuration = exercise.recordedDuration {
                    DetailRow(label: "Recorded Duration", value: formatDuration(recordedDuration))
                }
                
            case .pullups:
                // Show detailed sets if pullupSetsData exists
                if !exercise.pullupSetsData.isEmpty {
                    if let sets = parsePullupSets() {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sets Breakdown")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                                HStack {
                                    Text("Set \(index + 1)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(set.reps) reps")
                                        .font(.caption)
                                    if set.weight > 0 {
                                        Text("+\(set.weight)kg")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if set.restDuration > 0 {
                                        Text("(\(set.restDuration)s rest)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                } else if let reps = exercise.repetitions, let sets = exercise.sets {
                    DetailRow(label: "Reps", value: "\(reps)")
                    DetailRow(label: "Sets", value: "\(sets)")
                    if let weight = exercise.addedWeight, weight > 0 {
                        DetailRow(label: "Added Weight", value: "\(weight)kg")
                    }
                }
                
            case .deadlifts:
                // Show detailed sets if deadliftsSetsData exists
                if !exercise.deadliftsSetsData.isEmpty {
                    if let sets = parseDeadliftSets() {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sets Breakdown")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                                HStack {
                                    Text("Set \(index + 1)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(set.reps) reps × \(set.weight)kg")
                                        .font(.caption)
                                    if set.restDuration > 0 {
                                        Text("(\(set.restDuration)s rest)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                } else if let reps = exercise.repetitions, let sets = exercise.sets {
                    DetailRow(label: "Reps", value: "\(reps)")
                    DetailRow(label: "Sets", value: "\(sets)")
                    if let weight = exercise.weight {
                        DetailRow(label: "Weight", value: "\(weight)kg")
                    }
                }
                
            case .shoulderLifts:
                // Show detailed sets if shoulderLiftsSetsData exists
                if !exercise.shoulderLiftsSetsData.isEmpty {
                    if let sets = parseShoulderLiftSets() {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sets Breakdown")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                                HStack {
                                    Text("Set \(index + 1)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(set.reps) reps × \(set.weight)kg")
                                        .font(.caption)
                                    if set.restDuration > 0 {
                                        Text("(\(set.restDuration)s rest)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                } else if let reps = exercise.repetitions, let sets = exercise.sets {
                    DetailRow(label: "Reps", value: "\(reps)")
                    DetailRow(label: "Sets", value: "\(sets)")
                    if let weight = exercise.weight {
                        DetailRow(label: "Weight", value: "\(weight)kg")
                    }
                }
                
            case .boardClimbing:
                // Show detailed routes if boardClimbingRoutesData exists
                if !exercise.boardClimbingRoutesData.isEmpty {
                    if let routes = parseBoardClimbingRoutes() {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Routes")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            ForEach(routes) { route in
                                HStack {
                                    Text(route.boardType)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("Grade: \(route.grade)")
                                        .font(.caption)
                                    Text("\(route.tries) tries")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if route.sent {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                    }
                }
                            }
                        }
                        .padding(.top, 4)
                    }
                } else {
                    // Fallback to basic info if no detailed data
                    if let boardType = exercise.boardType {
                        DetailRow(label: "Board Type", value: boardType.rawValue)
                    }
                if let grade = exercise.grade {
                    DetailRow(label: "Grade", value: grade)
                }
                if let routes = exercise.routes {
                    DetailRow(label: "Routes", value: "\(routes)")
                }
                if let attempts = exercise.attempts {
                    DetailRow(label: "Attempts", value: "\(attempts)")
                }
                }
                
            case .limitBouldering:
                // Show detailed routes if limitBoulderingRoutesData exists
                if !exercise.limitBoulderingRoutesData.isEmpty {
                    if let routes = parseLimitBoulderingRoutes() {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Boulders")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            ForEach(routes) { route in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(route.boulderType)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text("Grade: \(route.grade)")
                                            .font(.caption)
                                        Text("\(route.tries) tries")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if route.sent {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                    }
                                    if let name = route.name, !name.isEmpty {
                                        Text(name)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .italic()
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                } else {
                    // Fallback to basic info
                    if let grade = exercise.grade {
                        DetailRow(label: "Grade", value: grade)
                    }
                    if let routes = exercise.routes {
                        DetailRow(label: "Routes", value: "\(routes)")
                    }
                    if let attempts = exercise.attempts {
                        DetailRow(label: "Attempts", value: "\(attempts)")
                    }
                }
                
            case .nxn:
                if let routes = exercise.routes,
                   let sets = exercise.sets {
                    DetailRow(label: "Problems per Set", value: "\(routes)")
                    DetailRow(label: "Sets", value: "\(sets)")
                }
                
                // Show detailed sets if nxnSetsData exists
                if !exercise.nxnSetsData.isEmpty {
                    if let sets = parseNxNSets() {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sets Breakdown")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text("Set \(index + 1)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Spacer()
                                        if set.completed {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                        if set.restDuration > 0 {
                                            Text("\(set.restDuration)s rest")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    if !set.grades.isEmpty {
                                        Text("Grades: \(set.grades.joined(separator: ", "))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                
            case .boulderCampus:
                if let sets = exercise.sets {
                    DetailRow(label: "Sets", value: "\(sets)")
                }
                
                // Show detailed sets if boulderCampusSetsData exists
                if !exercise.boulderCampusSetsData.isEmpty {
                    if let sets = parseBoulderCampusSets() {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sets Breakdown")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                                HStack {
                                    Text("Set \(index + 1)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(set.moves) moves")
                                        .font(.caption)
                                    if set.restDuration > 0 {
                                        Text("(\(set.restDuration)s rest)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                
            case .campusing:
                if let sets = exercise.sets {
                    DetailRow(label: "Sets", value: "\(sets)")
                }
                if let edgeSize = exercise.edgeSize {
                    DetailRow(label: "Edge Size", value: "\(edgeSize)mm")
                }
                if let rest = exercise.restDuration {
                    DetailRow(label: "Rest Time", value: formatDuration(rest))
                }
                
                // Campusing stores detailed set data in notes
                if let notes = exercise.notes, !notes.isEmpty, notes.hasPrefix("Campusing:") {
                    campusingSetsView
                }
                
            case .circuit:
                // Use recordedDuration if available (for recorded exercises)
                if let duration = exercise.recordedDuration ?? exercise.duration {
                    DetailRow(label: "Duration", value: formatDuration(duration))
                }
                if let sets = exercise.sets {
                    DetailRow(label: "Sets", value: "\(sets)")
                }
                if let moves = exercise.moves {
                    DetailRow(label: "Moves per Set", value: "\(moves)")
                }
                if let grade = exercise.grade {
                    DetailRow(label: "Difficulty", value: grade)
                }
                if let rest = exercise.restDuration {
                    DetailRow(label: "Rest Time", value: formatDuration(rest))
                }
                
                // Circuit stores detailed data in notes
                if let notes = exercise.notes, !notes.isEmpty, (notes.hasPrefix("Circuit:") || notes.hasPrefix("Time Based Circuit:")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Workout Details")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                
            case .core:
                if let duration = exercise.duration {
                    DetailRow(label: "Training Time", value: formatDuration(duration))
                }
                if let sets = exercise.sets {
                    DetailRow(label: "Sets", value: "\(sets)")
                }
                if let rest = exercise.restDuration {
                    DetailRow(label: "Rest Time", value: formatDuration(rest))
                }
                
            case .flexibility, .warmup:
                // Use recordedDuration if available (for recorded exercises)
                if let duration = exercise.recordedDuration ?? exercise.duration {
                    DetailRow(label: "Duration", value: formatDuration(duration))
                }
                
                // Show selected areas if available
                if !exercise.selectedDetailOptions.isEmpty {
                    DetailRow(label: "Areas", value: exercise.selectedDetailOptions.joined(separator: ", "))
                }
                
                // Flexibility-specific fields
                if exercise.hamstrings {
                    DetailRow(label: "Hamstrings", value: "Yes")
                }
                if exercise.hips {
                    DetailRow(label: "Hips", value: "Yes")
                }
                if exercise.forearms {
                    DetailRow(label: "Forearms", value: "Yes")
                }
                if exercise.legs {
                    DetailRow(label: "Legs", value: "Yes")
                }
                
            case .benchmark:
                // Show benchmark results if available
                if !exercise.benchmarkResultsData.isEmpty {
                    if let results = parseBenchmarkResults() {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Benchmark Results")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                                if let type = BenchmarkType(rawValue: result.benchmarkType) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(type.displayName)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        HStack {
                                            Text(String(format: "%.1f", result.value1))
                                                .font(.caption)
                                            Text(type.unit)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            if let value2 = result.value2 {
                                                Spacer()
                                                Text("R: \(String(format: "%.1f", value2))")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                } else {
                    Text("No benchmark results recorded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func parseBenchmarkResults() -> [(benchmarkType: String, value1: Double, value2: Double?, date: String)]? {
        guard !exercise.benchmarkResultsData.isEmpty,
              let data = exercise.benchmarkResultsData.data(using: .utf8),
              let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        
        return results.compactMap { result in
            guard let type = result["benchmarkType"] as? String,
                  let value1 = result["value1"] as? Double else {
                return nil as (benchmarkType: String, value1: Double, value2: Double?, date: String)?
            }
            let value2 = result["value2"] as? Double
            let date = result["date"] as? String ?? ""
            return (benchmarkType: type, value1: value1, value2: value2, date: date)
        }
    }
    
    // MARK: - JSON Parsing Helpers
    
    private func parseMaxHangsSets() -> [MaxHangSet]? {
        guard !exercise.maxHangsSetsData.isEmpty,
              let data = exercise.maxHangsSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([MaxHangSet].self, from: data) else {
            return nil
        }
        return sets
    }
    
    private func parseRepeatersSets() -> [RepeaterSet]? {
        guard !exercise.repeatersSetsData.isEmpty,
              let data = exercise.repeatersSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([RepeaterSet].self, from: data) else {
            return nil
        }
        return sets
    }
    
    private func parseEdgePickupsSets() -> [EdgePickupSet]? {
        guard !exercise.edgePickupsSetsData.isEmpty,
              let data = exercise.edgePickupsSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([EdgePickupSet].self, from: data) else {
            return nil
        }
        return sets
    }
    
    private func parsePullupSets() -> [PullupSet]? {
        guard !exercise.pullupSetsData.isEmpty,
              let data = exercise.pullupSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([PullupSet].self, from: data) else {
            return nil
        }
        return sets
    }
    
    private func parseDeadliftSets() -> [DeadliftSet]? {
        guard !exercise.deadliftsSetsData.isEmpty,
              let data = exercise.deadliftsSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([DeadliftSet].self, from: data) else {
            return nil
        }
        return sets
    }
    
    private func parseShoulderLiftSets() -> [ShoulderLiftSet]? {
        guard !exercise.shoulderLiftsSetsData.isEmpty,
              let data = exercise.shoulderLiftsSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([ShoulderLiftSet].self, from: data) else {
            return nil
        }
        return sets
    }
    
    private func parseBoardClimbingRoutes() -> [BoardClimbingRoute]? {
        guard !exercise.boardClimbingRoutesData.isEmpty,
              let data = exercise.boardClimbingRoutesData.data(using: .utf8),
              let routes = try? JSONDecoder().decode([BoardClimbingRoute].self, from: data) else {
            return nil
        }
        return routes
    }
    
    private func parseLimitBoulderingRoutes() -> [LimitBoulderingRoute]? {
        guard !exercise.limitBoulderingRoutesData.isEmpty,
              let data = exercise.limitBoulderingRoutesData.data(using: .utf8),
              let routes = try? JSONDecoder().decode([LimitBoulderingRoute].self, from: data) else {
            return nil
        }
        return routes
    }
    
    private func parseNxNSets() -> [NxNSet]? {
        guard !exercise.nxnSetsData.isEmpty,
              let data = exercise.nxnSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([NxNSet].self, from: data) else {
            return nil
        }
        return sets
    }
    
    private func parseBoulderCampusSets() -> [BoulderCampusSet]? {
        guard !exercise.boulderCampusSetsData.isEmpty,
              let data = exercise.boulderCampusSetsData.data(using: .utf8),
              let sets = try? JSONDecoder().decode([BoulderCampusSet].self, from: data) else {
            return nil
        }
        return sets
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct MediaCard: View {
    let media: Media
    var onDelete: (() -> Void)? = nil
    @State private var showingFullMedia = false
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Group {
            if let thumbnail = media.thumbnail {
                thumbnail
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        showingFullMedia = true
                    }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
        }
        .overlay(alignment: .topTrailing) {
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                        .padding(6)
                        .background(Color.black.opacity(0.35))
                        .clipShape(Circle())
                }
                .padding(6)
            }
        }
        .overlay(alignment: .bottomLeading) {
            // Upload status indicator
            uploadStatusIndicator
                .padding(6)
        }
        .contextMenu {
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
            if media.hasUploadFailed {
                Button {
                    Task {
                        await FirebaseSyncManager.shared.retryMediaUpload(media: media, context: modelContext)
                    }
                } label: {
                    Label("Retry Upload", systemImage: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showingFullMedia) {
            MediaFullView(media: media)
        }
    }
    
    @ViewBuilder
    private var uploadStatusIndicator: some View {
        switch media.uploadStateEnum {
        case .uploading:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(.white)
                if let progress = media.uploadProgress {
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
            .padding(6)
            .background(Color.blue.opacity(0.8))
            .clipShape(Capsule())
        case .uploaded:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding(6)
                .background(Color.green.opacity(0.8))
                .clipShape(Circle())
        case .failed:
            Button {
                Task {
                    await FirebaseSyncManager.shared.retryMediaUpload(media: media, context: modelContext)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text("Retry")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.8))
                .clipShape(Capsule())
            }
        case .pending:
            if !media.isUploaded {
                Image(systemName: "clock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.orange.opacity(0.8))
                    .clipShape(Circle())
            }
        }
    }
}

struct MediaFullView: View {
    let media: Media
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if media.type == .image, let image = media.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else if media.type == .video, let videoURL = media.videoURL {
                    VideoPlayer(player: AVPlayer(url: videoURL))
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

