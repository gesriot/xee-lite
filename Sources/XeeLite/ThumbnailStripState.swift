import AppKit
import Foundation
import ImageIO

@MainActor
final class ThumbnailStripState: ObservableObject {
    @Published private var loadedThumbnails: [String: NSImage] = [:]

    private let cache = NSCache<NSString, NSImage>()
    private var tasks: [String: Task<Void, Never>] = [:]

    func thumbnail(for url: URL) -> NSImage? {
        let key = thumbnailKey(for: url)

        if let image = loadedThumbnails[key] {
            return image
        }

        if let cachedImage = cache.object(forKey: key as NSString) {
            loadedThumbnails[key] = cachedImage
            return cachedImage
        }

        return nil
    }

    func requestThumbnail(for url: URL, maxPixelSize: Int = 160) {
        let key = thumbnailKey(for: url)

        if loadedThumbnails[key] != nil || cache.object(forKey: key as NSString) != nil || tasks[key] != nil {
            return
        }

        tasks[key] = Task(priority: .utility) { [weak self] in
            guard let self else { return }

            let cgImage = await Task.detached(priority: .utility) {
                Self.generateThumbnailCGImage(for: url, maxPixelSize: maxPixelSize)
            }.value

            guard !Task.isCancelled else { return }

            await MainActor.run {
                defer {
                    self.tasks[key] = nil
                }

                guard let cgImage else { return }

                let image = NSImage(
                    cgImage: cgImage,
                    size: NSSize(width: cgImage.width, height: cgImage.height)
                )

                self.cache.setObject(image, forKey: key as NSString)
                self.loadedThumbnails[key] = image
            }
        }
    }

    func updateScope(urls: [URL]) {
        let validKeys = Set(urls.map(thumbnailKey(for:)))

        for (key, task) in tasks where !validKeys.contains(key) {
            task.cancel()
            tasks.removeValue(forKey: key)
        }

        loadedThumbnails = loadedThumbnails.filter { validKeys.contains($0.key) }
    }

    deinit {
        for task in tasks.values {
            task.cancel()
        }
    }

    private func thumbnailKey(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    nonisolated private static func generateThumbnailCGImage(for url: URL, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCache: false
        ]

        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
