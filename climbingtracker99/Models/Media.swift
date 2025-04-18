import Foundation
import SwiftData
import SwiftUI

@Model
final class Media: Identifiable {
    var id: UUID
    var type: MediaType
    @Attribute(.externalStorage) var imageData: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?
    var date: Date
    var training: Training?
    
    init(type: MediaType, imageData: Data? = nil, thumbnailData: Data? = nil) {
        self.id = UUID()
        self.type = type
        self.imageData = imageData
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
}

enum MediaType: String, Codable {
    case image
    case video
} 