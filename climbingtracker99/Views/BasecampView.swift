import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseFirestore
import AVKit

struct BasecampView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Training.date, order: .reverse) private var allTrainings: [Training]
    @Query(sort: \RunningSession.startTime, order: .reverse) private var allRuns: [RunningSession]
    @StateObject private var viewModel = BasecampViewModel()
    @State private var showingFriendSearch = false
    @State private var selectedTraining: Training?
    @State private var selectedRun: RunningSession?
    @State private var currentUser: FirebaseAuth.User? = Auth.auth().currentUser
    @State private var authHandle: AuthStateDidChangeListenerHandle?
    @State private var authEmail: String = ""
    @State private var authPassword: String = ""
    @State private var authStatusMessage: String = ""
    @State private var authStatusColor: Color = .secondary
    @State private var isProcessingAuth: Bool = false
    @State private var authMode: AuthMode = .signIn
    
    enum AuthMode: String, CaseIterable, Identifiable {
        case signIn = "Sign In"
        case signUp = "Sign Up"
        var id: String { rawValue }
    }
    
    private var authContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                    Text("Sign in to Basecamp")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Connect with friends to share trainings and runs.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                Picker("", selection: $authMode) {
                    ForEach(AuthMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                
                VStack(spacing: 16) {
                    TextField("Email", text: $authEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                        .textFieldStyle(.roundedBorder)
                    SecureField("Password", text: $authPassword)
                        .textContentType(.password)
                        .textFieldStyle(.roundedBorder)
                    if authMode == .signUp {
                        Text("Password must be at least 6 characters.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if isProcessingAuth {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Button(authMode == .signIn ? "Sign In" : "Create Account", action: handleAuthAction)
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .disabled(authEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || authPassword.count < 6)
                    }
                }
                
                if !authStatusMessage.isEmpty {
                    Text(authStatusMessage)
                        .font(.footnote)
                        .foregroundColor(authStatusColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private func handleAuthAction() {
        let email = authEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        authEmail = email
        guard !email.isEmpty else {
            authStatusColor = .red
            authStatusMessage = "Please enter an email address."
            return
        }
        guard authPassword.count >= 6 else {
            authStatusColor = .red
            authStatusMessage = "Password must be at least 6 characters."
            return
        }
        isProcessingAuth = true
        authStatusMessage = ""
        let completion: (AuthDataResult?, Error?) -> Void = { result, error in
            DispatchQueue.main.async {
                self.isProcessingAuth = false
                if let error = error {
                    self.authStatusColor = .red
                    self.authStatusMessage = error.localizedDescription
                } else if let user = result?.user {
                    self.authStatusColor = .green
                    self.authStatusMessage = self.authMode == .signIn ? "Signed in successfully." : "Account created."
                    self.authPassword = ""
                    self.currentUser = user
                    FirebaseSyncManager.shared.triggerFullSync()
                    Task { await self.viewModel.refresh() }
                } else {
                    self.authStatusColor = .secondary
                    self.authStatusMessage = "" 
                }
            }
        }
        switch authMode {
        case .signIn:
            Auth.auth().signIn(withEmail: email, password: authPassword, completion: completion)
        case .signUp:
            Auth.auth().createUser(withEmail: email, password: authPassword, completion: completion)
        }
    }
    
    private func signOut() {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            authPassword = ""
            authStatusColor = .secondary
            authStatusMessage = "Signed out."
            showingFriendSearch = false
            selectedTraining = nil
            selectedRun = nil
            viewModel.feedItems = []
            viewModel.followingProfiles = []
            viewModel.isLoading = false
        } catch {
            authStatusColor = .red
            authStatusMessage = error.localizedDescription
        }
    }
    
    private func attachAuthListenerIfNeeded() {
        guard authHandle == nil else { return }
        authHandle = Auth.auth().addStateDidChangeListener { _, user in
            DispatchQueue.main.async {
                self.currentUser = user
                if let user {
                    if self.authEmail.isEmpty {
                        self.authEmail = user.email ?? ""
                    }
                    self.authPassword = ""
                    self.authStatusMessage = ""
                    self.authStatusColor = .secondary
                    FirebaseSyncManager.shared.triggerFullSync()
                    Task { await self.viewModel.refresh() }
                } else {
                    self.viewModel.feedItems = []
                    self.viewModel.followingProfiles = []
                    self.viewModel.isLoading = false
                }
            }
        }
    }
    
    private func detachAuthListener() {
        if let handle = authHandle {
            Auth.auth().removeStateDidChangeListener(handle)
            authHandle = nil
        }
    }
    
    private func clearAuthStatus() {
        guard !isProcessingAuth else { return }
        authStatusMessage = ""
        authStatusColor = .secondary
    }
    
    var body: some View {
        NavigationStack {
            if currentUser == nil {
                authContent
                    .navigationTitle("Basecamp")
            } else {
                Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.feedItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.3")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(viewModel.emptyStateMessage)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button(action: { showingFriendSearch = true }) {
                        Label("Find friends", systemImage: "person.crop.circle.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                        let trainingMap = Dictionary(uniqueKeysWithValues: allTrainings.compactMap { training -> (String, Training)? in
                            guard let id = training.syncIdentifier else { return nil }
                            return (id, training)
                        })
                        let runMap = Dictionary(uniqueKeysWithValues: allRuns.compactMap { run -> (String, RunningSession)? in
                            guard let id = run.syncIdentifier else { return nil }
                            return (id, run)
                        })
                        List {
                            ForEach(viewModel.feedItems) { item in
                                FeedRow(item: item,
                                        training: item.entityId.flatMap { trainingMap[$0] },
                                        run: item.entityId.flatMap { runMap[$0] },
                                        viewModel: viewModel,
                                        onSelectTraining: { selectedTraining = $0 },
                                        onSelectRun: { selectedRun = $0 })
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .navigationTitle("Basecamp")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingFriendSearch = true }) {
                            Image(systemName: "person.crop.circle.badge.plus")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: signOut) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
                .refreshable {
                    await viewModel.refresh()
                }
                .onAppear {
                    Task { await viewModel.refresh() }
                }
                .onDisappear {
                    Task { @MainActor in
                        viewModel.stopLikesListener()
                    }
                }
            }
        }
        .sheet(isPresented: $showingFriendSearch) {
            if currentUser != nil {
                FriendSearchView(existingFollowees: viewModel.followingProfiles,
                                 onFollow: { profile in
                    Task {
                        await viewModel.follow(profile: profile)
                    }
                }, onUnfollow: { profile in
                    Task {
                        await viewModel.unfollow(profile: profile)
                    }
                }, onDismiss: {
                    showingFriendSearch = false
                })
            } else {
                EmptyView()
            }
        }
        .sheet(item: $selectedTraining) { training in
            TrainingDetailView(training: training)
        }
        .sheet(item: $selectedRun) { run in
            RunDetailView(run: run)
        }
        .onAppear { attachAuthListenerIfNeeded() }
        .onDisappear { detachAuthListener() }
        .onChange(of: authMode) { _, _ in clearAuthStatus() }
        .onChange(of: authEmail) { _, _ in clearAuthStatus() }
        .onChange(of: authPassword) { _, _ in clearAuthStatus() }
    }
}

@MainActor
final class BasecampViewModel: ObservableObject {
    @Published var feedItems: [FirebaseActivityItem] = []
    @Published var followingProfiles: [FirebaseUserProfile] = []
    @Published var isLoading = false
    @Published var likedActivityIds: Set<String> = []
    
    private var likesListener: ListenerRegistration?
    
    private var currentUserId: String? {
        FirebaseAuth.Auth.auth().currentUser?.uid
    }
    
    var emptyStateMessage: String {
        if FirebaseAuth.Auth.auth().currentUser == nil {
            return "Sign in to Basecamp to see your feed."
        } else {
            return "Follow friends to see their activity feed."
        }
    }
    
    func isLiked(activityId: String) -> Bool {
        likedActivityIds.contains(activityId)
    }
    
    func toggleLike(for item: FirebaseActivityItem) async {
        guard currentUserId != nil else { return }
        let activityId = item.id
        let isCurrentlyLiked = likedActivityIds.contains(activityId)
        
        // Optimistic update
        if isCurrentlyLiked {
            likedActivityIds.remove(activityId)
            updateItemLikeState(itemId: activityId, isLiked: false)
        } else {
            likedActivityIds.insert(activityId)
            updateItemLikeState(itemId: activityId, isLiked: true)
        }
        
        // Update Firebase
        do {
            if isCurrentlyLiked {
                try await FirebaseSyncManager.shared.unlikeActivity(activityId: activityId)
            } else {
                try await FirebaseSyncManager.shared.likeActivity(activityId: activityId)
            }
            // Don't refresh - the optimistic update already handled the UI
            // The like count will be correct on next feed refresh
        } catch {
            // Revert optimistic update on error
            if isCurrentlyLiked {
                likedActivityIds.insert(activityId)
                updateItemLikeState(itemId: activityId, isLiked: true)
            } else {
                likedActivityIds.remove(activityId)
                updateItemLikeState(itemId: activityId, isLiked: false)
            }
            print("Failed to \(isCurrentlyLiked ? "unlike" : "like") activity: \(error.localizedDescription)")
        }
    }
    
    private func updateItemLikeState(itemId: String, isLiked: Bool) {
        if let index = feedItems.firstIndex(where: { $0.id == itemId }) {
            let item = feedItems[index]
            var newLikedBy = item.likedBy
            if let currentUserId = currentUserId {
                if isLiked {
                    if !newLikedBy.contains(currentUserId) {
                        newLikedBy.append(currentUserId)
                    }
                } else {
                    newLikedBy.removeAll { $0 == currentUserId }
                }
            }
            feedItems[index] = item.updatingLikes(likeCount: newLikedBy.count, likedBy: newLikedBy)
        }
    }
    
    func refresh() async {
        guard FirebaseAuth.Auth.auth().currentUser != nil else {
            await MainActor.run {
                feedItems = []
                followingProfiles = []
                isLoading = false
            }
            stopLikesListener()
            return
        }
        guard !isLoading else { return }
        isLoading = true
        async let followsTask = fetchFollowing()
        async let feedTask = fetchFeed()
        let (follows, feed) = await (followsTask, feedTask)
        followingProfiles = follows
        feedItems = feed
        isLoading = false
        
        // Set up real-time listeners for likes
        setupLikesListener()
    }
    
    private func setupLikesListener() {
        // Remove existing listener
        stopLikesListener()
        
        guard !feedItems.isEmpty else { 
            print("⚠️ Cannot setup likes listener: feedItems is empty")
            return 
        }
        let activityIds = feedItems.map { $0.id }
        print("🔔 Setting up likes listener for \(activityIds.count) activities")
        
        likesListener = FirebaseSyncManager.shared.listenToLikesForActivities(activityIds) { [weak self] likesByActivity in
            Task { @MainActor in
                guard let self = self else { return }
                
                print("📢 Likes listener triggered with \(likesByActivity.count) activities")
                
                // Create updated feed items array
                var updatedItems = self.feedItems
                var hasChanges = false
                
                // Update feed items with new like data
                for (index, item) in updatedItems.enumerated() {
                    let likedBy = likesByActivity[item.id] ?? []
                    let newItem = item.updatingLikes(likeCount: likedBy.count, likedBy: likedBy)
                    
                    // Check if there are actual changes - compare arrays as sets for order-independent comparison
                    let currentLikedBySet = Set(item.likedBy)
                    let newLikedBySet = Set(likedBy)
                    let countsMatch = item.likeCount == newItem.likeCount
                    let setsMatch = currentLikedBySet == newLikedBySet
                    
                    if !countsMatch || !setsMatch {
                        updatedItems[index] = newItem
                        hasChanges = true
                        print("🔄 Updated likes for activity \(item.id): \(item.likeCount) -> \(newItem.likeCount)")
                    }
                }
                
                // Always update to ensure UI reflects current state
                if hasChanges {
                    self.feedItems = updatedItems
                    
                    // Update liked activity IDs
                    if let currentUserId = self.currentUserId {
                        self.likedActivityIds = Set(self.feedItems.filter { $0.likedBy.contains(currentUserId) }.map { $0.id })
                    }
                    print("✅ Updated feed items with new like data")
                } else {
                    print("ℹ️ No changes detected in like data")
                }
            }
        }
        
        if likesListener != nil {
            print("✅ Likes listener set up successfully")
        } else {
            print("⚠️ Failed to set up likes listener")
        }
    }
    
    func stopLikesListener() {
        likesListener?.remove()
        likesListener = nil
    }
    
    deinit {
        // Clean up listener synchronously - listener.remove() is thread-safe
        likesListener?.remove()
        likesListener = nil
    }
    
    private func fetchFollowing() async -> [FirebaseUserProfile] {
        do {
            return try await FirebaseSyncManager.shared.fetchFollowedUsers()
        } catch {
            print("Failed to fetch following: \(error)")
            return []
        }
    }
    
    private func fetchFeed() async -> [FirebaseActivityItem] {
        do {
            let currentUserId = FirebaseAuth.Auth.auth().currentUser?.uid
            let raw = try await FirebaseSyncManager.shared.fetchFeedActivities()
                .filter { item in
                    if let currentUserId, item.userId == currentUserId {
                        return false
                    }
                    if item.entityId == nil && (item.type == "training" || item.type == "run") {
                        return false
                    }
                    return true
                }
            let grouped = Dictionary(grouping: raw) { $0.entityId ?? $0.id }
            let deduped = grouped.compactMap { _, values in
                values.sorted { $0.createdAt > $1.createdAt }.first
            }
            let sorted = deduped.sorted { $0.createdAt > $1.createdAt }
            
            // Update liked activity IDs
            if let currentUserId = currentUserId {
                likedActivityIds = Set(sorted.filter { $0.likedBy.contains(currentUserId) }.map { $0.id })
            }
            
            return sorted
        } catch {
            print("Failed to fetch feed: \(error)")
            return []
        }
    }
    
    func follow(profile: FirebaseUserProfile) async {
        do {
            try await FirebaseSyncManager.shared.follow(userId: profile.id)
            await refresh()
        } catch {
            print("Failed to follow: \(error)")
        }
    }
    
    func unfollow(profile: FirebaseUserProfile) async {
        do {
            try await FirebaseSyncManager.shared.unfollow(userId: profile.id)
            await refresh()
        } catch {
            print("Failed to unfollow: \(error)")
        }
    }
}

struct FeedRow: View {
    let item: FirebaseActivityItem
    let training: Training?
    let run: RunningSession?
    let viewModel: BasecampViewModel
    let onSelectTraining: (Training) -> Void
    let onSelectRun: (RunningSession) -> Void
    
    var body: some View {
        if let training {
            TrainingActivityCard(training: training, author: item)
                .contentShape(Rectangle())
                .onTapGesture { onSelectTraining(training) }
        } else if item.type == "training" {
            TrainingFeedSummaryCard(item: item, viewModel: viewModel)
        } else if let run {
            CompactRunningCard(run: run, author: item)
                .contentShape(Rectangle())
                .onTapGesture { onSelectRun(run) }
        } else if item.type == "run" {
            RunFeedSummaryCard(item: item, viewModel: viewModel)
        } else {
            FeedSummaryCard(item: item)
        }
    }
}

struct FeedSummaryCard: View {
    let item: FirebaseActivityItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            authorHeader
            Text(item.summary)
                .font(.body)
            if let detail = item.payload["details"] as? String, !detail.isEmpty {
                Text(detail)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
    
    private var authorHeader: some View {
        HStack(spacing: 8) {
            ProfileAvatarView(imageData: item.profileImageData, displayName: item.displayName)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                if !item.username.isEmpty {
                    Text("@\(item.username)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(item.createdAt, format: .relative(presentation: .named))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct TrainingFeedSummaryCard: View {
    let item: FirebaseActivityItem
    let viewModel: BasecampViewModel
    
    private var focus: TrainingFocus? {
        if let value = item.payload["focus"] as? String {
            return TrainingFocus(rawValue: value)
        }
        return nil
    }
    private var duration: Int {
        item.payload["duration"] as? Int ?? 0
    }
    private var exerciseCount: Int {
        if let count = item.payload["exerciseCount"] as? Int { return count }
        return exerciseNames.count
    }
    private var location: TrainingLocation? {
        if let value = item.payload["location"] as? String {
            return TrainingLocation(rawValue: value)
        }
        return nil
    }
    private var isRecorded: Bool {
        item.payload["isRecorded"] as? Bool ?? false
    }
    private var exerciseNames: [String] {
        item.payload["exerciseNames"] as? [String] ?? []
    }
    private var notes: String? {
        item.payload["notes"] as? String
    }
    private var focusColor: Color {
        focus?.color ?? .blue
    }
    private var isRecordedLabel: String { isRecorded ? "Recorded" : "Logged" }
    private var remoteMediaItems: [RemoteMediaItem] {
        RemoteMediaItem.items(from: item.payload["mediaItems"])
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with author, date, and icon
            HStack {
                // Author info (icon + name)
                HStack(spacing: 8) {
                    ProfileAvatarView(imageData: item.profileImageData, displayName: item.displayName)
                        .frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.displayName)
                            .font(.system(size: 16, weight: .semibold))
                        if !item.username.isEmpty {
                            Text("@\(item.username)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Date and time
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.createdAt, style: .date)
                        .font(.system(size: 16, weight: .semibold))
                    Text(item.createdAt, style: .time)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 12)
                
                Spacer()
                
                Image(systemName: "figure.climbing")
                    .font(.title2)
                    .foregroundColor(focusColor)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            
            // Main stats row (Strava-style)
            HStack(spacing: 0) {
                // Duration - Largest
                VStack(spacing: 4) {
                    Text("\(max(duration, 0))")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 40)
                
                // Exercise count
                VStack(spacing: 4) {
                    Text("\(max(exerciseCount, 0))")
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                    Text(exerciseCount == 1 ? "exercise" : "exercises")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 40)
                
                // Focus
                VStack(spacing: 4) {
                    Text(focus?.rawValue.uppercased() ?? "TRAINING")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("focus")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            // Secondary stats
            HStack(spacing: 20) {
                if let location {
                    StatBadge(icon: location == .indoor ? "building.2" : "tree",
                              value: location.rawValue,
                              unit: "")
                }
                StatBadge(icon: "dot.radiowaves.left.and.right",
                          value: isRecordedLabel,
                          unit: "")
                if !remoteMediaItems.isEmpty {
                    StatBadge(icon: "photo.fill", value: "\(remoteMediaItems.count)", unit: "")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Notes (if available)
            if let notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .padding(.horizontal)
                    .padding(.bottom, remoteMediaItems.isEmpty ? 8 : 0)
            }
            
            // Media gallery
            if !remoteMediaItems.isEmpty {
                RemoteMediaGallery(items: remoteMediaItems)
                    .padding(8)
            }
            
            // Like button
            HStack {
                Spacer()
                Button(action: {
                    Task {
                        await viewModel.toggleLike(for: item)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.isLiked(activityId: item.id) ? "heart.fill" : "heart")
                            .foregroundColor(viewModel.isLiked(activityId: item.id) ? .red : .secondary)
                            .font(.system(size: 16))
                        if item.likeCount > 0 {
                            Text("\(item.likeCount)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .contentShape(Rectangle())
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(focusColor.opacity(0.3), lineWidth: 1)
        )
    }
}

struct RunFeedSummaryCard: View {
    let item: FirebaseActivityItem
    let viewModel: BasecampViewModel
    
    private var distance: Double {
        item.payload["distance"] as? Double ?? 0
    }
    private var duration: TimeInterval {
        if let value = item.payload["duration"] as? Double { return value }
        if let value = item.payload["duration"] as? Int { return Double(value) }
        return 0
    }
    private var pace: Double {
        item.payload["averagePace"] as? Double ?? 0
    }
    private var calories: Int {
        item.payload["calories"] as? Int ?? 0
    }
    private var startTime: Date {
        if let ts = item.payload["startTime"] as? Timestamp {
            return ts.dateValue()
        }
        return item.createdAt
    }
    private var remoteMediaItems: [RemoteMediaItem] {
        RemoteMediaItem.items(from: item.payload["mediaItems"])
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with author, date, and icon
            HStack {
                // Author info (icon + name)
                HStack(spacing: 8) {
                    ProfileAvatarView(imageData: item.profileImageData, displayName: item.displayName)
                        .frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.displayName)
                            .font(.system(size: 16, weight: .semibold))
                        if !item.username.isEmpty {
                            Text("@\(item.username)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Date and time
                VStack(alignment: .leading, spacing: 2) {
                    Text(startTime, style: .date)
                        .font(.system(size: 16, weight: .semibold))
                    Text(startTime, style: .time)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 12)
                
                Spacer()
                
                Image(systemName: "figure.run")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            
            // Main stats row (Strava-style)
            HStack(spacing: 0) {
                // Distance - Largest
                VStack(spacing: 4) {
                    Text(String(format: "%.2f", distance))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("km")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 40)
                
                // Duration
                VStack(spacing: 4) {
                    Text(formatDuration(duration))
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                    Text("time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 40)
                
                // Pace
                VStack(spacing: 4) {
                    Text(formatPace(pace))
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                    Text("pace")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            // Secondary stats
            HStack(spacing: 20) {
                if let elevation = item.payload["elevationGain"] as? Double, elevation > 0 {
                    StatBadge(icon: "arrow.up",
                              value: String(format: "%.0f", elevation),
                              unit: "m")
                }
                if let calories = item.payload["calories"] as? Int, calories > 0 {
                    StatBadge(icon: "flame.fill",
                              value: "\(calories)",
                              unit: "kcal")
                }
                if !remoteMediaItems.isEmpty {
                    StatBadge(icon: "photo.fill",
                              value: "\(remoteMediaItems.count)",
                              unit: "")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Route preview (if available)
            if let routeCoordinates = item.payload["routeCoordinates"] as? [[String: Double]], !routeCoordinates.isEmpty {
                // Note: RoutePreview would need to be adapted for this data structure
                // For now, we'll skip it or show a placeholder
            }
            
            // Notes (if available)
            if let notes = item.payload["notes"] as? String, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .padding(.horizontal)
                    .padding(.bottom, remoteMediaItems.isEmpty ? 8 : 0)
            }
            
            // Media gallery
            if !remoteMediaItems.isEmpty {
                RemoteMediaGallery(items: remoteMediaItems)
                    .padding(8)
            }
            
            // Like button
            HStack {
                Spacer()
                Button(action: {
                    Task {
                        await viewModel.toggleLike(for: item)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.isLiked(activityId: item.id) ? "heart.fill" : "heart")
                            .foregroundColor(viewModel.isLiked(activityId: item.id) ? .red : .secondary)
                            .font(.system(size: 16))
                        if item.likeCount > 0 {
                            Text("\(item.likeCount)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        guard duration > 0 else { return "--" }
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        let s = Int(duration) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
    
    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct FollowingChip: View {
    let profile: FirebaseUserProfile
    let unfollowAction: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            ProfileAvatarView(imageData: profile.profileImageData, displayName: profile.displayName ?? "")
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName ?? "Unknown")
                    .font(.caption)
                    .fontWeight(.semibold)
                if let username = profile.username, !username.isEmpty {
                    Text("@\(username)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Button(role: .destructive, action: unfollowAction) {
                Text("Unfollow")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct FriendSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var results: [FirebaseUserProfile] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    let existingFollowees: [FirebaseUserProfile]
    let onFollow: (FirebaseUserProfile) -> Void
    let onUnfollow: (FirebaseUserProfile) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            List {
                if let message = errorMessage {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                if !existingFollowees.isEmpty {
                    Section("Following") {
                        ForEach(existingFollowees) { profile in
                            HStack(spacing: 12) {
                                ProfileAvatarView(imageData: profile.profileImageData, displayName: profile.displayName ?? "")
                                    .frame(width: 40, height: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.displayName ?? "Unknown")
                                        .font(.body)
                                        .fontWeight(.semibold)
                                    if let username = profile.username, !username.isEmpty {
                                        Text("@\(username)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    onUnfollow(profile)
                                } label: {
                                    Label("Unfollow", systemImage: "person.badge.minus")
                                        .labelStyle(.iconOnly)
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                Section("Search Results") {
                    if isSearching {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if results.isEmpty {
                        Text("Type a username to find friends.")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(results, id: \.id) { profile in
                            Button {
                                onFollow(profile)
                            } label: {
                                HStack(spacing: 12) {
                                    ProfileAvatarView(imageData: profile.profileImageData, displayName: profile.displayName ?? "")
                                        .frame(width: 40, height: 40)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(profile.displayName ?? "Unknown")
                                            .font(.body)
                                            .fontWeight(.semibold)
                                        if let username = profile.username, !username.isEmpty {
                                            Text("@\(username)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "person.badge.plus")
                                        .foregroundColor(.accentColor)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Friends")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .onSubmit(of: .search) {
                Task { await search() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
            .onChange(of: query) { _, newValue in
                if newValue.isEmpty {
                    results = []
                }
            }
        }
    }
    
    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        do {
            let fetched = try await FirebaseSyncManager.shared.searchUsers(matching: trimmed, limit: 20)
            await MainActor.run {
                results = fetched
                isSearching = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to search users."
                isSearching = false
            }
        }
    }
}

struct RemoteMediaItem: Identifiable {
    let id: String
    let type: MediaType
    let url: URL?
    let thumbnailURL: URL?
    let base64: String?
    let thumbnailBase64: String?
    
    static func items(from payload: Any?) -> [RemoteMediaItem] {
        guard let array = payload as? [[String: Any]] else { return [] }
        return array.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let typeRaw = dict["type"] as? String,
                  let type = MediaType(rawValue: typeRaw) else { return nil }
            
            // Check for base64 first, then fall back to URL
            let base64 = dict["base64"] as? String
            let url = base64 == nil ? RemoteMediaItem.urlValue(from: dict["url"]) : nil
            
            // Check for base64 thumbnail first, then fall back to URL
            let thumbnailBase64 = dict["thumbnailBase64"] as? String
            let thumbURL = thumbnailBase64 == nil ? RemoteMediaItem.urlValue(from: dict["thumbnailURL"]) : nil
            
            // Must have either URL or base64
            guard url != nil || base64 != nil else { return nil }
            
            return RemoteMediaItem(id: id, type: type, url: url, thumbnailURL: thumbURL, base64: base64, thumbnailBase64: thumbnailBase64)
        }
    }
    
    private static func urlValue(from value: Any?) -> URL? {
        if let url = value as? URL { return url }
        if let string = value as? String {
            // Skip base64: prefix strings
            if string.hasPrefix("base64:") { return nil }
            return URL(string: string)
        }
        return nil
    }
}

struct RemoteMediaGallery: View {
    let items: [RemoteMediaItem]
    @State private var selectedItem: RemoteMediaItem?
    
    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            TabView {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    ZStack {
                        RemoteMediaAsyncImage(item: item)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(Color.black.opacity(item.type == .video ? 0.15 : 0.05))
                            .overlay(alignment: .center) {
                                if item.type == .video {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(.white)
                                        .shadow(radius: 8)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedItem = item
                            }
                            .overlay(alignment: .bottomTrailing) {
                                Text("\(index + 1)/\(items.count)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .padding(12)
                            }
                    }
                }
            }
            .frame(height: 240)
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.35)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .allowsHitTesting(false)
            )
            .padding(.top, 8)
            .sheet(item: $selectedItem) { item in
                RemoteMediaViewer(item: item)
            }
        }
    }
}

private struct RemoteMediaAsyncImage: View {
    let item: RemoteMediaItem
    
    var body: some View {
        // Check for base64 first
        if let base64 = item.base64, let data = Data(base64Encoded: base64), let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let thumbnailBase64 = item.thumbnailBase64, let data = Data(base64Encoded: thumbnailBase64), let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let url = item.thumbnailURL ?? item.url {
            AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failure:
                placeholder
            case .empty:
                ZStack {
                    Color.gray.opacity(0.1)
                    ProgressView()
                }
            @unknown default:
                placeholder
            }
            }
        } else {
            placeholder
        }
    }
    
    private var placeholder: some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: item.type == .video ? "video.fill" : "photo")
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

struct RemoteMediaViewer: View {
    let item: RemoteMediaItem
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    
    var body: some View {
        NavigationStack {
            Group {
                if item.type == .video {
                    if let url = item.url {
                    VideoPlayer(player: player)
                        .onAppear {
                                player = AVPlayer(url: url)
                            player?.play()
                        }
                        .onDisappear {
                            player?.pause()
                            player = nil
                        }
                } else {
                        placeholder
                    }
                } else {
                    // Check for base64 first
                    if let base64 = item.base64, let data = Data(base64Encoded: base64), let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.9))
                    } else if let url = item.url {
                        AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.opacity(0.9))
                        case .failure:
                            placeholder
                        case .empty:
                            ZStack {
                                Color.black.opacity(0.9)
                                ProgressView()
                                    .tint(.white)
                            }
                        @unknown default:
                            placeholder
                        }
                        }
                    } else {
                        placeholder
                    }
                }
            }
            .ignoresSafeArea()
            .background(Color.black.opacity(0.95))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private var placeholder: some View {
        ZStack {
            Color.black.opacity(0.9)
            Image(systemName: item.type == .video ? "video.fill" : "photo")
                .font(.system(size: 36))
                .foregroundColor(.white)
        }
    }
}

