import Foundation
import SwiftData
import SwiftUI
import AVKit

enum MediaType: String, Codable, CaseIterable {
    case image
    case video
}

enum UploadState: String, Codable {
    case pending
    case uploading
    case uploaded
    case failed
}

@Model
final class Media: Identifiable {
    var id: UUID
    var type: MediaType
    @Attribute(.externalStorage) var imageData: Data?
    @Attribute(.externalStorage) var videoData: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?
    var date: Date
    var training: Training?
    var runningSession: RunningSession?
    var remoteURL: String?
    var remoteThumbnailURL: String?
    var storagePath: String?
    var thumbnailStoragePath: String?
    var isRouteSnapshot: Bool
    var uploadState: String // UploadState rawValue for SwiftData compatibility
    var uploadError: String?
    var uploadProgress: Double?
    
    init(type: MediaType, imageData: Data? = nil, videoData: Data? = nil, thumbnailData: Data? = nil) {
        self.id = UUID()
        self.type = type
        self.imageData = imageData
        self.videoData = videoData
        self.thumbnailData = thumbnailData
        self.date = Date()
        self.remoteURL = nil
        self.remoteThumbnailURL = nil
        self.storagePath = nil
        self.thumbnailStoragePath = nil
        self.isRouteSnapshot = false
        self.uploadState = UploadState.pending.rawValue
        self.uploadError = nil
        self.uploadProgress = nil
    }
    
    var image: Image? {
        guard let imageData = imageData,
              let uiImage = UIImage(data: imageData) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
    
    var thumbnail: Image? {
        if let thumbnailData = thumbnailData,
           let uiImage = UIImage(data: thumbnailData) {
            return Image(uiImage: uiImage)
        }
        return image
    }
    
    var videoURL: URL? {
        guard let videoData = videoData else { return nil }
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("\(id).mp4")
        try? videoData.write(to: tempFile)
        return tempFile
    }
    
    func generateThumbnail() async throws -> Data? {
        guard let videoData = videoData else { return nil }
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("\(id).mp4")
        try videoData.write(to: tempFile)
        
        let asset = AVURLAsset(url: tempFile)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        
        return try await withCheckedThrowingContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { image, actualTime, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let cgImage = image else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let uiImage = UIImage(cgImage: cgImage)
                if let data = uiImage.jpegData(compressionQuality: 0.8) {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // Convenience computed properties for upload state
    var uploadStateEnum: UploadState {
        get {
            UploadState(rawValue: uploadState) ?? .pending
        }
        set {
            uploadState = newValue.rawValue
        }
    }
    
    var isUploaded: Bool {
        uploadStateEnum == .uploaded || remoteURL != nil
    }
    
    var isUploading: Bool {
        uploadStateEnum == .uploading
    }
    
    var hasUploadFailed: Bool {
        uploadStateEnum == .failed
    }
} 