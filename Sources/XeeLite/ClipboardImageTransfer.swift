import AppKit
import Foundation
import UniformTypeIdentifiers

enum ImportedImageSource {
    case fileURL(URL)
    case bitmap(NSImage)
}

enum ClipboardImageTransferError: LocalizedError {
    case unsupportedContent
    case loadFailed
    case decodeFailed
    case copyFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedContent:
            return "The clipboard doesn't currently contain an image."
        case .loadFailed:
            return "Couldn't load the dropped or pasted image."
        case .decodeFailed:
            return "The dropped or pasted image data couldn't be decoded."
        case .copyFailed:
            return "Couldn't copy the current image to the clipboard."
        }
    }
}

enum ClipboardImageTransfer {
    static func copyImage(_ image: NSImage, to pasteboard: NSPasteboard = .general) -> Bool {
        pasteboard.clearContents()
        return pasteboard.writeObjects([image])
    }

    static func readFromPasteboard(_ pasteboard: NSPasteboard = .general) -> Result<ImportedImageSource, Error> {
        if let fileURL = firstSupportedFileURL(from: pasteboard) {
            return .success(.fileURL(fileURL))
        }

        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first {
            return .success(.bitmap(image))
        }

        return .failure(ClipboardImageTransferError.unsupportedContent)
    }

    static func readFromItemProviders(
        _ providers: [NSItemProvider],
        completion: @escaping @MainActor (Result<ImportedImageSource, Error>) -> Void
    ) -> Bool {
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let error {
                    Task { @MainActor in
                        completion(.failure(error))
                    }
                    return
                }

                guard let url = resolvedFileURL(from: item), isSupportedImageURL(url) else {
                    Task { @MainActor in
                        completion(.failure(ClipboardImageTransferError.unsupportedContent))
                    }
                    return
                }

                Task { @MainActor in
                    completion(.success(.fileURL(url.standardizedFileURL)))
                }
            }

            return true
        }

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let error {
                    Task { @MainActor in
                        completion(.failure(error))
                    }
                    return
                }

                guard let data else {
                    Task { @MainActor in
                        completion(.failure(ClipboardImageTransferError.loadFailed))
                    }
                    return
                }

                Task { @MainActor in
                    guard let image = NSImage(data: data) else {
                        completion(.failure(ClipboardImageTransferError.decodeFailed))
                        return
                    }

                    completion(.success(.bitmap(image)))
                }
            }

            return true
        }

        return false
    }

    private static func firstSupportedFileURL(from pasteboard: NSPasteboard) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]

        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
        return urls.first(where: isSupportedImageURL(_:))?.standardizedFileURL
    }

    private static func resolvedFileURL(from item: NSSecureCoding?) -> URL? {
        switch item {
        case let url as URL:
            return url
        case let nsURL as NSURL:
            return nsURL as URL
        case let data as Data:
            return URL(dataRepresentation: data, relativeTo: nil)
        case let string as String:
            return URL(string: string)
        default:
            return nil
        }
    }

    private static func isSupportedImageURL(_ url: URL) -> Bool {
        SupportedImageFormats.folderExtensions.contains(url.pathExtension.lowercased())
    }
}
