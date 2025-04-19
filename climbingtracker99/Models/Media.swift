import Foundation
import SwiftData
import SwiftUI
import AVKit

@Model
final class Media: Identifiable {
    var id: UUID
    var type: MediaType
    @Attribute(.externalStorage) var imageData: Data?
    @Attribute(.externalStorage) var videoData: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?
    var date: Date
    var training: Training?
    
    init(type: MediaType, imageData: Data? = nil, videoData: Data? = nil, thumbnailData: Data? = nil) {
        self.id = UUID()
        self.type = type
        self.imageData = imageData
        self.videoData = videoData
        self.thumbnailData = thumbnailData
        self.date = Date()
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
}

enum MediaType: String, Codable, CaseIterable {
    case image
    case video
} 