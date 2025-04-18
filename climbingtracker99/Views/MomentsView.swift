import SwiftUI
import SwiftData
import PhotosUI

struct MomentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trainings: [Training]
    
    @State private var selectedMedia: Media?
    @State private var showingMediaDetail = false
    @State private var gridLayout: [GridItem] = Array(repeating: .init(.flexible()), count: 3)
    @State private var searchText = ""
    @State private var selectedFocus: TrainingFocus?
    @State private var selectedLocation: TrainingLocation?
    
    private var allMedia: [Media] {
        trainings.flatMap { $0.media }
            .sorted { $0.date > $1.date }
    }
    
    private var filteredMedia: [Media] {
        var filtered = allMedia
        
        // Apply focus filter
        if let focus = selectedFocus {
            filtered = filtered.filter { media in
                media.training?.focus == focus
            }
        }
        
        // Apply location filter
        if let location = selectedLocation {
            filtered = filtered.filter { media in
                media.training?.location == location
            }
        }
        
        // Apply search text filter
        if !searchText.isEmpty {
            filtered = filtered.filter { media in
                if let training = media.training {
                    return training.notes.localizedCaseInsensitiveContains(searchText) ||
                           training.focus.rawValue.localizedCaseInsensitiveContains(searchText) ||
                           training.location.rawValue.localizedCaseInsensitiveContains(searchText)
                }
                return false
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TabHeaderView(title: "Moments") {
                    Menu {
                        Button(action: { gridLayout = Array(repeating: .init(.flexible()), count: 2) }) {
                            Label("2 Columns", systemImage: "rectangle.grid.2x2")
                        }
                        Button(action: { gridLayout = Array(repeating: .init(.flexible()), count: 3) }) {
                            Label("3 Columns", systemImage: "rectangle.grid.3x2")
                        }
                        Button(action: { gridLayout = Array(repeating: .init(.flexible()), count: 4) }) {
                            Label("4 Columns", systemImage: "rectangle.grid.4x3")
                        }
                    } label: {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 24))
                    }
                }
                
                // Filter Buttons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Focus Filters
                        ForEach(TrainingFocus.allCases, id: \.self) { focus in
                            Button(action: {
                                selectedFocus = selectedFocus == focus ? nil : focus
                            }) {
                                Text(focus.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedFocus == focus ? focus.color : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedFocus == focus ? .white : .primary)
                                    .cornerRadius(15)
                            }
                        }
                        
                        // Location Filters
                        ForEach(TrainingLocation.allCases, id: \.self) { location in
                            Button(action: {
                                selectedLocation = selectedLocation == location ? nil : location
                            }) {
                                Text(location.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedLocation == location ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedLocation == location ? .white : .primary)
                                    .cornerRadius(15)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemBackground))
                
                // Grid View
                ScrollView {
                    LazyVGrid(columns: gridLayout, spacing: 2) {
                        ForEach(filteredMedia) { media in
                            if let image = media.thumbnail {
                                GeometryReader { geometry in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: geometry.size.width, height: geometry.size.width)
                                        .clipped()
                                        .overlay(
                                            VStack {
                                                HStack {
                                                    if let training = media.training {
                                                        Circle()
                                                            .fill(training.focus.color)
                                                            .frame(width: 8, height: 8)
                                                            .padding(4)
                                                            .background(Color.black.opacity(0.5))
                                                            .cornerRadius(8)
                                                    }
                                                    Spacer()
                                                }
                                                .padding(.top, 4)
                                                .padding(.leading, 4)
                                                
                                                Spacer()
                                                
                                                HStack {
                                                    if let training = media.training {
                                                        Text(training.date, style: .date)
                                                            .font(.caption2)
                                                            .foregroundColor(.white)
                                                            .padding(4)
                                                            .background(Color.black.opacity(0.5))
                                                            .cornerRadius(4)
                                                    }
                                                    Spacer()
                                                }
                                                .padding(4)
                                            }
                                        )
                                        .onTapGesture {
                                            selectedMedia = media
                                            showingMediaDetail = true
                                        }
                                }
                                .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .searchable(text: $searchText, prompt: "Search by date, focus, or location")
            .sheet(item: $selectedMedia) { media in
                MediaDetailView(media: media)
            }
        }
    }
}

struct MediaDetailView: View {
    let media: Media
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGFloat = 0
    @State private var currentIndex: Int = 0
    
    private var allMedia: [Media] {
        media.training?.media.sorted { $0.date > $1.date } ?? []
    }
    
    private var currentMedia: Media {
        allMedia[currentIndex]
    }
    
    private func nextImage() {
        withAnimation {
            if currentIndex < allMedia.count - 1 {
                currentIndex += 1
                scale = 1.0
            }
        }
    }
    
    private func previousImage() {
        withAnimation {
            if currentIndex > 0 {
                currentIndex -= 1
                scale = 1.0
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if let image = currentMedia.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(x: offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale = min(max(scale * delta, 1), 4)
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        offset = value.translation.width
                                    }
                                    .onEnded { value in
                                        let threshold: CGFloat = 50
                                        if value.translation.width > threshold {
                                            previousImage()
                                        } else if value.translation.width < -threshold {
                                            nextImage()
                                        }
                                        offset = 0
                                    }
                            )
                        )
                }
                
                if let training = currentMedia.training {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Training Details")
                            .font(.headline)
                            .padding(.top)
                        
                        HStack {
                            Text("Date:")
                            Spacer()
                            Text(training.date, style: .date)
                        }
                        
                        HStack {
                            Text("Location:")
                            Spacer()
                            Text(training.location.rawValue)
                        }
                        
                        HStack {
                            Text("Focus:")
                            Spacer()
                            Text(training.focus.rawValue)
                                .foregroundColor(training.focus.color)
                        }
                        
                        if !training.notes.isEmpty {
                            Text("Notes:")
                                .font(.headline)
                                .padding(.top)
                            Text(training.notes)
                        }
                    }
                    .padding()
                }
                
                // Page indicator
                if allMedia.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<allMedia.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Color.primary : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: previousImage) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                    }
                    .disabled(currentIndex == 0)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: nextImage) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                    }
                    .disabled(currentIndex == allMedia.count - 1)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("\(currentIndex + 1) of \(allMedia.count)")
                        .font(.subheadline)
                }
            }
        }
    }
} 