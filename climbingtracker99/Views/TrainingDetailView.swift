import SwiftUI
import SwiftData
import AVKit

struct TrainingDetailView: View {
    @Environment(\.dismiss) private var dismiss
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
                    
                    // Media section
                    if !training.media.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Media")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(training.media) { media in
                                        MediaCard(media: media)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
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
            }
            .navigationTitle("Training Details")
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

struct RecordedExerciseDetailsView: View {
    let exercise: RecordedExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch exercise.exercise.type {
            case .hangboarding:
                if let grip = exercise.gripType,
                   let edgeSize = exercise.edgeSize,
                   let duration = exercise.duration,
                   let sets = exercise.sets {
                    DetailRow(label: "Grip", value: grip.rawValue)
                    DetailRow(label: "Edge Size", value: "\(edgeSize)mm")
                    DetailRow(label: "Duration", value: "\(duration)s")
                    DetailRow(label: "Sets", value: "\(sets)")
                    if let weight = exercise.addedWeight, weight > 0 {
                        DetailRow(label: "Added Weight", value: "\(weight)kg")
                    }
                }
                
            case .repeaters:
                if let duration = exercise.duration,
                   let reps = exercise.repetitions,
                   let sets = exercise.sets {
                    DetailRow(label: "Hang Time", value: "\(duration)s")
                    DetailRow(label: "Repetitions", value: "\(reps)")
                    DetailRow(label: "Sets", value: "\(sets)")
                    if let weight = exercise.addedWeight, weight > 0 {
                        DetailRow(label: "Added Weight", value: "\(weight)kg")
                    }
                }
                
            case .running:
                if let distance = exercise.distance {
                    DetailRow(label: "Distance", value: String(format: "%.2f km", distance))
                }
                if let hours = exercise.hours, let minutes = exercise.minutes {
                    DetailRow(label: "Duration", value: "\(hours)h \(minutes)m")
                }
                
            case .pullups, .deadlifts, .shoulderLifts:
                if let reps = exercise.repetitions,
                   let sets = exercise.sets {
                    DetailRow(label: "Reps", value: "\(reps)")
                    DetailRow(label: "Sets", value: "\(sets)")
                    if let weight = exercise.weight {
                        DetailRow(label: "Weight", value: "\(weight)kg")
                    } else if let addedWeight = exercise.addedWeight {
                        DetailRow(label: "Added Weight", value: "\(addedWeight)kg")
                    }
                }
                
            case .limitBouldering, .boardClimbing:
                if let grade = exercise.grade {
                    DetailRow(label: "Grade", value: grade)
                }
                if let routes = exercise.routes {
                    DetailRow(label: "Routes", value: "\(routes)")
                }
                if let attempts = exercise.attempts {
                    DetailRow(label: "Attempts", value: "\(attempts)")
                }
                
            default:
                // Generic details for other exercise types
                if let duration = exercise.duration {
                    DetailRow(label: "Duration", value: "\(duration)s")
                }
                if let sets = exercise.sets {
                    DetailRow(label: "Sets", value: "\(sets)")
                }
            }
        }
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
    @State private var showingFullMedia = false
    
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
        .sheet(isPresented: $showingFullMedia) {
            MediaFullView(media: media)
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

