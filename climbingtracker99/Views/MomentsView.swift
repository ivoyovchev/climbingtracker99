import SwiftUI
import SwiftData
import PhotosUI
import AVKit

struct MediaFilter {
    let allMedia: [Media]
    let selectedTab: MediaType
    let selectedFocus: TrainingFocus?
    let selectedLocation: TrainingLocation?
    let searchText: String
    
    func filtered() -> [Media] {
        // Step 1: Filter by type
        var result = allMedia.filter { $0.type == selectedTab }
        
        // Step 2: Filter by focus if selected
        if let focus = selectedFocus {
            result = result.filter { $0.training?.focus == focus }
        }
        
        // Step 3: Filter by location if selected
        if let location = selectedLocation {
            result = result.filter { $0.training?.location == location }
        }
        
        // Step 4: Filter by search text if not empty
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            result = result.filter { media in
                guard let training = media.training else { return false }
                return training.notes.lowercased().contains(searchLower) ||
                       training.focus.rawValue.lowercased().contains(searchLower) ||
                       training.location.rawValue.lowercased().contains(searchLower)
            }
        }
        
        return result
    }
}

@Observable
class MomentsViewModel {
    var selectedMedia: Media?
    var showingMediaDetail = false
    var searchText = ""
    var selectedFocus: TrainingFocus?
    var selectedLocation: TrainingLocation?
    var selectedTab: MediaType = .image
    
    private let trainings: [Training]
    
    init(trainings: [Training]) {
        self.trainings = trainings
    }
    
    private var allMedia: [Media] {
        var result: [Media] = []
        for training in trainings {
            result.append(contentsOf: training.media)
        }
        return result.sorted { $0.date > $1.date }
    }
    
    var filteredMedia: [Media] {
        let filter = MediaFilter(
            allMedia: allMedia,
            selectedTab: selectedTab,
            selectedFocus: selectedFocus,
            selectedLocation: selectedLocation,
            searchText: searchText
        )
        return filter.filtered()
    }
}

struct MediaGridItemView: View {
    let media: Media
    let size: CGFloat
    
    private var focusIndicator: some View {
        Group {
            if let training = media.training {
                Circle()
                    .fill(training.focus.color)
                    .frame(width: 8, height: 8)
                    .padding(4)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
        }
    }
    
    private var overlayContent: some View {
        VStack {
            HStack {
                focusIndicator
                Spacer()
            }
            Spacer()
        }
        .padding(4)
    }
    
    var body: some View {
        if let image = media.thumbnail {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipped()
                .overlay(overlayContent)
        }
    }
}

struct MomentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Training.date, order: .reverse) private var trainings: [Training]
    @State private var viewModel: MomentsViewModel
    @State private var gridLayout: [GridItem] = Array(repeating: .init(.flexible()), count: 3)
    
    init() {
        _viewModel = State(initialValue: MomentsViewModel(trainings: []))
    }
    
    private func mediaTypeButton(_ type: MediaType) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.selectedTab = type
            }
        }) {
            Text(type.rawValue)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(viewModel.selectedTab == type ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(viewModel.selectedTab == type ? .white : .primary)
                .cornerRadius(15)
        }
    }
    
    private var mediaTypeTabs: some View {
        HStack(spacing: 8) {
            ForEach(MediaType.allCases, id: \.self) { type in
                mediaTypeButton(type)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private var filterButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Focus Filters
                ForEach(TrainingFocus.allCases, id: \.self) { focus in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.selectedFocus = viewModel.selectedFocus == focus ? nil : focus
                        }
                    }) {
                        Text(focus.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedFocus == focus ? focus.color : Color.gray.opacity(0.2))
                            .foregroundColor(viewModel.selectedFocus == focus ? .white : .primary)
                            .cornerRadius(15)
                    }
                }
                
                // Location Filters
                ForEach(TrainingLocation.allCases, id: \.self) { location in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.selectedLocation = viewModel.selectedLocation == location ? nil : location
                        }
                    }) {
                        Text(location.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedLocation == location ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(viewModel.selectedLocation == location ? .white : .primary)
                            .cornerRadius(15)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
    
    private var mediaGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridLayout, spacing: 2) {
                ForEach(viewModel.filteredMedia, id: \.id) { media in
                    GeometryReader { geometry in
                        MediaGridItemView(media: media, size: geometry.size.width)
                            .onTapGesture {
                                viewModel.selectedMedia = media
                                viewModel.showingMediaDetail = true
                            }
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    mediaTypeTabs
                }
                filterButtons
                mediaGrid
            }
            .navigationTitle("Moments")
            .searchable(text: $viewModel.searchText, prompt: "Search moments")
            .sheet(isPresented: $viewModel.showingMediaDetail) {
                if let media = viewModel.selectedMedia {
                    MediaDetailView(media: media)
                }
            }
            .onAppear {
                viewModel = MomentsViewModel(trainings: trainings)
            }
        }
    }
}

struct MediaDetailView: View {
    let media: Media
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var currentIndex: Int
    @State private var player: AVPlayer?
    
    private let allMedia: [Media]
    
    init(media: Media) {
        self.media = media
        self.allMedia = media.training?.media.sorted { $0.date > $1.date } ?? []
        _currentIndex = State(initialValue: self.allMedia.firstIndex(where: { $0.id == media.id }) ?? 0)
    }
    
    private var currentMedia: Media {
        allMedia[currentIndex]
    }
    
    private func nextImage() {
        withAnimation {
            if currentIndex < allMedia.count - 1 {
                currentIndex += 1
                scale = 1.0
                player?.pause()
                player = nil
            }
        }
    }
    
    private func previousImage() {
        withAnimation {
            if currentIndex > 0 {
                currentIndex -= 1
                scale = 1.0
                player?.pause()
                player = nil
            }
        }
    }
    
    private func handleSwipe(_ value: DragGesture.Value) {
        if value.translation.width > 0 {
            previousImage()
        } else {
            nextImage()
        }
    }
    
    private var mediaContent: some View {
        Group {
            if currentMedia.type == .image {
                if let image = currentMedia.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .onTapGesture(count: 2) {
                            withAnimation {
                                scale = scale == 1.0 ? 2.0 : 1.0
                            }
                        }
                }
            } else if let videoURL = currentMedia.videoURL {
                VideoPlayer(player: player)
                    .onAppear {
                        player = AVPlayer(url: videoURL)
                        player?.play()
                    }
                    .onDisappear {
                        player?.pause()
                        player = nil
                    }
            }
        }
    }
    
    private var detailsContent: some View {
        Group {
            if let training = currentMedia.training {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Training Details")
                        .font(.headline)
                        .padding(.top)
                    
                    HStack {
                        Text(training.date, style: .date)
                        Spacer()
                        Text(training.focus.rawValue)
                            .foregroundColor(training.focus.color)
                    }
                    
                    HStack {
                        Text("\(training.duration) min")
                        Spacer()
                        Text(training.location.rawValue)
                    }
                    
                    if !training.notes.isEmpty {
                        Text("Notes:")
                            .font(.headline)
                        Text(training.notes)
                    }
                }
                .padding()
            }
        }
    }
    
    private var indicatorContent: some View {
        Group {
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
    }
    
    var body: some View {
        NavigationView {
            VStack {
                mediaContent
                detailsContent
                indicatorContent
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded(handleSwipe)
            )
        }
    }
} 