import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

final class FirebaseSyncManager {
    static let shared = FirebaseSyncManager()
    private init() {}
    
    private var modelContainer: ModelContainer?
    private var authListener: AuthStateDidChangeListenerHandle?
    @MainActor private var isSyncing = false
    private var db: Firestore { Firestore.firestore() }
    private var storage: Storage { Storage.storage() }
    
    func start(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        if let handle = authListener {
            Auth.auth().removeStateDidChangeListener(handle)
            authListener = nil
        }
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self, let user = user else { return }
            Task { @MainActor in
                await self.syncAllData(for: user, modelContainer: modelContainer)
            }
        }
        if let user = Auth.auth().currentUser {
            Task { @MainActor in
                await syncAllData(for: user, modelContainer: modelContainer)
            }
        }
    }
    
    func stop() {
        if let handle = authListener {
            Auth.auth().removeStateDidChangeListener(handle)
            authListener = nil
        }
    }
    
    @MainActor
    private func syncAllData(for user: FirebaseAuth.User, modelContainer: ModelContainer) async {
        if isSyncing { return }
        isSyncing = true
        defer { isSyncing = false }
        
        let context = ModelContext(modelContainer)
        var trainings = (try? context.fetch(FetchDescriptor<Training>())) ?? []
        var runs = (try? context.fetch(FetchDescriptor<RunningSession>())) ?? []
        let plannedTrainings = (try? context.fetch(FetchDescriptor<PlannedTraining>())) ?? []
        let plannedRuns = (try? context.fetch(FetchDescriptor<PlannedRun>())) ?? []
        let plannedBenchmarks = (try? context.fetch(FetchDescriptor<PlannedBenchmark>())) ?? []
        let weightEntries = (try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []
        let userSettings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first
        
        trainings = await downloadTrainingsIfNeeded(for: user, context: context, existingTrainings: trainings)
        runs = await downloadRunsIfNeeded(for: user, context: context, existingRuns: runs)
        deduplicateTrainings(in: context)
        deduplicateRuns(in: context)
        
        trainings = (try? context.fetch(FetchDescriptor<Training>())) ?? trainings
        runs = (try? context.fetch(FetchDescriptor<RunningSession>())) ?? runs
        
        ensureSyncIdentifiers(trainings: trainings,
                               runs: runs,
                               plannedTrainings: plannedTrainings,
                               plannedRuns: plannedRuns,
                               plannedBenchmarks: plannedBenchmarks,
                               weightEntries: weightEntries,
                               context: context)

        uploadUserDocument(user: user, settings: userSettings)
        await uploadTrainings(trainings, for: user, settings: userSettings, context: context)
        await uploadRuns(runs, for: user, settings: userSettings, context: context)
        uploadPlannedTrainings(plannedTrainings, for: user)
        uploadPlannedRuns(plannedRuns, for: user)
        uploadPlannedBenchmarks(plannedBenchmarks, for: user)
        uploadWeightEntries(weightEntries, for: user)
    }
    
    private func uploadUserDocument(user: FirebaseAuth.User, settings: UserSettings?) {
        let userDoc = db.collection("users").document(user.uid)
        var data = baseProfileData(for: user)
        if let settings = settings {
            data.merge(profileData(from: settings)) { _, new in new }
        }
        userDoc.setData(data, merge: true)
    }

    private func baseProfileData(for user: FirebaseAuth.User) -> [String: Any] {
        var data: [String: Any] = [
            "email": user.email ?? "",
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let displayName = user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !displayName.isEmpty {
            data["displayName"] = displayName
            data["displayNameLowercase"] = displayName.lowercased()
        }
        return data
    }

    private func profileData(from settings: UserSettings) -> [String: Any] {
        let trimmedDisplayName = settings.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = settings.handle.trimmingCharacters(in: .whitespacesAndNewlines)

        var data: [String: Any] = [
            "displayName": trimmedDisplayName,
            "username": trimmedUsername,
            "bio": settings.bio,
            "lastProfileUpdated": FieldValue.serverTimestamp()
        ]
        if !trimmedDisplayName.isEmpty {
            data["displayNameLowercase"] = trimmedDisplayName.lowercased()
        }
        if !trimmedUsername.isEmpty {
            data["usernameLowercase"] = trimmedUsername.lowercased()
        }
        let maxRawBytes = 600_000
        let maxBase64Length = 1_000_000
        if let imageData = settings.profileImageData, imageData.count <= maxRawBytes {
            let base64 = imageData.base64EncodedString()
            if base64.count <= maxBase64Length {
                data["profileImageBase64"] = base64
            }
        } else {
            data["profileImageBase64"] = FieldValue.delete()
        }
        return data
    }

    private func ensureSyncIdentifiers(trainings: [Training],
                                       runs: [RunningSession],
                                       plannedTrainings: [PlannedTraining],
                                       plannedRuns: [PlannedRun],
                                       plannedBenchmarks: [PlannedBenchmark],
                                       weightEntries: [WeightEntry],
                                       context: ModelContext) {
        var needsSave = false

        func ensure(_ value: inout String?) {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.isEmpty {
                value = UUID().uuidString
                needsSave = true
            }
        }

        for training in trainings {
            ensure(&training.syncIdentifier)
        }
        for run in runs {
            ensure(&run.syncIdentifier)
        }
        for plan in plannedTrainings {
            ensure(&plan.syncIdentifier)
        }
        for plan in plannedRuns {
            ensure(&plan.syncIdentifier)
        }
        for benchmark in plannedBenchmarks {
            ensure(&benchmark.syncIdentifier)
        }
        for entry in weightEntries {
            ensure(&entry.syncIdentifier)
        }

        if needsSave {
            do {
                try context.save()
            } catch {
                print("Failed to persist sync identifiers: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    private func uploadTrainings(_ trainings: [Training], for user: FirebaseAuth.User, settings: UserSettings?, context: ModelContext) async {
        let collection = db.collection("users").document(user.uid).collection("trainings")
        for training in trainings {
            guard let docId = training.syncIdentifier else { continue }
            let mediaItems = await uploadTrainingMedia(for: training, user: user, context: context)
            var data: [String: Any] = [
                "date": Timestamp(date: training.date),
                "duration": training.duration,
                "location": training.location.rawValue,
                "focus": training.focus.rawValue,
                "notes": training.notes,
                "isRecorded": training.isRecorded,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            if let start = training.recordingStartTime {
                data["recordingStartTime"] = Timestamp(date: start)
            }
            if let end = training.recordingEndTime {
                data["recordingEndTime"] = Timestamp(date: end)
            }
            if let total = training.totalRecordedDuration {
                data["totalRecordedDuration"] = total
            }
            let exercises = training.recordedExercises.map { $0.toSyncDictionary() }
            data["recordedExercises"] = exercises
            if mediaItems.isEmpty {
                data["mediaItems"] = FieldValue.delete()
            } else {
                data["mediaItems"] = mediaItems
            }
            try? await collection.document(docId).setData(data, merge: true)
            uploadTrainingActivity(training, user: user, settings: settings, mediaItems: mediaItems)
        }
    }
    
    @MainActor
    private func uploadRuns(_ runs: [RunningSession], for user: FirebaseAuth.User, settings: UserSettings?, context: ModelContext) async {
        let collection = db.collection("users").document(user.uid).collection("runs")
        for run in runs {
            guard let docId = run.syncIdentifier else { continue }
            let mediaItems = await uploadRunMedia(for: run, user: user, context: context)
            var data: [String: Any] = [
                "startTime": Timestamp(date: run.startTime),
                "duration": run.duration,
                "distance": run.distance,
                "averagePace": run.averagePace,
                "maxSpeed": run.maxSpeed,
                "averageSpeed": run.averageSpeed,
                "calories": run.calories,
                "elevationGain": run.elevationGain,
                "elevationLoss": run.elevationLoss,
                "notes": run.notes,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            if let end = run.endTime {
                data["endTime"] = Timestamp(date: end)
            }
            if let routeData = run.routeDataJSON {
                data["routeData"] = routeData.base64EncodedString()
            } else {
                data["routeData"] = FieldValue.delete()
            }
            if let splitsData = run.splitsDataJSON {
                data["splitsData"] = splitsData.base64EncodedString()
            } else {
                data["splitsData"] = FieldValue.delete()
            }
            if mediaItems.isEmpty {
                data["mediaItems"] = FieldValue.delete()
            } else {
                data["mediaItems"] = mediaItems
            }
            try? await collection.document(docId).setData(data, merge: true)
            uploadRunActivity(run, user: user, settings: settings, mediaItems: mediaItems)
        }
    }
    
    private func uploadPlannedTrainings(_ plans: [PlannedTraining], for user: FirebaseAuth.User) {
        let collection = db.collection("users").document(user.uid).collection("plannedTrainings")
        for plan in plans {
            guard let docId = plan.syncIdentifier else { continue }
            var data: [String: Any] = [
                "date": Timestamp(date: plan.date),
                "estimatedDuration": plan.estimatedDuration,
                "notes": plan.notes ?? "",
                "updatedAt": FieldValue.serverTimestamp()
            ]
            data["exerciseTypes"] = plan.exerciseTypes.map { $0.rawValue }
            data["estimatedTimeOfDay"] = Timestamp(date: plan.estimatedTimeOfDay)
            collection.document(docId).setData(data, merge: true)
        }
    }
    
    private func uploadPlannedRuns(_ plans: [PlannedRun], for user: FirebaseAuth.User) {
        let collection = db.collection("users").document(user.uid).collection("plannedRuns")
        for plan in plans {
            guard let docId = plan.syncIdentifier else { continue }
            var data: [String: Any] = [
                "date": Timestamp(date: plan.date),
                "runningType": plan.runningType.rawValue,
                "estimatedDistance": plan.estimatedDistance,
                "estimatedDuration": plan.estimatedDuration,
                "notes": plan.notes ?? "",
                "updatedAt": FieldValue.serverTimestamp()
            ]
            if let tempo = plan.estimatedTempo {
                data["estimatedTempo"] = tempo
            }
            data["estimatedTimeOfDay"] = Timestamp(date: plan.estimatedTimeOfDay)
            collection.document(docId).setData(data, merge: true)
        }
    }
    
    private func uploadPlannedBenchmarks(_ plans: [PlannedBenchmark], for user: FirebaseAuth.User) {
        let collection = db.collection("users").document(user.uid).collection("plannedBenchmarks")
        for plan in plans {
            guard let docId = plan.syncIdentifier else { continue }
            var data: [String: Any] = [
                "date": Timestamp(date: plan.date),
                "benchmarkType": plan.benchmarkType.rawValue,
                "completed": plan.completed,
                "notes": plan.notes ?? "",
                "updatedAt": FieldValue.serverTimestamp()
            ]
            if let est = plan.estimatedTime {
                data["estimatedTime"] = Timestamp(date: est)
            }
            if let completedDate = plan.completedDate {
                data["completedDate"] = Timestamp(date: completedDate)
            }
            if let value1 = plan.resultValue1 {
                data["resultValue1"] = value1
            }
            if let value2 = plan.resultValue2 {
                data["resultValue2"] = value2
            }
            if let resultNotes = plan.resultNotes {
                data["resultNotes"] = resultNotes
            }
            collection.document(docId).setData(data, merge: true)
        }
    }
    
    private func uploadWeightEntries(_ entries: [WeightEntry], for user: FirebaseAuth.User) {
        let collection = db.collection("users").document(user.uid).collection("weightEntries")
        for entry in entries {
            guard let docId = entry.syncIdentifier else { continue }
            let data: [String: Any] = [
                "date": Timestamp(date: entry.date),
                "weight": entry.weight,
                "notes": "",
                "updatedAt": FieldValue.serverTimestamp()
            ]
            collection.document(docId).setData(data, merge: true)
        }
    }
}

extension FirebaseSyncManager {
    @MainActor
    private func downloadTrainingsIfNeeded(for user: FirebaseAuth.User,
                                           context: ModelContext,
                                           existingTrainings: [Training]) async -> [Training] {
        do {
            let snapshot = try await db.collection("users")
                .document(user.uid)
                .collection("trainings")
                .getDocuments()
            
            guard !snapshot.documents.isEmpty else {
                return existingTrainings
            }
            
            let existingIDs = Set(existingTrainings.compactMap { $0.syncIdentifier })
            var exerciseCache = buildExerciseCache(context: context)
            var hasChanges = false
            
            for document in snapshot.documents {
                let docId = document.documentID
                if existingIDs.contains(docId) {
                    continue
                }
                if let training = createTraining(from: document,
                                                 context: context,
                                                 exerciseCache: &exerciseCache) {
                    context.insert(training)
                    for exercise in training.recordedExercises {
                        context.insert(exercise)
                    }
                    for media in training.media {
                        context.insert(media)
                    }
                    hasChanges = true
                }
            }
            
            if hasChanges {
                do {
                    try context.save()
                } catch {
                    print("Failed to save downloaded trainings: \(error.localizedDescription)")
                }
                return (try? context.fetch(FetchDescriptor<Training>())) ?? existingTrainings
            } else {
                return existingTrainings
            }
        } catch {
            print("Failed to download trainings: \(error.localizedDescription)")
            return existingTrainings
        }
    }
    
    @MainActor
    private func deduplicateTrainings(in context: ModelContext) {
        guard let trainings = try? context.fetch(FetchDescriptor<Training>()) else { return }
        var seen: Set<String> = []
        var didDelete = false
        for training in trainings {
            guard let id = training.syncIdentifier else { continue }
            if seen.contains(id) {
                context.delete(training)
                didDelete = true
            } else {
                seen.insert(id)
            }
        }
        if didDelete {
            do {
                try context.save()
            } catch {
                print("Failed to save after deduplicating trainings: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    private func downloadRunsIfNeeded(for user: FirebaseAuth.User,
                                      context: ModelContext,
                                      existingRuns: [RunningSession]) async -> [RunningSession] {
        do {
            let snapshot = try await db.collection("users")
                .document(user.uid)
                .collection("runs")
                .getDocuments()
            
            guard !snapshot.documents.isEmpty else {
                return existingRuns
            }
            
            let existingIDs = Set(existingRuns.compactMap { $0.syncIdentifier })
            var hasChanges = false
            
            for document in snapshot.documents {
                let docId = document.documentID
                if existingIDs.contains(docId) {
                    continue
                }
                
                if let run = createRunningSession(from: document, context: context) {
                    context.insert(run)
                    for media in run.media {
                        context.insert(media)
                    }
                    hasChanges = true
                }
            }
            
            if hasChanges {
                do {
                    try context.save()
                } catch {
                    print("Failed to save downloaded runs: \(error.localizedDescription)")
                }
                return (try? context.fetch(FetchDescriptor<RunningSession>())) ?? existingRuns
            } else {
                return existingRuns
            }
        } catch {
            print("Failed to download runs: \(error.localizedDescription)")
            return existingRuns
        }
    }
    
    @MainActor
    private func deduplicateRuns(in context: ModelContext) {
        guard let runs = try? context.fetch(FetchDescriptor<RunningSession>()) else { return }
        var seen: Set<String> = []
        var didDelete = false
        for run in runs {
            guard let id = run.syncIdentifier else { continue }
            if seen.contains(id) {
                context.delete(run)
                didDelete = true
            } else {
                seen.insert(id)
            }
        }
        if didDelete {
            do {
                try context.save()
            } catch {
                print("Failed to save after deduplicating runs: \(error.localizedDescription)")
            }
        }
    }
    
    func triggerFullSync() {
        guard let container = modelContainer, let user = Auth.auth().currentUser else { return }
        Task { @MainActor in
            await syncAllData(for: user, modelContainer: container)
        }
    }

    func uploadProfile(settings: UserSettings) {
        guard let user = Auth.auth().currentUser else { return }
        var data = baseProfileData(for: user)
        data.merge(profileData(from: settings)) { _, new in new }
        db.collection("users").document(user.uid).setData(data, merge: true)
    }

    func follow(userId: String) async throws {
        guard let currentUser = Auth.auth().currentUser else { return }
        let docId = "\(currentUser.uid)_\(userId)"
        let data: [String: Any] = [
            "followerId": currentUser.uid,
            "followeeId": userId,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "isActive": true
        ]
        try await db.collection("follows").document(docId).setData(data, merge: true)
    }

    func likeActivity(activityId: String) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "FirebaseSyncManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        let likeDocId = "\(activityId)_\(currentUser.uid)"
        let likeDoc = db.collection("likes").document(likeDocId)
        // Use setData with merge: false to ensure it's treated as a create operation
        try await likeDoc.setData([
            "activityId": activityId,
            "userId": currentUser.uid,
            "createdAt": FieldValue.serverTimestamp()
        ], merge: false)
    }
    
    func unlikeActivity(activityId: String) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "FirebaseSyncManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        let likeDocId = "\(activityId)_\(currentUser.uid)"
        let likeDoc = db.collection("likes").document(likeDocId)
        
        // Check if document exists before deleting
        let document = try await likeDoc.getDocument()
        if document.exists {
            try await likeDoc.delete()
            print("✅ Successfully unliked activity: \(activityId)")
        } else {
            // Document doesn't exist, which is fine - it's already unliked
            // This can happen if the like was already removed or never existed
            print("ℹ️ Like document doesn't exist for \(activityId), already unliked")
        }
    }
    
    func fetchLikesForActivities(_ activityIds: [String]) async throws -> [String: [String]] {
        guard !activityIds.isEmpty else { return [:] }
        
        // Firestore 'in' queries are limited to 10 items, so we need to chunk
        var likesByActivity: [String: [String]] = [:]
        let chunked = activityIds.chunked(into: 10)
        
        for chunk in chunked {
            let snapshot = try await db.collection("likes")
                .whereField("activityId", in: chunk)
                .getDocuments()
            
            for doc in snapshot.documents {
                if let activityId = doc.data()["activityId"] as? String,
                   let userId = doc.data()["userId"] as? String {
                    if likesByActivity[activityId] == nil {
                        likesByActivity[activityId] = []
                    }
                    likesByActivity[activityId]?.append(userId)
                }
            }
        }
        return likesByActivity
    }
    
    func listenToLikesForActivities(_ activityIds: [String], onUpdate: @escaping ([String: [String]]) -> Void) -> ListenerRegistration? {
        guard !activityIds.isEmpty else { return nil }
        
        // Firestore 'in' queries are limited to 10 items, so we need to chunk
        var listeners: [ListenerRegistration] = []
        let chunked = activityIds.chunked(into: 10)
        
        // Track likes from all chunks
        var allLikesByActivity: [String: [String]] = [:]
        let lock = NSLock()
        
        func updateAndNotify() {
            lock.lock()
            defer { lock.unlock() }
            onUpdate(allLikesByActivity)
        }
        
        for chunk in chunked {
            let listener = db.collection("likes")
                .whereField("activityId", in: chunk)
                .addSnapshotListener { snapshot, error in
                    guard let snapshot = snapshot, error == nil else {
                        if let error = error {
                            print("⚠️ Error listening to likes: \(error.localizedDescription)")
                        }
                        return
                    }
                    
                    lock.lock()
                    // Rebuild likes for activities in this chunk from the snapshot
                    let chunkActivityIds = Set(chunk)
                    for activityId in chunkActivityIds {
                        // Get all likes for this activity from the current snapshot
                        let currentLikes = snapshot.documents.compactMap { doc -> String? in
                            if let docActivityId = doc.data()["activityId"] as? String,
                               docActivityId == activityId,
                               let userId = doc.data()["userId"] as? String {
                                return userId
                            }
                            return nil
                        }
                        // Always set, even if empty, to ensure we have complete data
                        allLikesByActivity[activityId] = currentLikes
                    }
                    lock.unlock()
                    
                    // Always notify - Firestore listeners trigger on all changes
                    updateAndNotify()
                }
            listeners.append(listener)
        }
        
        // Return a composite listener that removes all when called
        return CompositeListenerRegistration(listeners: listeners)
    }
    
    // Helper class to manage multiple listeners
    private class CompositeListenerRegistration: NSObject, ListenerRegistration {
        private let listeners: [ListenerRegistration]
        
        init(listeners: [ListenerRegistration]) {
            self.listeners = listeners
            super.init()
        }
        
        func remove() {
            listeners.forEach { $0.remove() }
        }
    }
    
    func unfollow(userId: String) async throws {
        guard let currentUser = Auth.auth().currentUser else { return }
        let docId = "\(currentUser.uid)_\(userId)"
        let update: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp(),
            "isActive": false
        ]
        do {
            try await db.collection("follows").document(docId).setData(update, merge: true)
        } catch {
            print("Failed to deactivate follow document: \(error.localizedDescription)")
            throw error
        }
    }

    func fetchFollowedUsers() async throws -> [FirebaseUserProfile] {
        guard let currentUser = Auth.auth().currentUser else { return [] }
        let snapshot = try await db.collection("follows")
            .whereField("followerId", isEqualTo: currentUser.uid)
            .getDocuments()
        let followeeIds = snapshot.documents.compactMap { doc -> String? in
            let data = doc.data()
            if let isActive = data["isActive"] as? Bool, isActive == false {
                return nil
            }
            return data["followeeId"] as? String
        }
        guard !followeeIds.isEmpty else { return [] }
        var results: [FirebaseUserProfile] = []
        let chunked = followeeIds.chunked(into: 10)
        for chunk in chunked {
            let userSnapshot = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            results.append(contentsOf: userSnapshot.documents.compactMap { FirebaseUserProfile(document: $0) })
        }
        return results.sorted { ($0.displayName ?? "").localizedCaseInsensitiveCompare($1.displayName ?? "") == .orderedAscending }
    }

    func fetchFeedActivities(limit: Int = 30) async throws -> [FirebaseActivityItem] {
        guard let currentUser = Auth.auth().currentUser else { return [] }
        let followSnapshot = try await db.collection("follows")
            .whereField("followerId", isEqualTo: currentUser.uid)
            .getDocuments()
        var userIds = followSnapshot.documents.compactMap { $0.data()["followeeId"] as? String }
        userIds = followSnapshot.documents.compactMap { doc -> String? in
            let data = doc.data()
            if let isActive = data["isActive"] as? Bool, isActive == false {
                return nil
            }
            return data["followeeId"] as? String
        }
        userIds.append(currentUser.uid)
        userIds = Array(Set(userIds))
        guard !userIds.isEmpty else { return [] }
        var feed: [FirebaseActivityItem] = []
        let chunked = userIds.chunked(into: 10)
        for chunk in chunked {
            let activitySnapshot = try await db.collection("activities")
                .whereField("userId", in: chunk)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            feed.append(contentsOf: activitySnapshot.documents.compactMap { FirebaseActivityItem(document: $0) })
        }
        
        let trimmedFeed = feed.sorted { $0.createdAt > $1.createdAt }.prefix(limit)
        
        // Fetch profiles
        let profileMap = try await fetchProfiles(for: Set(trimmedFeed.map { $0.userId }))
        
        // Fetch likes for all activities (handle errors gracefully)
        let activityIds = Array(trimmedFeed.map { $0.id })
        var likesByActivity: [String: [String]] = [:]
        do {
            likesByActivity = try await fetchLikesForActivities(activityIds)
        } catch {
            print("⚠️ Failed to fetch likes (non-critical): \(error.localizedDescription)")
            // Continue without likes - feed will still work
        }
        
        // Enrich feed items with profile and like data
        let enrichedFeed = trimmedFeed.map { item -> FirebaseActivityItem in
            var enriched = item
            // Add profile data
            if let profile = profileMap[item.userId] {
                enriched = enriched.updatingProfile(displayName: profile.displayName ?? item.displayName,
                                                    username: profile.username ?? item.username,
                                                    imageData: profile.profileImageData)
            }
            // Add like data
            let likedBy = likesByActivity[item.id] ?? []
            enriched = enriched.updatingLikes(likeCount: likedBy.count, likedBy: likedBy)
            return enriched
        }
        return Array(enrichedFeed)
    }

    func searchUsers(matching query: String, limit: Int = 20) async throws -> [FirebaseUserProfile] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmedQuery.lowercased()
        guard !lowered.isEmpty else { return [] }

        async let usernamesSnapshot = db.collection("users")
            .whereField("usernameLowercase", isGreaterThanOrEqualTo: lowered)
            .whereField("usernameLowercase", isLessThanOrEqualTo: lowered + "\u{F8FF}")
            .limit(to: limit)
            .getDocuments()
 
        async let displayNamesSnapshot = db.collection("users")
            .whereField("displayNameLowercase", isGreaterThanOrEqualTo: lowered)
            .whereField("displayNameLowercase", isLessThanOrEqualTo: lowered + "\u{F8FF}")
            .limit(to: limit)
            .getDocuments()

        async let legacyUsernameSnapshot = db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: lowered)
            .whereField("username", isLessThanOrEqualTo: lowered + "\u{F8FF}")
            .limit(to: limit)
            .getDocuments()

        async let legacyDisplaySnapshot = db.collection("users")
            .whereField("displayName", isGreaterThanOrEqualTo: trimmedQuery)
            .whereField("displayName", isLessThanOrEqualTo: trimmedQuery + "\u{F8FF}")
            .limit(to: limit)
            .getDocuments()
 
        let snapshots = try await [usernamesSnapshot, displayNamesSnapshot, legacyUsernameSnapshot, legacyDisplaySnapshot]

        var profilesById: [String: FirebaseUserProfile] = [:]
        for snapshot in snapshots {
            for document in snapshot.documents {
                guard let profile = FirebaseUserProfile(document: document) else { continue }
                profilesById[profile.id] = profile
            }
        }

        func sortKey(for profile: FirebaseUserProfile) -> String {
            let name = profile.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let name, !name.isEmpty { return name.lowercased() }
            let handle = profile.username?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let handle, !handle.isEmpty { return handle.lowercased() }
            return ""
        }

        let sorted = profilesById.values
            .sorted { sortKey(for: $0) < sortKey(for: $1) }

        if sorted.count > limit {
            return Array(sorted.prefix(limit))
        }
        return sorted
    }
}

// MARK: - Activity Uploads

private extension FirebaseSyncManager {
    func uploadTrainingActivity(_ training: Training, user: FirebaseAuth.User, settings: UserSettings?, mediaItems: [[String: Any]]) {
        guard let syncId = training.syncIdentifier else { return }
        let docId = "training_\(syncId)"
        let summary = "Completed a training session (\(training.duration) min)"
        let exerciseNames = training.recordedExercises.map { $0.exercise.type.displayName }.prefix(3)
        var payload: [String: Any] = [
            "duration": training.duration,
            "focus": training.focus.rawValue,
            "location": training.location.rawValue,
            "isRecorded": training.isRecorded,
            "exerciseCount": training.recordedExercises.count,
            "exerciseNames": Array(exerciseNames),
            "notes": training.notes
        ]
        if !mediaItems.isEmpty {
            payload["mediaItems"] = mediaItems
        }
        if let start = training.recordingStartTime {
            payload["recordingStartTime"] = Timestamp(date: start)
        }
        if let end = training.recordingEndTime {
            payload["recordingEndTime"] = Timestamp(date: end)
        }
        if let total = training.totalRecordedDuration {
            payload["totalRecordedDuration"] = total
        }
        let activityDoc = db.collection("activities").document(docId)
        var data: [String: Any] = [
            "userId": user.uid,
            "type": "training",
            "summary": summary,
            "createdAt": Timestamp(date: training.date),
            "updatedAt": FieldValue.serverTimestamp(),
            "entityId": syncId,
            "payload": payload,
        ]
        if let settings {
            data["displayName"] = settings.userName
            data["username"] = settings.handle
        }
        activityDoc.setData(data, merge: true)
    }
    
    func uploadRunActivity(_ run: RunningSession, user: FirebaseAuth.User, settings: UserSettings?, mediaItems: [[String: Any]]) {
        guard let syncId = run.syncIdentifier else { return }
        let docId = "run_\(syncId)"
        let distanceKM = String(format: "%.2f", run.distanceInKm)
        let summary = "Finished a run: \(distanceKM) km"
        var payload: [String: Any] = [
            "distance": run.distanceInKm,
            "duration": run.duration,
            "averagePace": run.averagePace,
            "averageSpeed": run.averageSpeed,
            "maxSpeed": run.maxSpeed,
            "calories": run.calories,
            "elevationGain": run.elevationGain,
            "elevationLoss": run.elevationLoss,
            "startTime": Timestamp(date: run.startTime),
            "endTime": run.endTime != nil ? Timestamp(date: run.endTime!) : NSNull()
        ]
        if !run.notes.isEmpty {
            payload["notes"] = run.notes
        }
        let splitsCount = run.splits.count
        if splitsCount > 0 {
            payload["splitsCount"] = splitsCount
        }
        if let splitsData = run.splitsDataJSON {
            payload["splitsData"] = splitsData.base64EncodedString()
        }
        if let routeData = run.routeDataJSON {
            payload["routeData"] = routeData.base64EncodedString()
        }
        if !mediaItems.isEmpty {
            payload["mediaItems"] = mediaItems
        }
        uploadActivityDocument(id: docId,
                               user: user,
                               settings: settings,
                               type: "run",
                               summary: summary,
                               createdAt: run.startTime,
                               entityId: syncId,
                               payload: payload)
    }
    
    func uploadActivityDocument(id: String,
                                user: FirebaseAuth.User,
                                settings: UserSettings?,
                                type: String,
                                summary: String,
                                createdAt: Date,
                                entityId: String,
                                payload: [String: Any]) {
        var data: [String: Any] = [
            "userId": user.uid,
            "type": type,
            "summary": summary,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": FieldValue.serverTimestamp(),
            "entityId": entityId,
            "payload": payload,
        ]
        if let settings {
            data["displayName"] = settings.userName
            data["username"] = settings.handle
        }
        db.collection("activities").document(id).setData(data, merge: true)
    }
}

// MARK: - Firebase Models

struct FirebaseUserProfile: Identifiable, Hashable {
    let id: String
    let displayName: String?
    let username: String?
    let bio: String?
    let profileImageData: Data?
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        self.id = document.documentID
        self.displayName = data["displayName"] as? String
        self.username = data["username"] as? String
        self.bio = data["bio"] as? String
        if let base64 = data["profileImageBase64"] as? String,
           let decoded = Data(base64Encoded: base64) {
            self.profileImageData = decoded
        } else {
            self.profileImageData = nil
        }
    }
}

struct FirebaseActivityItem: Identifiable, Hashable {
    let id: String
    let userId: String
    let displayName: String
    let username: String
    let type: String
    let summary: String
    let createdAt: Date
    let payload: [String: Any]
    let entityId: String?
    let profileImageData: Data?
    let likeCount: Int
    let likedBy: [String]
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let userId = data["userId"] as? String,
              let summary = data["summary"] as? String,
              let type = data["type"] as? String else { return nil }
        let likedBy = data["likedBy"] as? [String] ?? []
        self.init(id: document.documentID,
                  userId: userId,
                  displayName: (data["displayName"] as? String) ?? "Unknown",
                  username: (data["username"] as? String) ?? "",
                  type: type,
                  summary: summary,
                  createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                  payload: data["payload"] as? [String: Any] ?? [:],
                  entityId: data["entityId"] as? String,
                  profileImageData: nil,
                  likeCount: likedBy.count,
                  likedBy: likedBy)
    }
    
    init(id: String,
         userId: String,
         displayName: String,
         username: String,
         type: String,
         summary: String,
         createdAt: Date,
         payload: [String: Any],
         entityId: String?,
         profileImageData: Data?,
         likeCount: Int = 0,
         likedBy: [String] = []) {
        self.id = id
        self.userId = userId
        self.displayName = displayName
        self.username = username
        self.type = type
        self.summary = summary
        self.createdAt = createdAt
        self.payload = payload
        self.entityId = entityId
        self.profileImageData = profileImageData
        self.likeCount = likeCount
        self.likedBy = likedBy
    }
    
    func updatingProfile(displayName: String, username: String, imageData: Data?) -> FirebaseActivityItem {
        FirebaseActivityItem(id: id,
                             userId: userId,
                             displayName: displayName,
                             username: username,
                             type: type,
                             summary: summary,
                             createdAt: createdAt,
                             payload: payload,
                             entityId: entityId,
                             profileImageData: imageData,
                             likeCount: likeCount,
                             likedBy: likedBy)
    }
    
    func updatingLikes(likeCount: Int, likedBy: [String]) -> FirebaseActivityItem {
        FirebaseActivityItem(id: id,
                             userId: userId,
                             displayName: displayName,
                             username: username,
                             type: type,
                             summary: summary,
                             createdAt: createdAt,
                             payload: payload,
                             entityId: entityId,
                             profileImageData: profileImageData,
                             likeCount: likeCount,
                             likedBy: likedBy)
    }
    
    static func == (lhs: FirebaseActivityItem, rhs: FirebaseActivityItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Helpers

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        var result: [[Element]] = []
        var current: [Element] = []
        current.reserveCapacity(size)
        for element in self {
            current.append(element)
            if current.count == size {
                result.append(current)
                current.removeAll(keepingCapacity: true)
            }
        }
        if !current.isEmpty {
            result.append(current)
        }
        return result
    }
}

@MainActor
private func buildExerciseCache(context: ModelContext) -> [ExerciseType: Exercise] {
    var cache: [ExerciseType: Exercise] = [:]
    let existingExercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
    for exercise in existingExercises {
        cache[exercise.type] = exercise
    }
    return cache
}

@MainActor
private func ensureExercise(for type: ExerciseType,
                            context: ModelContext,
                            cache: inout [ExerciseType: Exercise]) -> Exercise {
    if let cached = cache[type] {
        return cached
    }
    let exercise = Exercise(type: type)
    context.insert(exercise)
    cache[type] = exercise
    return exercise
}

@MainActor
private func createTraining(from document: DocumentSnapshot,
                            context: ModelContext,
                            exerciseCache: inout [ExerciseType: Exercise]) -> Training? {
    guard let data = document.data() else { return nil }
    
    let date = timestampDate(data["date"]) ?? Date()
    let duration = intValue(data["duration"]) ?? 0
    let location = TrainingLocation(rawValue: data["location"] as? String ?? "") ?? .indoor
    let focus = TrainingFocus(rawValue: data["focus"] as? String ?? "") ?? .strength
    let notes = data["notes"] as? String ?? ""
    let isRecorded = data["isRecorded"] as? Bool ?? false
    let recordingStart = timestampDate(data["recordingStartTime"])
    let recordingEnd = timestampDate(data["recordingEndTime"])
    let totalRecordedDuration = intValue(data["totalRecordedDuration"])
    
    var recordedModels: [RecordedExercise] = []
    let recordedArray = dictionaryArray(from: data["recordedExercises"])
    for record in recordedArray {
        guard let typeRaw = record["type"] as? String,
              let exerciseType = ExerciseType(rawValue: typeRaw) else { continue }
        let exercise = ensureExercise(for: exerciseType, context: context, cache: &exerciseCache)
        let recordedExercise = createRecordedExercise(from: record, exercise: exercise)
        recordedModels.append(recordedExercise)
    }
    
    var mediaModels: [Media] = []
    let mediaArray = dictionaryArray(from: data["mediaItems"])
    for entry in mediaArray {
        guard let typeRaw = entry["type"] as? String,
              let mediaType = MediaType(rawValue: typeRaw) else { continue }
        
        let media = Media(type: mediaType)
        
        // Handle base64 or URL
        if let base64 = entry["base64"] as? String {
            // Store base64 with prefix for identification
            media.remoteURL = "base64:\(base64)"
            // Also decode and store as imageData for local use
            if let data = Data(base64Encoded: base64) {
                media.imageData = data
            }
        } else if let urlString = entry["url"] as? String {
        media.remoteURL = urlString
        } else {
            continue // Skip if no URL or base64
        }
        
        // Handle thumbnail
        if let thumbBase64 = entry["thumbnailBase64"] as? String {
            media.remoteThumbnailURL = "base64:\(thumbBase64)"
            if let thumbData = Data(base64Encoded: thumbBase64) {
                media.thumbnailData = thumbData
            }
        } else if let thumb = entry["thumbnailURL"] as? String {
            media.remoteThumbnailURL = thumb
        }
        
        if let isRoute = entry["isRouteSnapshot"] as? Bool {
            media.isRouteSnapshot = isRoute
        }
        media.date = date
        mediaModels.append(media)
    }
    
    let training = Training(date: date,
                            duration: duration,
                            location: location,
                            focus: focus,
                            recordedExercises: recordedModels,
                            notes: notes,
                            media: [],
                            isRecorded: isRecorded,
                            recordingStartTime: recordingStart,
                            syncIdentifier: document.documentID)
    training.recordingEndTime = recordingEnd
    if let total = totalRecordedDuration {
        training.totalRecordedDuration = total
    }
    
    training.media = mediaModels
    for media in mediaModels {
        media.training = training
    }
    
    return training
}

@MainActor
private func createRecordedExercise(from data: [String: Any],
                                    exercise: Exercise) -> RecordedExercise {
    let recorded = RecordedExercise(exercise: exercise)
    if let gripRaw = data["gripType"] as? String,
       let grip = GripType(rawValue: gripRaw) {
        recorded.gripType = grip
    }
    if let duration = intValue(data["duration"]) {
        recorded.duration = duration
    }
    if let repetitions = intValue(data["repetitions"]) {
        recorded.repetitions = repetitions
    }
    if let sets = intValue(data["sets"]) {
        recorded.sets = sets
    }
    if let weight = intValue(data["addedWeight"]) {
        recorded.addedWeight = weight
    }
    if let rest = intValue(data["restDuration"]) {
        recorded.restDuration = rest
    }
    if let grade = data["grade"] as? String {
        recorded.grade = grade
    }
    if let routes = intValue(data["routes"]) {
        recorded.routes = routes
    }
    if let attempts = intValue(data["attempts"]) {
        recorded.attempts = attempts
    }
    if let restBetween = intValue(data["restBetweenRoutes"]) {
        recorded.restBetweenRoutes = restBetween
    }
    if let sessionDuration = intValue(data["sessionDuration"]) {
        recorded.sessionDuration = sessionDuration
    }
    if let boardRaw = data["boardType"] as? String,
       let board = BoardType(rawValue: boardRaw) {
        recorded.boardType = board
    }
    if let gradeTried = data["gradeTried"] as? String {
        recorded.gradeTried = gradeTried
    }
    if let moves = intValue(data["moves"]) {
        recorded.moves = moves
    }
    if let weight = intValue(data["weight"]) {
        recorded.weight = weight
    }
    if let edgeSize = intValue(data["edgeSize"]) {
        recorded.edgeSize = edgeSize
    }
    if let hours = intValue(data["hours"]) {
        recorded.hours = hours
    }
    if let minutes = intValue(data["minutes"]) {
        recorded.minutes = minutes
    }
    if let distance = doubleValue(data["distance"]) {
        recorded.distance = distance
    }
    if let notes = data["notes"] as? String {
        recorded.notes = notes
    }
    if let start = timestampDate(data["recordedStartTime"]) {
        recorded.recordedStartTime = start
    }
    if let end = timestampDate(data["recordedEndTime"]) {
        recorded.recordedEndTime = end
    }
    if let recordedDuration = intValue(data["recordedDuration"]) {
        recorded.recordedDuration = recordedDuration
    }
    if let paused = intValue(data["pausedDuration"]) {
        recorded.pausedDuration = paused
    }
    if let isCompleted = data["isCompleted"] as? Bool {
        recorded.isCompleted = isCompleted
    }
    if let selected = data["selectedDetailOptionsData"] as? String {
        recorded.selectedDetailOptionsData = selected
    }
    recorded.hamstrings = data["hamstrings"] as? Bool ?? false
    recorded.hips = data["hips"] as? Bool ?? false
    recorded.forearms = data["forearms"] as? Bool ?? false
    recorded.legs = data["legs"] as? Bool ?? false
    if let pullupData = data["pullupSetsData"] as? String {
        recorded.pullupSetsData = pullupData
    }
    if let nxnData = data["nxnSetsData"] as? String {
        recorded.nxnSetsData = nxnData
    }
    if let boardRoutes = data["boardClimbingRoutesData"] as? String {
        recorded.boardClimbingRoutesData = boardRoutes
    }
    if let shoulderData = data["shoulderLiftsSetsData"] as? String {
        recorded.shoulderLiftsSetsData = shoulderData
    }
    if let repeatersData = data["repeatersSetsData"] as? String {
        recorded.repeatersSetsData = repeatersData
    }
    if let edgePickupsData = data["edgePickupsSetsData"] as? String {
        recorded.edgePickupsSetsData = edgePickupsData
    }
    if let limitData = data["limitBoulderingRoutesData"] as? String {
        recorded.limitBoulderingRoutesData = limitData
    }
    if let maxHangsData = data["maxHangsSetsData"] as? String {
        recorded.maxHangsSetsData = maxHangsData
    }
    if let campusData = data["boulderCampusSetsData"] as? String {
        recorded.boulderCampusSetsData = campusData
    }
    if let deadliftData = data["deadliftsSetsData"] as? String {
        recorded.deadliftsSetsData = deadliftData
    }
    if let benchmarkData = data["benchmarkResultsData"] as? String {
        recorded.benchmarkResultsData = benchmarkData
    }
    return recorded
}

@MainActor
private func createRunningSession(from document: DocumentSnapshot,
                                  context: ModelContext) -> RunningSession? {
    guard let data = document.data() else { return nil }
    
    let startTime = timestampDate(data["startTime"]) ?? Date()
    let endTime = timestampDate(data["endTime"])
    let duration = doubleValue(data["duration"]) ?? 0
    let distance = doubleValue(data["distance"]) ?? 0
    let averagePace = doubleValue(data["averagePace"]) ?? 0
    let maxSpeed = doubleValue(data["maxSpeed"]) ?? 0
    let averageSpeed = doubleValue(data["averageSpeed"]) ?? 0
    let calories = intValue(data["calories"]) ?? 0
    let elevationGain = doubleValue(data["elevationGain"]) ?? 0
    let elevationLoss = doubleValue(data["elevationLoss"]) ?? 0
    let notes = data["notes"] as? String ?? ""
    
    let run = RunningSession(startTime: startTime,
                             endTime: endTime,
                             duration: duration,
                             distance: distance,
                             averagePace: averagePace,
                             calories: calories,
                             elevationGain: elevationGain,
                             elevationLoss: elevationLoss,
                             maxSpeed: maxSpeed,
                             averageSpeed: averageSpeed,
                             notes: notes,
                             media: [],
                             syncIdentifier: document.documentID)
    
    if let routeData = dataFromBase64(data["routeData"]) {
        run.routeDataJSON = routeData
    }
    if let splitsData = dataFromBase64(data["splitsData"]) {
        run.splitsDataJSON = splitsData
    }
    
    let mediaEntries = dictionaryArray(from: data["mediaItems"])
    var mediaItems: [Media] = []
    for entry in mediaEntries {
        guard let typeRaw = entry["type"] as? String,
              let mediaType = MediaType(rawValue: typeRaw) else { continue }
        
        let media = Media(type: mediaType)
        
        // Handle base64 or URL
        if let base64 = entry["base64"] as? String {
            // Store base64 with prefix for identification
            media.remoteURL = "base64:\(base64)"
            // Also decode and store as imageData for local use
            if let data = Data(base64Encoded: base64) {
                media.imageData = data
            }
        } else if let urlString = entry["url"] as? String {
        media.remoteURL = urlString
        } else {
            continue // Skip if no URL or base64
        }
        
        // Handle thumbnail
        if let thumbBase64 = entry["thumbnailBase64"] as? String {
            media.remoteThumbnailURL = "base64:\(thumbBase64)"
            if let thumbData = Data(base64Encoded: thumbBase64) {
                media.thumbnailData = thumbData
            }
        } else if let thumb = entry["thumbnailURL"] as? String {
            media.remoteThumbnailURL = thumb
        }
        
        if let isRoute = entry["isRouteSnapshot"] as? Bool {
            media.isRouteSnapshot = isRoute
        }
        media.date = startTime
        media.runningSession = run
        mediaItems.append(media)
    }
    run.media = mediaItems
    
    return run
}

private func dictionaryArray(from value: Any?) -> [[String: Any]] {
    if let array = value as? [[String: Any]] {
        return array
    }
    if let array = value as? [Any] {
        return array.compactMap { $0 as? [String: Any] }
    }
    return []
}

private func intValue(_ value: Any?) -> Int? {
    switch value {
    case let int as Int:
        return int
    case let double as Double:
        return Int(double)
    case let number as NSNumber:
        return number.intValue
    default:
        return nil
    }
}

private func doubleValue(_ value: Any?) -> Double? {
    switch value {
    case let double as Double:
        return double
    case let int as Int:
        return Double(int)
    case let number as NSNumber:
        return number.doubleValue
    default:
        return nil
    }
}

private func timestampDate(_ value: Any?) -> Date? {
    if let timestamp = value as? Timestamp {
        return timestamp.dateValue()
    }
    if let date = value as? Date {
        return date
    }
    return nil
}

private func dataFromBase64(_ value: Any?) -> Data? {
    if let string = value as? String {
        return Data(base64Encoded: string)
    }
    return nil
}

private extension RecordedExercise {
    func toSyncDictionary() -> [String: Any] {
        var data: [String: Any] = [
            "type": exercise.type.rawValue
        ]
        if let focus = exercise.focus {
            data["focus"] = focus.rawValue
        }
        if let grip = gripType {
            data["gripType"] = grip.rawValue
        }
        if let duration = duration { data["duration"] = duration }
        if let repetitions = repetitions { data["repetitions"] = repetitions }
        if let sets = sets { data["sets"] = sets }
        if let addedWeight = addedWeight { data["addedWeight"] = addedWeight }
        if let rest = restDuration { data["restDuration"] = rest }
        if let grade = grade { data["grade"] = grade }
        if let routes = routes { data["routes"] = routes }
        if let attempts = attempts { data["attempts"] = attempts }
        if let restBetweenRoutes = restBetweenRoutes { data["restBetweenRoutes"] = restBetweenRoutes }
        if let sessionDuration = sessionDuration { data["sessionDuration"] = sessionDuration }
        if let board = boardType { data["boardType"] = board.rawValue }
        if let gradeTried = gradeTried { data["gradeTried"] = gradeTried }
        if let moves = moves { data["moves"] = moves }
        if let weight = weight { data["weight"] = weight }
        if let edgeSize = edgeSize { data["edgeSize"] = edgeSize }
        if hours != nil { data["hours"] = hours }
        if minutes != nil { data["minutes"] = minutes }
        if let distance = distance { data["distance"] = distance }
        if let notes = notes, !notes.isEmpty { data["notes"] = notes }
        if let start = recordedStartTime { data["recordedStartTime"] = Timestamp(date: start) }
        if let end = recordedEndTime { data["recordedEndTime"] = Timestamp(date: end) }
        if let recordedDuration = recordedDuration { data["recordedDuration"] = recordedDuration }
        data["pausedDuration"] = pausedDuration
        data["isCompleted"] = isCompleted
        if !selectedDetailOptionsData.isEmpty { data["selectedDetailOptionsData"] = selectedDetailOptionsData }
        data["hamstrings"] = hamstrings
        data["hips"] = hips
        data["forearms"] = forearms
        data["legs"] = legs
        if !pullupSetsData.isEmpty { data["pullupSetsData"] = pullupSetsData }
        if !nxnSetsData.isEmpty { data["nxnSetsData"] = nxnSetsData }
        if !boardClimbingRoutesData.isEmpty { data["boardClimbingRoutesData"] = boardClimbingRoutesData }
        if !shoulderLiftsSetsData.isEmpty { data["shoulderLiftsSetsData"] = shoulderLiftsSetsData }
        if !repeatersSetsData.isEmpty { data["repeatersSetsData"] = repeatersSetsData }
        if !edgePickupsSetsData.isEmpty { data["edgePickupsSetsData"] = edgePickupsSetsData }
        if !limitBoulderingRoutesData.isEmpty { data["limitBoulderingRoutesData"] = limitBoulderingRoutesData }
        if !maxHangsSetsData.isEmpty { data["maxHangsSetsData"] = maxHangsSetsData }
        if !boulderCampusSetsData.isEmpty { data["boulderCampusSetsData"] = boulderCampusSetsData }
        if !deadliftsSetsData.isEmpty { data["deadliftsSetsData"] = deadliftsSetsData }
        if !benchmarkResultsData.isEmpty { data["benchmarkResultsData"] = benchmarkResultsData }
        return data
    }
}

extension FirebaseSyncManager {
    @MainActor
    private func uploadRunMedia(for run: RunningSession, user: FirebaseAuth.User, context: ModelContext) async -> [[String: Any]] {
        // Validation checks
        guard let runId = run.syncIdentifier else {
            print("⚠️ Cannot upload run media: missing syncIdentifier for run")
            return []
        }
        
        var mediaPayload: [[String: Any]] = []
        let basePath = "users/\(user.uid)/runs/\(runId)"
        var didUpdate = false

        for media in run.media {
            var remoteURL = media.remoteURL
            var remoteThumb = media.remoteThumbnailURL

            // Skip if already uploaded
            if remoteURL != nil {
                // Ensure state is set to uploaded if we have a remote URL
                if media.uploadStateEnum != .uploaded {
                    media.uploadStateEnum = .uploaded
                    media.uploadError = nil
                    media.uploadProgress = 1.0
                    didUpdate = true
                }
            } else {
                // Check if media data exists
                let hasImageData = media.type == .image && media.imageData != nil
                let hasVideoData = media.type == .video && media.videoData != nil
                
                guard hasImageData || hasVideoData else {
                    print("⚠️ Cannot upload media \(media.id.uuidString): missing data for type \(media.type.rawValue)")
                    media.uploadStateEnum = .failed
                    media.uploadError = "Missing media data"
                    didUpdate = true
                    continue
                }
                
                // Set uploading state
                media.uploadStateEnum = .uploading
                media.uploadProgress = 0.0
                media.uploadError = nil
                didUpdate = true
                
                if media.type == .image, let data = media.imageData {
                    // Store as base64 in Firestore (like profile images)
                    let maxRawBytes = 600_000
                    var imageData = data
                    if data.count > maxRawBytes {
                        if let compressed = compressImageData(data, maxBytes: maxRawBytes) {
                            imageData = compressed
                        }
                    }
                    let base64 = imageData.base64EncodedString()
                    remoteURL = "base64:\(base64)"
                        media.remoteURL = remoteURL
                    media.uploadStateEnum = .uploaded
                    media.uploadProgress = 1.0
                    media.uploadError = nil
                        didUpdate = true
                    print("✅ Successfully stored run image as base64: \(media.id.uuidString)")
                } else if media.type == .video, let data = media.videoData {
                    let metadata = StorageMetadata()
                    metadata.contentType = "video/mp4"
                    let path = "\(basePath)/\(media.id.uuidString).mp4"
                    let ref = storage.reference(withPath: path)
                    do {
                        media.uploadProgress = 0.5
                        _ = try await ref.putDataAsync(data, metadata: metadata)
                        remoteURL = try await ref.downloadURL().absoluteString
                        media.remoteURL = remoteURL
                        media.storagePath = path
                        media.uploadStateEnum = .uploaded
                        media.uploadProgress = 1.0
                        media.uploadError = nil
                        didUpdate = true
                        print("✅ Successfully uploaded run video media: \(media.id.uuidString)")
                    } catch {
                        let errorMsg = "Failed to upload video: \(error.localizedDescription)"
                        print("❌ \(errorMsg) - Media ID: \(media.id.uuidString), Run ID: \(runId)")
                        media.uploadStateEnum = .failed
                        media.uploadError = errorMsg
                        media.uploadProgress = nil
                        didUpdate = true
                    }
                }
            }

            if media.type == .video, media.remoteThumbnailURL == nil, let thumbData = media.thumbnailData {
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                let thumbPath = "\(basePath)/\(media.id.uuidString)_thumb.jpg"
                let ref = storage.reference(withPath: thumbPath)
                do {
                    _ = try await ref.putDataAsync(thumbData, metadata: metadata)
                    let url = try await ref.downloadURL().absoluteString
                    media.remoteThumbnailURL = url
                    media.thumbnailStoragePath = thumbPath
                    remoteThumb = url
                    didUpdate = true
                } catch {
                    print("Failed to upload run video thumbnail: \(error.localizedDescription)")
                }
            }

            if let remoteURL {
                var entry: [String: Any] = [
                    "id": media.id.uuidString,
                    "type": media.type.rawValue
                ]
                
                // Store base64 directly if it's a base64 string, otherwise use URL
                if remoteURL.hasPrefix("base64:") {
                    let base64String = String(remoteURL.dropFirst(7)) // Remove "base64:" prefix
                    entry["base64"] = base64String
                } else {
                    entry["url"] = remoteURL
                }
                
                if let remoteThumb {
                    if remoteThumb.hasPrefix("base64:") {
                        entry["thumbnailBase64"] = String(remoteThumb.dropFirst(7))
                    } else {
                    entry["thumbnailURL"] = remoteThumb
                    }
                }
                if media.isRouteSnapshot {
                    entry["isRouteSnapshot"] = true
                }
                mediaPayload.append(entry)
            }
        }

        if didUpdate, context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save run media remote info: \(error.localizedDescription)")
            }
        }

        return mediaPayload
    }

    @MainActor
    private func uploadTrainingMedia(for training: Training, user: FirebaseAuth.User, context: ModelContext) async -> [[String: Any]] {
        // Validation checks
        guard let trainingId = training.syncIdentifier else {
            print("⚠️ Cannot upload training media: missing syncIdentifier for training")
            return []
        }
        
        var mediaPayload: [[String: Any]] = []
        let basePath = "users/\(user.uid)/trainings/\(trainingId)"
        var didUpdate = false

        for media in training.media {
            var remoteURL = media.remoteURL
            var remoteThumb = media.remoteThumbnailURL

            // Skip if already uploaded
            if remoteURL != nil {
                // Ensure state is set to uploaded if we have a remote URL
                if media.uploadStateEnum != .uploaded {
                    media.uploadStateEnum = .uploaded
                    media.uploadError = nil
                    media.uploadProgress = 1.0
                    didUpdate = true
                }
            } else {
                // Check if media data exists
                let hasImageData = media.type == .image && media.imageData != nil
                let hasVideoData = media.type == .video && media.videoData != nil
                
                guard hasImageData || hasVideoData else {
                    print("⚠️ Cannot upload media \(media.id.uuidString): missing data for type \(media.type.rawValue)")
                    media.uploadStateEnum = .failed
                    media.uploadError = "Missing media data"
                    didUpdate = true
                    continue
                }
                
                // Set uploading state
                media.uploadStateEnum = .uploading
                media.uploadProgress = 0.0
                media.uploadError = nil
                didUpdate = true
                
                if media.type == .image, let data = media.imageData {
                    // Store as base64 in Firestore (like profile images)
                    let maxRawBytes = 600_000
                    var imageData = data
                    if data.count > maxRawBytes {
                        if let compressed = compressImageData(data, maxBytes: maxRawBytes) {
                            imageData = compressed
                        }
                    }
                    let base64 = imageData.base64EncodedString()
                    remoteURL = "base64:\(base64)"
                        media.remoteURL = remoteURL
                    media.uploadStateEnum = .uploaded
                    media.uploadProgress = 1.0
                    media.uploadError = nil
                        didUpdate = true
                    print("✅ Successfully stored image as base64: \(media.id.uuidString)")
                } else if media.type == .video, let data = media.videoData {
                    let metadata = StorageMetadata()
                    metadata.contentType = "video/mp4"
                    let path = "\(basePath)/\(media.id.uuidString).mp4"
                    let ref = storage.reference(withPath: path)
                    do {
                        media.uploadProgress = 0.5
                        _ = try await ref.putDataAsync(data, metadata: metadata)
                        remoteURL = try await ref.downloadURL().absoluteString
                        media.remoteURL = remoteURL
                        media.storagePath = path
                        media.uploadStateEnum = .uploaded
                        media.uploadProgress = 1.0
                        media.uploadError = nil
                        didUpdate = true
                        print("✅ Successfully uploaded video media: \(media.id.uuidString)")
                    } catch {
                        let errorMsg = "Failed to upload video: \(error.localizedDescription)"
                        print("❌ \(errorMsg) - Media ID: \(media.id.uuidString), Training ID: \(trainingId)")
                        media.uploadStateEnum = .failed
                        media.uploadError = errorMsg
                        media.uploadProgress = nil
                        didUpdate = true
                    }
                }
            }

            if media.type == .video, media.remoteThumbnailURL == nil, let thumbData = media.thumbnailData {
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                let thumbPath = "\(basePath)/\(media.id.uuidString)_thumb.jpg"
                let ref = storage.reference(withPath: thumbPath)
                do {
                    _ = try await ref.putDataAsync(thumbData, metadata: metadata)
                    let url = try await ref.downloadURL().absoluteString
                    media.remoteThumbnailURL = url
                    media.thumbnailStoragePath = thumbPath
                    didUpdate = true
                    remoteThumb = url
                } catch {
                    print("Failed to upload video thumbnail: \(error.localizedDescription)")
                }
            }

            if let remoteURL {
                var entry: [String: Any] = [
                    "id": media.id.uuidString,
                    "type": media.type.rawValue
                ]
                
                // Store base64 directly if it's a base64 string, otherwise use URL
                if remoteURL.hasPrefix("base64:") {
                    let base64String = String(remoteURL.dropFirst(7)) // Remove "base64:" prefix
                    entry["base64"] = base64String
                } else {
                    entry["url"] = remoteURL
                }
                
                if let remoteThumb {
                    if remoteThumb.hasPrefix("base64:") {
                        entry["thumbnailBase64"] = String(remoteThumb.dropFirst(7))
                    } else {
                    entry["thumbnailURL"] = remoteThumb
                    }
                }
                mediaPayload.append(entry)
            }
        }

        if didUpdate, context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save media remote info: \(error.localizedDescription)")
            }
        }

        return mediaPayload
    }

    func deleteRemoteMediaIfNeeded(media: Media) async {
        // Delete from Firebase Storage
        if let path = media.storagePath {
        let ref = storage.reference(withPath: path)
        do {
            try await ref.delete()
                print("✅ Deleted media from Firebase Storage: \(path)")
        } catch {
                print("❌ Failed to delete remote media: \(error.localizedDescription)")
            }
        }
        if let thumbPath = media.thumbnailStoragePath {
            let thumbRef = storage.reference(withPath: thumbPath)
            do {
                try await thumbRef.delete()
                print("✅ Deleted thumbnail from Firebase Storage: \(thumbPath)")
            } catch {
                print("❌ Failed to delete remote thumbnail: \(error.localizedDescription)")
            }
        }
        
        // Update activity feed to remove media
        await updateActivityFeedAfterMediaDeletion(media: media)
    }
    
    @MainActor
    private func updateActivityFeedAfterMediaDeletion(media: Media) async {
        guard let user = Auth.auth().currentUser else { return }
        
        if let training = media.training, let trainingId = training.syncIdentifier {
            // Update training document in Firestore
            let trainingDoc = db.collection("users").document(user.uid).collection("trainings").document(trainingId)
            do {
                let document = try await trainingDoc.getDocument()
                if var data = document.data(), var mediaItems = data["mediaItems"] as? [[String: Any]] {
                    mediaItems.removeAll { item in
                        (item["id"] as? String) == media.id.uuidString
                    }
                    data["mediaItems"] = mediaItems.isEmpty ? FieldValue.delete() : mediaItems
                    data["updatedAt"] = FieldValue.serverTimestamp()
                    try await trainingDoc.setData(data, merge: true)
                    print("✅ Updated training document after media deletion")
                }
            } catch {
                print("⚠️ Failed to update training document: \(error.localizedDescription)")
            }
            
            // Update activity feed
            let docId = "training_\(trainingId)"
            let activityDoc = db.collection("activities").document(docId)
            do {
                let document = try await activityDoc.getDocument()
                guard var data = document.data() else { return }
                
                var payload = data["payload"] as? [String: Any] ?? [:]
                var currentMedia = payload["mediaItems"] as? [[String: Any]] ?? []
                
                currentMedia.removeAll { item in
                    (item["id"] as? String) == media.id.uuidString
                }
                
                payload["mediaItems"] = currentMedia.isEmpty ? FieldValue.delete() : currentMedia
                data["payload"] = payload
                data["updatedAt"] = FieldValue.serverTimestamp()
                
                try await activityDoc.setData(data, merge: true)
                print("✅ Updated activity feed after media deletion")
            } catch {
                print("⚠️ Failed to update activity feed: \(error.localizedDescription)")
            }
        } else if let run = media.runningSession, let runId = run.syncIdentifier {
            // Update run document in Firestore
            let runDoc = db.collection("users").document(user.uid).collection("runs").document(runId)
            do {
                let document = try await runDoc.getDocument()
                if var data = document.data(), var mediaItems = data["mediaItems"] as? [[String: Any]] {
                    mediaItems.removeAll { item in
                        (item["id"] as? String) == media.id.uuidString
                    }
                    data["mediaItems"] = mediaItems.isEmpty ? FieldValue.delete() : mediaItems
                    data["updatedAt"] = FieldValue.serverTimestamp()
                    try await runDoc.setData(data, merge: true)
                    print("✅ Updated run document after media deletion")
                }
            } catch {
                print("⚠️ Failed to update run document: \(error.localizedDescription)")
            }
            
            // Update activity feed
            let docId = "run_\(runId)"
            let activityDoc = db.collection("activities").document(docId)
            do {
                let document = try await activityDoc.getDocument()
                guard var data = document.data() else { return }
                
                var payload = data["payload"] as? [String: Any] ?? [:]
                var currentMedia = payload["mediaItems"] as? [[String: Any]] ?? []
                
                currentMedia.removeAll { item in
                    (item["id"] as? String) == media.id.uuidString
                }
                
                payload["mediaItems"] = currentMedia.isEmpty ? FieldValue.delete() : currentMedia
                data["payload"] = payload
                data["updatedAt"] = FieldValue.serverTimestamp()
                
                try await activityDoc.setData(data, merge: true)
                print("✅ Updated activity feed after media deletion")
            } catch {
                print("⚠️ Failed to update activity feed: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    func retryMediaUpload(media: Media, context: ModelContext) async {
        await uploadMediaImmediately(media: media, context: context)
    }
    
    @MainActor
    func uploadMediaImmediately(media: Media, context: ModelContext) async {
        guard let user = Auth.auth().currentUser else {
            let errorMsg = "User not authenticated"
            print("⚠️ Cannot upload media: \(errorMsg)")
            media.uploadStateEnum = .failed
            media.uploadError = errorMsg
            if context.hasChanges {
                try? context.save()
            }
            return
        }
        
        // Determine if this is training or run media
        if let training = media.training {
            // Ensure sync identifier exists
            if training.syncIdentifier == nil || training.syncIdentifier?.isEmpty == true {
                // Try to ensure sync identifier
                let trainings = (try? context.fetch(FetchDescriptor<Training>())) ?? []
                ensureSyncIdentifiers(trainings: trainings, runs: [], plannedTrainings: [], plannedRuns: [], plannedBenchmarks: [], weightEntries: [], context: context)
            }
            
            guard let trainingId = training.syncIdentifier, !trainingId.isEmpty else {
                let errorMsg = "Training missing syncIdentifier"
                print("⚠️ Cannot upload media: \(errorMsg)")
                media.uploadStateEnum = .failed
                media.uploadError = errorMsg
                if context.hasChanges {
                    try? context.save()
                }
                return
            }
            
            let basePath = "users/\(user.uid)/trainings/\(trainingId)"
            await uploadSingleMedia(media: media, basePath: basePath, context: context)
            
            // Only update activity feed if upload was successful
            if media.uploadStateEnum == .uploaded {
                let settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first
                let mediaItems = await uploadTrainingMedia(for: training, user: user, context: context)
                uploadTrainingActivity(training, user: user, settings: settings, mediaItems: mediaItems)
            }
        } else if let run = media.runningSession {
            // Ensure sync identifier exists
            if run.syncIdentifier == nil || run.syncIdentifier?.isEmpty == true {
                // Try to ensure sync identifier
                let runs = (try? context.fetch(FetchDescriptor<RunningSession>())) ?? []
                ensureSyncIdentifiers(trainings: [], runs: runs, plannedTrainings: [], plannedRuns: [], plannedBenchmarks: [], weightEntries: [], context: context)
            }
            
            guard let runId = run.syncIdentifier, !runId.isEmpty else {
                let errorMsg = "Run missing syncIdentifier"
                print("⚠️ Cannot upload media: \(errorMsg)")
                media.uploadStateEnum = .failed
                media.uploadError = errorMsg
                if context.hasChanges {
                    try? context.save()
                }
                return
            }
            
            let basePath = "users/\(user.uid)/runs/\(runId)"
            await uploadSingleMedia(media: media, basePath: basePath, context: context)
            
            // Only update activity feed if upload was successful
            if media.uploadStateEnum == .uploaded {
                let settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first
                let mediaItems = await uploadRunMedia(for: run, user: user, context: context)
                uploadRunActivity(run, user: user, settings: settings, mediaItems: mediaItems)
            }
        } else {
            let errorMsg = "Media not associated with training or run"
            print("⚠️ Cannot upload media: \(errorMsg)")
            media.uploadStateEnum = .failed
            media.uploadError = errorMsg
            if context.hasChanges {
                try? context.save()
            }
        }
    }
    
    @MainActor
    private func uploadSingleMedia(media: Media, basePath: String, context: ModelContext) async {
        // Check if already uploaded (has base64 stored or remote URL)
        if let existingURL = media.remoteURL, !existingURL.isEmpty {
            print("ℹ️ Media already uploaded: \(media.id.uuidString)")
            media.uploadStateEnum = .uploaded
            media.uploadProgress = 1.0
            media.uploadError = nil
            if context.hasChanges {
                try? context.save()
            }
            return
        }
        
        // Validate media data exists
        let hasImageData = media.type == .image && media.imageData != nil
        let hasVideoData = media.type == .video && media.videoData != nil
        
        guard hasImageData || hasVideoData else {
            let errorMsg = "Missing media data for \(media.type.rawValue)"
            print("❌ \(errorMsg) - Media ID: \(media.id.uuidString)")
            media.uploadStateEnum = .failed
            media.uploadError = errorMsg
            media.uploadProgress = nil
            if context.hasChanges {
                try? context.save()
            }
            return
        }
        
        // Reset state and start upload
        media.uploadStateEnum = .uploading
        media.uploadProgress = 0.0
        media.uploadError = nil
        
        if context.hasChanges {
            try? context.save()
        }
        
        if media.type == .image, let data = media.imageData {
            // Store as base64 in Firestore (like profile images)
            let maxRawBytes = 600_000 // 600KB max for images
            let maxBase64Length = 1_000_000 // 1MB base64 string max
            
            // Compress image if needed
            var imageData = data
            if data.count > maxRawBytes {
                if let compressed = compressImageData(data, maxBytes: maxRawBytes) {
                    imageData = compressed
                    print("📦 Compressed image from \(data.count) to \(compressed.count) bytes")
                } else {
                    let errorMsg = "Image too large even after compression"
                    print("❌ \(errorMsg)")
                    media.uploadStateEnum = .failed
                    media.uploadError = errorMsg
                    media.uploadProgress = nil
                    if context.hasChanges {
                        try? context.save()
                    }
                    return
                }
            }
            
            let base64 = imageData.base64EncodedString()
            if base64.count <= maxBase64Length {
                // Store base64 directly - no need for Storage
                media.remoteURL = "base64:\(base64)" // Mark as base64 stored
                media.uploadStateEnum = .uploaded
                media.uploadProgress = 1.0
                media.uploadError = nil
                print("✅ Successfully stored image as base64: \(media.id.uuidString), size: \(base64.count) chars")
                
                // Save context
                if context.hasChanges {
                    do {
                        try context.save()
                        print("✅ Saved media state to context")
                    } catch {
                        print("⚠️ Failed to save media state: \(error.localizedDescription)")
                    }
                }
            } else {
                let errorMsg = "Image base64 string too large (\(base64.count) chars)"
                print("❌ \(errorMsg)")
                media.uploadStateEnum = .failed
                media.uploadError = errorMsg
                media.uploadProgress = nil
                if context.hasChanges {
                    try? context.save()
                }
            }
        } else if media.type == .video, let data = media.videoData {
            let metadata = StorageMetadata()
            metadata.contentType = "video/mp4"
            let path = "\(basePath)/\(media.id.uuidString).mp4"
            let ref = storage.reference(withPath: path)
            do {
                print("📤 Starting video upload: \(path), size: \(data.count) bytes")
                media.uploadProgress = 0.5
                _ = try await ref.putDataAsync(data, metadata: metadata)
                print("✅ Video uploaded to Storage, getting download URL...")
                let remoteURL = try await ref.downloadURL().absoluteString
                media.remoteURL = remoteURL
                media.storagePath = path
                media.uploadStateEnum = .uploaded
                media.uploadProgress = 1.0
                media.uploadError = nil
                
                // Upload thumbnail if needed
                if media.remoteThumbnailURL == nil, let thumbData = media.thumbnailData {
                    let thumbMetadata = StorageMetadata()
                    thumbMetadata.contentType = "image/jpeg"
                    let thumbPath = "\(basePath)/\(media.id.uuidString)_thumb.jpg"
                    let thumbRef = storage.reference(withPath: thumbPath)
                    do {
                        print("📤 Uploading video thumbnail...")
                        _ = try await thumbRef.putDataAsync(thumbData, metadata: thumbMetadata)
                        let thumbURL = try await thumbRef.downloadURL().absoluteString
                        media.remoteThumbnailURL = thumbURL
                        media.thumbnailStoragePath = thumbPath
                        print("✅ Thumbnail uploaded: \(thumbURL)")
                    } catch {
                        print("⚠️ Failed to upload thumbnail: \(error.localizedDescription)")
                    }
                }
                
                print("✅ Successfully uploaded video media: \(media.id.uuidString), URL: \(remoteURL)")
                
                // Save context
                if context.hasChanges {
                    try context.save()
                    print("✅ Saved media state to context")
                }
            } catch {
                let errorMsg = "Failed to upload video: \(error.localizedDescription)"
                print("❌ Upload failed: \(errorMsg)")
                print("   Error details: \(error)")
                if let nsError = error as NSError? {
                    print("   Domain: \(nsError.domain), Code: \(nsError.code)")
                    print("   UserInfo: \(nsError.userInfo)")
                }
                media.uploadStateEnum = .failed
                media.uploadError = errorMsg
                media.uploadProgress = nil
                
                // Save failed state
                if context.hasChanges {
                    try? context.save()
                }
            }
        } else {
            // This shouldn't happen due to validation above, but just in case
            let errorMsg = "Unknown media type or missing data"
            print("❌ \(errorMsg) - Media ID: \(media.id.uuidString), Type: \(media.type.rawValue)")
            media.uploadStateEnum = .failed
            media.uploadError = errorMsg
            media.uploadProgress = nil
            if context.hasChanges {
                try? context.save()
            }
        }
    }
}

// MARK: - Image Compression Helper

private func compressImageData(_ data: Data, maxBytes: Int = 600_000) -> Data? {
    guard var image = UIImage(data: data) else { return data.count <= maxBytes ? data : nil }
    var compression: CGFloat = 0.8
    var result = image.jpegData(compressionQuality: compression)
    while let current = result, current.count > maxBytes, compression > 0.1 {
        compression -= 0.1
        result = image.jpegData(compressionQuality: compression)
    }
    var scaleAttempts = 0
    while let current = result, current.count > maxBytes, scaleAttempts < 4 {
        guard let scaled = image.resized(to: CGSize(width: image.size.width * 0.7, height: image.size.height * 0.7)) else { break }
        image = scaled
        compression = 0.8
        result = image.jpegData(compressionQuality: compression)
        while let inner = result, inner.count > maxBytes, compression > 0.1 {
            compression -= 0.1
            result = image.jpegData(compressionQuality: compression)
        }
        scaleAttempts += 1
    }
    if let result, result.count <= maxBytes {
        return result
    }
    return nil
}

private extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

private extension FirebaseSyncManager {
    func fetchProfiles(for ids: Set<String>) async throws -> [String: FirebaseUserProfile] {
        guard !ids.isEmpty else { return [:] }
        var result: [String: FirebaseUserProfile] = [:]
        let chunks = Array(ids).chunked(into: 10)
        for chunk in chunks {
            let snapshot = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            for document in snapshot.documents {
                if let profile = FirebaseUserProfile(document: document) {
                    result[profile.id] = profile
                }
            }
        }
        return result
    }
}

