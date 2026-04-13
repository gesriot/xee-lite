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

    private let supportedExtensions = Set([
        "avif", "bmp", "gif", "heic", "jpeg", "jpg", "png", "tif", "tiff", "webp"
    ])

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
                .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
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

    private func updateDisplayedImage() {
        guard imageURLs.indices.contains(currentIndex) else {
            currentImage = nil
            currentImageURL = nil
            currentImagePixelSize = nil
            return
        }

        let url = imageURLs[currentIndex]

        guard let image = NSImage(contentsOf: url) else {
            currentImage = nil
            currentImageURL = url
            currentImagePixelSize = nil
            return
        }

        currentImage = image
        currentImageURL = url
        currentImagePixelSize = pixelSize(for: image)
    }

    private func setSingleImage(url: URL, error: Error? = nil) {
        imageURLs = [url]
        currentIndex = 0
        currentImageURL = url

        if let image = NSImage(contentsOf: url) {
            currentImage = image
            currentImagePixelSize = pixelSize(for: image)
        } else {
            currentImage = nil
            currentImagePixelSize = nil
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
}
