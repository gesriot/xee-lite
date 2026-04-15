import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum CropAspectRatioPreset: String, CaseIterable, Identifiable {
    case freeform
    case square
    case ratio4x3
    case ratio16x9

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .freeform:
            return "Freeform"
        case .square:
            return "1:1"
        case .ratio4x3:
            return "4:3"
        case .ratio16x9:
            return "16:9"
        }
    }

    var aspectRatio: CGFloat? {
        switch self {
        case .freeform:
            return nil
        case .square:
            return 1
        case .ratio4x3:
            return 4.0 / 3.0
        case .ratio16x9:
            return 16.0 / 9.0
        }
    }
}

enum CropSaveMode {
    case overwriteOriginal
    case saveAs
}

@MainActor
final class CropState: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var selectionRect: CGRect?
    @Published private(set) var aspectRatioPreset: CropAspectRatioPreset = .freeform
    @Published private(set) var activateRequestID: UInt64 = 0
    @Published private(set) var saveRequestID: UInt64 = 0
    @Published private(set) var saveAsRequestID: UInt64 = 0

    private var dragStartPixelPoint: CGPoint?

    var canSaveSelection: Bool {
        guard let selectionRect = normalizedSelectionRect else { return false }
        return selectionRect.width >= 1 && selectionRect.height >= 1
    }

    var normalizedSelectionRect: CGRect? {
        guard let selectionRect else { return nil }

        let normalized = selectionRect.standardized
        guard normalized.width >= 1, normalized.height >= 1 else { return nil }
        return normalized
    }

    var selectionText: String? {
        guard let selectionRect = normalizedSelectionRect else { return nil }

        return "\(Int(selectionRect.width.rounded(.down))) × \(Int(selectionRect.height.rounded(.down))) px"
    }

    func requestActivate() {
        activateRequestID &+= 1
    }

    func requestSave() {
        guard canSaveSelection else { return }
        saveRequestID &+= 1
    }

    func requestSaveAs() {
        guard canSaveSelection else { return }
        saveAsRequestID &+= 1
    }

    func activate(imagePixelSize: CGSize?) {
        guard let imagePixelSize, imagePixelSize.width > 0, imagePixelSize.height > 0 else { return }

        isActive = true
        dragStartPixelPoint = nil

        if let selectionRect = selectionRect {
            self.selectionRect = adjustedSelectionRect(from: selectionRect, in: imagePixelSize)
        } else {
            self.selectionRect = defaultSelectionRect(for: imagePixelSize)
        }
    }

    func deactivate() {
        isActive = false
        selectionRect = nil
        dragStartPixelPoint = nil
    }

    func beginSelectionIfNeeded(at viewportPoint: CGPoint, zoomState: ZoomState) {
        guard isActive, dragStartPixelPoint == nil else { return }
        guard let imagePoint = zoomState.imagePixelPoint(forViewportPoint: viewportPoint) else { return }

        dragStartPixelPoint = imagePoint
        selectionRect = CGRect(origin: imagePoint, size: .zero)
    }

    func updateSelection(to viewportPoint: CGPoint, zoomState: ZoomState) {
        guard
            isActive,
            let dragStartPixelPoint,
            let imagePixelSize = zoomState.currentImagePixelSize,
            let imagePoint = zoomState.clampedImagePixelPoint(forViewportPoint: viewportPoint)
        else {
            return
        }

        selectionRect = dragSelectionRect(
            from: dragStartPixelPoint,
            to: imagePoint,
            in: imagePixelSize
        )
    }

    func endSelection(imagePixelSize: CGSize?) {
        dragStartPixelPoint = nil

        guard let imagePixelSize else {
            selectionRect = nil
            return
        }

        selectionRect = validatedSelectionRect(selectionRect, in: imagePixelSize)
    }

    func setAspectRatioPreset(_ preset: CropAspectRatioPreset, imagePixelSize: CGSize?) {
        aspectRatioPreset = preset

        guard isActive, let imagePixelSize, imagePixelSize.width > 0, imagePixelSize.height > 0 else { return }

        if let selectionRect {
            self.selectionRect = adjustedSelectionRect(from: selectionRect, in: imagePixelSize)
        } else {
            self.selectionRect = defaultSelectionRect(for: imagePixelSize)
        }
    }

    private func dragSelectionRect(from start: CGPoint, to end: CGPoint, in imagePixelSize: CGSize) -> CGRect {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y

        var resolvedWidth = abs(deltaX)
        var resolvedHeight = abs(deltaY)

        if let aspectRatio = aspectRatioPreset.aspectRatio, resolvedWidth > 0, resolvedHeight > 0 {
            if resolvedWidth / resolvedHeight > aspectRatio {
                resolvedWidth = resolvedHeight * aspectRatio
            } else {
                resolvedHeight = resolvedWidth / aspectRatio
            }
        }

        let signX: CGFloat = deltaX >= 0 ? 1 : -1
        let signY: CGFloat = deltaY >= 0 ? 1 : -1
        let resolvedEnd = CGPoint(
            x: start.x + signX * resolvedWidth,
            y: start.y + signY * resolvedHeight
        )

        return validatedSelectionRect(
            CGRect(
                x: min(start.x, resolvedEnd.x),
                y: min(start.y, resolvedEnd.y),
                width: abs(resolvedEnd.x - start.x),
                height: abs(resolvedEnd.y - start.y)
            ),
            in: imagePixelSize
        ) ?? .zero
    }

    private func validatedSelectionRect(_ rect: CGRect?, in imagePixelSize: CGSize) -> CGRect? {
        guard let rect else { return nil }

        let imageBounds = CGRect(origin: .zero, size: imagePixelSize)
        let clamped = rect.standardized.intersection(imageBounds)

        guard clamped.width >= 1, clamped.height >= 1 else { return nil }
        return clamped
    }

    private func adjustedSelectionRect(from rect: CGRect, in imagePixelSize: CGSize) -> CGRect {
        let imageBounds = CGRect(origin: .zero, size: imagePixelSize)
        let standardizedRect = rect.standardized.intersection(imageBounds)

        guard standardizedRect.width >= 1, standardizedRect.height >= 1 else {
            return defaultSelectionRect(for: imagePixelSize)
        }

        guard let aspectRatio = aspectRatioPreset.aspectRatio else {
            return standardizedRect
        }

        var width = standardizedRect.width
        var height = standardizedRect.height

        if width / height > aspectRatio {
            width = height * aspectRatio
        } else {
            height = width / aspectRatio
        }

        let center = CGPoint(x: standardizedRect.midX, y: standardizedRect.midY)
        var adjusted = CGRect(
            x: center.x - width / 2,
            y: center.y - height / 2,
            width: width,
            height: height
        )

        if adjusted.minX < imageBounds.minX {
            adjusted.origin.x = imageBounds.minX
        }

        if adjusted.minY < imageBounds.minY {
            adjusted.origin.y = imageBounds.minY
        }

        if adjusted.maxX > imageBounds.maxX {
            adjusted.origin.x = imageBounds.maxX - adjusted.width
        }

        if adjusted.maxY > imageBounds.maxY {
            adjusted.origin.y = imageBounds.maxY - adjusted.height
        }

        return adjusted.intersection(imageBounds)
    }

    private func defaultSelectionRect(for imagePixelSize: CGSize) -> CGRect {
        let inset: CGFloat = 0.12
        let availableSize = CGSize(
            width: imagePixelSize.width * (1 - inset * 2),
            height: imagePixelSize.height * (1 - inset * 2)
        )

        if let aspectRatio = aspectRatioPreset.aspectRatio {
            var width = availableSize.width
            var height = width / aspectRatio

            if height > availableSize.height {
                height = availableSize.height
                width = height * aspectRatio
            }

            return CGRect(
                x: (imagePixelSize.width - width) / 2,
                y: (imagePixelSize.height - height) / 2,
                width: width,
                height: height
            )
        }

        return CGRect(
            x: imagePixelSize.width * inset,
            y: imagePixelSize.height * inset,
            width: availableSize.width,
            height: availableSize.height
        )
    }
}

enum CropExporter {
    private static let writableTypeIdentifiers: Set<String> = {
        let identifiers = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return Set(identifiers)
    }()

    static func canOverwrite(url: URL, isAnimatedSource: Bool) -> Bool {
        guard !isAnimatedSource else { return false }
        return preferredWritableType(for: url) != nil
    }

    @MainActor
    static func saveCroppedImage(
        from image: NSImage,
        sourcePixelSize: CGSize,
        cropRect: CGRect,
        originalURL: URL?,
        isAnimatedSource: Bool,
        mode: CropSaveMode
    ) throws -> URL {
        let pixelWidth = max(Int(sourcePixelSize.width.rounded()), 1)
        let pixelHeight = max(Int(sourcePixelSize.height.rounded()), 1)

        let renderedImage = try renderedCGImage(
            from: image,
            sourceURL: originalURL,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight
        )

        let imageBounds = CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
        let normalizedCropRect = cropRect.standardized.integral.intersection(imageBounds)

        guard normalizedCropRect.width >= 1, normalizedCropRect.height >= 1 else {
            throw CropExportError.emptySelection
        }

        guard let croppedImage = renderedImage.cropping(to: normalizedCropRect) else {
            throw CropExportError.cropFailed
        }

        let destination = try resolvedDestination(
            mode: mode,
            originalURL: originalURL,
            isAnimatedSource: isAnimatedSource
        )

        switch mode {
        case .overwriteOriginal:
            try replaceImage(at: destination.url, with: croppedImage, type: destination.type)
        case .saveAs:
            try writeImage(croppedImage, to: destination.url, type: destination.type, replaceExisting: true)
        }

        return destination.url
    }

    @MainActor
    private static func resolvedDestination(
        mode: CropSaveMode,
        originalURL: URL?,
        isAnimatedSource: Bool
    ) throws -> (url: URL, type: UTType) {
        switch mode {
        case .overwriteOriginal:
            guard let originalURL else {
                throw CropExportError.missingOriginalFile
            }

            guard let type = preferredWritableType(for: originalURL), !isAnimatedSource else {
                throw CropExportError.overwriteUnavailable
            }

            return (originalURL.standardizedFileURL, type)
        case .saveAs:
            let fallbackType = preferredSaveAsType(for: originalURL, isAnimatedSource: isAnimatedSource)
            let saveURL = try requestedSaveAsURL(originalURL: originalURL, defaultType: fallbackType)
            let resolvedType = preferredWritableType(for: saveURL) ?? fallbackType
            return (saveURL.standardizedFileURL, resolvedType)
        }
    }

    private static func preferredWritableType(for url: URL) -> UTType? {
        guard !url.pathExtension.isEmpty else { return nil }
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return nil }
        guard writableTypeIdentifiers.contains(type.identifier) else { return nil }
        return type
    }

    private static func preferredSaveAsType(for originalURL: URL?, isAnimatedSource: Bool) -> UTType {
        if isAnimatedSource {
            return .png
        }

        if let originalURL, let originalType = preferredWritableType(for: originalURL) {
            return originalType
        }

        return .png
    }

    @MainActor
    private static func requestedSaveAsURL(originalURL: URL?, defaultType: UTType) throws -> URL {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [defaultType]

        if let originalURL {
            let baseName = originalURL.deletingPathExtension().lastPathComponent
            let fileExtension = defaultType.preferredFilenameExtension ?? originalURL.pathExtension
            panel.nameFieldStringValue = "\(baseName)-cropped.\(fileExtension)"
            panel.directoryURL = originalURL.deletingLastPathComponent()
        } else if let fileExtension = defaultType.preferredFilenameExtension {
            panel.nameFieldStringValue = "cropped.\(fileExtension)"
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            throw CropExportError.cancelled
        }

        return url
    }

    private static func replaceImage(at url: URL, with image: CGImage, type: UTType) throws {
        let directoryURL = url.deletingLastPathComponent()
        let fileExtension = type.preferredFilenameExtension ?? url.pathExtension
        let temporaryURL = directoryURL.appendingPathComponent(
            ".\(UUID().uuidString).crop.\(fileExtension)"
        )

        do {
            try writeImage(image, to: temporaryURL, type: type, replaceExisting: true)
            _ = try FileManager.default.replaceItemAt(url, withItemAt: temporaryURL)
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
    }

    private static func writeImage(
        _ image: CGImage,
        to url: URL,
        type: UTType,
        replaceExisting: Bool
    ) throws {
        if replaceExisting, FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw CropExportError.destinationCreationFailed(type.identifier)
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw CropExportError.destinationFinalizeFailed
        }
    }

    private static func renderedCGImage(
        from image: NSImage,
        sourceURL: URL?,
        pixelWidth: Int,
        pixelHeight: Int
    ) throws -> CGImage {
        // Prefer decoding directly from the original file so we keep the source
        // pixel data and embedded color space whenever ImageIO can provide it.
        if
            let sourceURL,
            let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil),
            cgImage.width == pixelWidth,
            cgImage.height == pixelHeight
        {
            return cgImage
        }

        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelWidth,
                pixelsHigh: pixelHeight,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ),
            let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)
        else {
            throw CropExportError.renderFailed
        }

        NSGraphicsContext.saveGraphicsState()
        defer {
            NSGraphicsContext.restoreGraphicsState()
        }

        NSGraphicsContext.current = graphicsContext
        graphicsContext.imageInterpolation = .high

        image.draw(
            in: NSRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1
        )

        guard let cgImage = bitmap.cgImage else {
            throw CropExportError.renderFailed
        }

        return cgImage
    }
}

private enum CropExportError: LocalizedError {
    case missingOriginalFile
    case overwriteUnavailable
    case emptySelection
    case cropFailed
    case renderFailed
    case cancelled
    case destinationCreationFailed(String)
    case destinationFinalizeFailed

    var errorDescription: String? {
        switch self {
        case .missingOriginalFile:
            return "The current image doesn't have a file URL to save back into."
        case .overwriteUnavailable:
            return "This image can't be overwritten directly after cropping. Use Save As instead."
        case .emptySelection:
            return "Select an area to crop first."
        case .cropFailed:
            return "Couldn't crop the selected area."
        case .renderFailed:
            return "Couldn't render the current image for cropping."
        case .cancelled:
            return nil
        case let .destinationCreationFailed(typeIdentifier):
            return "Couldn't create an image destination for \(typeIdentifier)."
        case .destinationFinalizeFailed:
            return "Couldn't write the cropped image to disk."
        }
    }
}
