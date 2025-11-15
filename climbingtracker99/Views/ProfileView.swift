import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var settings: UserSettings
    
    @State private var displayName: String = ""
    @State private var handle: String = ""
    @State private var bio: String = ""
    @State private var profileImageData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isSaving = false
    
    private let handleCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._"))
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 16) {
                        ZStack {
                            if let data = profileImageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                Text(initials)
                                    .font(.system(size: 36, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                        )
                        
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                            Text("Change Photo")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                
                Section(header: Text("Profile")) {
                    TextField("Display Name", text: $displayName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                    TextField("Username", text: Binding(
                        get: { handle },
                        set: { newValue in
                            let filtered = newValue.lowercased().filter { char in
                                String(char).rangeOfCharacter(from: handleCharacterSet) != nil
                            }
                            handle = String(filtered.prefix(24))
                        }
                    ))
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .font(.body)
                    TextEditor(text: $bio)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2))
                        )
                        .padding(.vertical, 4)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { saveProfile() }
                            .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                guard let item = newValue else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let compressed = compressImageData(data) {
                        await MainActor.run {
                            self.profileImageData = compressed
                        }
                    } else {
                        await MainActor.run {
                            self.profileImageData = nil
                        }
                    }
                }
            }
            .onAppear {
                displayName = settings.userName
                handle = settings.handle
                bio = settings.bio
                profileImageData = settings.profileImageData
            }
        }
    }
    
    private var initials: String {
        let components = displayName.split(separator: " ")
        if components.count >= 2 {
            return String(components.prefix(2).compactMap { $0.first }).uppercased()
        } else if let first = displayName.first {
            return String(first).uppercased()
        } else {
            return "YOU"
        }
    }
    
    private func saveProfile() {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        isSaving = true
        settings.userName = trimmedName
        settings.handle = handle
        settings.bio = bio
        settings.profileImageData = profileImageData
        settings.lastProfileUpdated = Date()
        do {
            try modelContext.save()
        } catch {
            // Log but continue
            print("Failed to save profile: \(error)")
        }
        FirebaseSyncManager.shared.uploadProfile(settings: settings)
        isSaving = false
        dismiss()
    }
}

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
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

