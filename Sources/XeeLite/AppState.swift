import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var imageURLs: [URL] = []
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var currentImage: NSImage?
    @Published private(set) var currentImageURL: URL?
    @Published private(set) var currentImagePixelSize: CGSize?
    @Published private(set) var currentImageFileSize: Int64?
    @Published private(set) var currentMetadata = ImageMetadata(sections: [])
    @Published private(set) var currentAnimatedImage: AnimatedImage?
    @Published private(set) var renameRequestID: UInt64 = 0

    func openImagePicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = []

        if panel.runModal() == .OK, let url = panel.url {
            loadImage(at: url)
        }
    }

    func loadInitialImage() {
        if let path = CommandLine.arguments.dropFirst().first {
            loadImage(at: URL(fileURLWithPath: path))
            return
        }

        openImagePicker()
    }

    func loadImage(at url: URL) {
        let standardizedURL = url.standardizedFileURL
        let folderURL = standardizedURL.deletingLastPathComponent()

        do {
            let folderContents = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            let images = folderContents
                .filter { SupportedImageFormats.folderExtensions.contains($0.pathExtension.lowercased()) }
                .sorted {
                    $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
                }

            guard !images.isEmpty else {
                setSingleImage(url: standardizedURL)
                return
            }

            imageURLs = images
            currentIndex = images.firstIndex(of: standardizedURL) ?? 0
            updateDisplayedImage()
        } catch {
            imageURLs = []
            currentIndex = 0
            setSingleImage(url: standardizedURL, error: error)
        }
    }

    func showPreviousImage() {
        guard canShowPrevious else { return }
        currentIndex -= 1
        updateDisplayedImage()
    }

    func showNextImage() {
        guard canShowNext else { return }
        currentIndex += 1
        updateDisplayedImage()
    }

    func showFirstImage() {
        guard !imageURLs.isEmpty, currentIndex != 0 else { return }
        currentIndex = 0
        updateDisplayedImage()
    }

    func showLastImage() {
        guard let lastIndex = imageURLs.indices.last, currentIndex != lastIndex else { return }
        currentIndex = lastIndex
        updateDisplayedImage()
    }

    func jumpImages(by delta: Int) {
        guard !imageURLs.isEmpty, delta != 0 else { return }

        let nextIndex = min(max(currentIndex + delta, 0), imageURLs.count - 1)
        guard nextIndex != currentIndex else { return }

        currentIndex = nextIndex
        updateDisplayedImage()
    }

    var canShowPrevious: Bool {
        currentIndex > 0
    }

    var canShowNext: Bool {
        currentIndex + 1 < imageURLs.count
    }

    var canRenameCurrentImage: Bool {
        currentImageURL != nil
    }

    var currentImagePositionText: String? {
        guard imageURLs.indices.contains(currentIndex) else { return nil }
        return "\(currentIndex + 1)/\(imageURLs.count)"
    }

    var currentImageFormatText: String? {
        guard let pathExtension = currentImageURL?.pathExtension.lowercased(), !pathExtension.isEmpty else { return nil }
        return SupportedImageFormats.displayName(for: pathExtension)
    }

    func requestRenameCurrentImage() {
        guard canRenameCurrentImage else { return }
        renameRequestID &+= 1
    }

    func renameValidationMessage(forBaseName baseName: String) -> String? {
        guard let currentImageURL else {
            return RenameImageError.noImage.localizedDescription
        }

        return renameValidationMessage(forBaseName: baseName, imageURL: currentImageURL)
    }

    func renameValidationMessage(forBaseName baseName: String, imageURL: URL) -> String? {
        do {
            _ = try renamedImageURL(forBaseName: baseName, from: imageURL)
            return nil
        } catch let error as RenameImageError {
            return error.localizedDescription
        } catch {
            return error.localizedDescription
        }
    }

    func renameCurrentImage(toBaseName baseName: String) throws {
        guard let currentImageURL else {
            throw RenameImageError.noImage
        }

        try renameImage(at: currentImageURL, toBaseName: baseName)
    }

    func renameImage(at imageURL: URL, toBaseName baseName: String) throws {
        let destinationURL = try renamedImageURL(forBaseName: baseName, from: imageURL)
        guard destinationURL != imageURL else { return }

        let fileManager = FileManager.default

        do {
            if isCaseOnlyRename(from: imageURL, to: destinationURL) {
                let temporaryURL = uniqueTemporaryRenameURL(for: imageURL)
                try fileManager.moveItem(at: imageURL, to: temporaryURL)

                do {
                    try fileManager.moveItem(at: temporaryURL, to: destinationURL)
                } catch {
                    try? fileManager.moveItem(at: temporaryURL, to: imageURL)
                    throw error
                }
            } else {
                try fileManager.moveItem(at: imageURL, to: destinationURL)
            }
        } catch {
            throw RenameImageError.moveFailed(error)
        }

        loadImage(at: destinationURL)
    }

    private func updateDisplayedImage() {
        guard imageURLs.indices.contains(currentIndex) else {
            currentImage = nil
            currentImageURL = nil
            currentImagePixelSize = nil
            currentImageFileSize = nil
            currentMetadata = ImageMetadata(sections: [])
            currentAnimatedImage = nil
            return
        }

        let url = imageURLs[currentIndex]
        let animatedImage = AnimatedImageLoader.load(from: url)

        guard let image = animatedImage?.posterImage ?? NSImage(contentsOf: url) else {
            currentImage = nil
            currentImageURL = url
            currentImagePixelSize = nil
            currentImageFileSize = fileSize(for: url)
            currentMetadata = ImageMetadataLoader.load(from: url)
            currentAnimatedImage = animatedImage
            return
        }

        currentImage = image
        currentImageURL = url
        currentImagePixelSize = animatedImage?.pixelSize ?? pixelSize(for: image)
        currentImageFileSize = fileSize(for: url)
        currentMetadata = ImageMetadataLoader.load(from: url)
        currentAnimatedImage = animatedImage
    }

    private func setSingleImage(url: URL, error: Error? = nil) {
        imageURLs = [url]
        currentIndex = 0
        currentImageURL = url
        let animatedImage = AnimatedImageLoader.load(from: url)

        if let image = animatedImage?.posterImage ?? NSImage(contentsOf: url) {
            currentImage = image
            currentImagePixelSize = animatedImage?.pixelSize ?? pixelSize(for: image)
            currentImageFileSize = fileSize(for: url)
            currentMetadata = ImageMetadataLoader.load(from: url)
            currentAnimatedImage = animatedImage
        } else {
            currentImage = nil
            currentImagePixelSize = nil
            currentImageFileSize = fileSize(for: url)
            currentMetadata = ImageMetadataLoader.load(from: url)
            currentAnimatedImage = animatedImage
        }
    }

    private func pixelSize(for image: NSImage) -> CGSize? {
        if let representation = image.representations.first(where: { $0.pixelsWide > 0 && $0.pixelsHigh > 0 }) {
            return CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
        }

        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }

        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        return size
    }

    private func fileSize(for url: URL) -> Int64? {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = attributes[.size] as? NSNumber
        else {
            return nil
        }

        return size.int64Value
    }

    private func renamedImageURL(forBaseName baseName: String, from currentURL: URL) throws -> URL {
        let trimmedBaseName = baseName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedBaseName.isEmpty else {
            throw RenameImageError.emptyName
        }

        guard trimmedBaseName != ".", trimmedBaseName != ".." else {
            throw RenameImageError.invalidCharacters
        }

        let invalidCharacters = CharacterSet(charactersIn: "/:")
        guard trimmedBaseName.rangeOfCharacter(from: invalidCharacters) == nil else {
            throw RenameImageError.invalidCharacters
        }

        let pathExtension = currentURL.pathExtension
        let currentBaseName = currentURL.deletingPathExtension().lastPathComponent
        guard trimmedBaseName != currentBaseName else {
            return currentURL
        }

        let destinationURL = destinationURL(forBaseName: trimmedBaseName, pathExtension: pathExtension, currentURL: currentURL)

        if FileManager.default.fileExists(atPath: destinationURL.path), !isCaseOnlyRename(from: currentURL, to: destinationURL) {
            throw RenameImageError.duplicateName(destinationURL.lastPathComponent)
        }

        return destinationURL
    }

    private func destinationURL(forBaseName baseName: String, pathExtension: String, currentURL: URL) -> URL {
        let fileName: String
        if pathExtension.isEmpty {
            fileName = baseName
        } else {
            fileName = "\(baseName).\(pathExtension)"
        }

        return currentURL.deletingLastPathComponent().appendingPathComponent(fileName)
    }

    private func isCaseOnlyRename(from sourceURL: URL, to destinationURL: URL) -> Bool {
        sourceURL.deletingLastPathComponent() == destinationURL.deletingLastPathComponent()
            && sourceURL.lastPathComponent.caseInsensitiveCompare(destinationURL.lastPathComponent) == .orderedSame
            && sourceURL.lastPathComponent != destinationURL.lastPathComponent
    }

    private func uniqueTemporaryRenameURL(for sourceURL: URL) -> URL {
        let directoryURL = sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let pathExtension = sourceURL.pathExtension

        while true {
            let candidateBaseName = "\(baseName).rename-\(UUID().uuidString)"
            let candidateURL = destinationURL(forBaseName: candidateBaseName, pathExtension: pathExtension, currentURL: sourceURL)

            if !FileManager.default.fileExists(atPath: candidateURL.path) {
                return directoryURL.appendingPathComponent(candidateURL.lastPathComponent)
            }
        }
    }
}

private enum RenameImageError: LocalizedError {
    case noImage
    case emptyName
    case invalidCharacters
    case duplicateName(String)
    case moveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noImage:
            return "No image loaded."
        case .emptyName:
            return "Name can't be empty."
        case .invalidCharacters:
            return "Name can't contain \"/\" or \":\"."
        case let .duplicateName(name):
            return "A file named \"\(name)\" already exists."
        case let .moveFailed(error):
            return "Couldn't rename the file: \(error.localizedDescription)"
        }
    }
}
