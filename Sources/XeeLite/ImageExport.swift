import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageExportFormat: String, CaseIterable, Identifiable {
    case jpeg
    case png
    case tiff
    case heic
    case webP

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .jpeg:
            return "JPEG"
        case .png:
            return "PNG"
        case .tiff:
            return "TIFF"
        case .heic:
            return "HEIC"
        case .webP:
            return "WebP"
        }
    }

    var filenameExtension: String {
        switch self {
        case .jpeg:
            return "jpg"
        case .png:
            return "png"
        case .tiff:
            return "tiff"
        case .heic:
            return "heic"
        case .webP:
            return "webp"
        }
    }

    var utType: UTType? {
        UTType(filenameExtension: filenameExtension)
    }

    var supportsCompressionQuality: Bool {
        switch self {
        case .jpeg, .heic, .webP:
            return true
        case .png, .tiff:
            return false
        }
    }

    var requiresOpaqueBackground: Bool {
        switch self {
        case .jpeg, .heic:
            return true
        case .png, .tiff, .webP:
            return false
        }
    }

    static var availableCases: [ImageExportFormat] {
        allCases.filter { format in
            guard let utType = format.utType else { return false }
            return writableTypeIdentifiers.contains(utType.identifier)
        }
    }

    static func defaultFormat(for originalURL: URL?, isAnimatedSource: Bool) -> ImageExportFormat {
        let availableFormats = availableCases

        if isAnimatedSource, availableFormats.contains(.png) {
            return .png
        }

        if
            let pathExtension = originalURL?.pathExtension.lowercased(),
            let matchingFormat = availableFormats.first(where: { $0.filenameExtension == pathExtension })
        {
            return matchingFormat
        }

        for preferredFormat in [ImageExportFormat.png, .jpeg, .tiff, .heic, .webP] {
            if availableFormats.contains(preferredFormat) {
                return preferredFormat
            }
        }

        return .png
    }

    private static let writableTypeIdentifiers: Set<String> = {
        let identifiers = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return Set(identifiers)
    }()
}

struct ImageExportOptions {
    let format: ImageExportFormat
    let pixelSize: CGSize
    let compressionQuality: Double
}

enum ImageExporter {
    @MainActor
    static func exportImage(
        from sourceImage: NSImage,
        sourcePixelSize: CGSize,
        originalURL: URL?,
        options: ImageExportOptions
    ) throws -> URL {
        guard let destinationType = options.format.utType else {
            throw ImageExportError.unsupportedFormat
        }

        let exportURL = try requestedExportURL(
            originalURL: originalURL,
            format: options.format
        )

        let sourceWidth = max(Int(sourcePixelSize.width.rounded()), 1)
        let sourceHeight = max(Int(sourcePixelSize.height.rounded()), 1)
        let targetWidth = max(Int(options.pixelSize.width.rounded()), 1)
        let targetHeight = max(Int(options.pixelSize.height.rounded()), 1)

        let renderedSourceImage = try renderedCGImage(
            from: sourceImage,
            sourceURL: originalURL,
            pixelWidth: sourceWidth,
            pixelHeight: sourceHeight
        )

        let preparedImage = try preparedCGImage(
            from: renderedSourceImage,
            targetWidth: targetWidth,
            targetHeight: targetHeight,
            format: options.format
        )

        try writeImage(
            preparedImage,
            to: exportURL,
            type: destinationType,
            compressionQuality: options.compressionQuality,
            supportsCompressionQuality: options.format.supportsCompressionQuality
        )

        return exportURL
    }

    @MainActor
    private static func requestedExportURL(
        originalURL: URL?,
        format: ImageExportFormat
    ) throws -> URL {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true

        if let utType = format.utType {
            panel.allowedContentTypes = [utType]
        }

        let baseName = originalURL?.deletingPathExtension().lastPathComponent ?? "image"
        panel.nameFieldStringValue = "\(baseName)-exported.\(format.filenameExtension)"

        if let originalURL {
            panel.directoryURL = originalURL.deletingLastPathComponent()
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            throw ImageExportError.cancelled
        }

        return url.standardizedFileURL
    }

    private static func writeImage(
        _ image: CGImage,
        to url: URL,
        type: UTType,
        compressionQuality: Double,
        supportsCompressionQuality: Bool
    ) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            type.identifier as CFString,
            1,
            nil
        ) else {
            throw ImageExportError.destinationCreationFailed(type.identifier)
        }

        let properties: CFDictionary?
        if supportsCompressionQuality {
            properties = [
                kCGImageDestinationLossyCompressionQuality: compressionQuality
            ] as CFDictionary
        } else {
            properties = nil
        }

        CGImageDestinationAddImage(destination, image, properties)

        guard CGImageDestinationFinalize(destination) else {
            throw ImageExportError.destinationFinalizeFailed
        }
    }

    private static func preparedCGImage(
        from sourceImage: CGImage,
        targetWidth: Int,
        targetHeight: Int,
        format: ImageExportFormat
    ) throws -> CGImage {
        if
            sourceImage.width == targetWidth,
            sourceImage.height == targetHeight,
            !format.requiresOpaqueBackground
        {
            return sourceImage
        }

        let colorSpace = sourceImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let alphaInfo: CGImageAlphaInfo = format.requiresOpaqueBackground ? .noneSkipLast : .premultipliedLast
        let bitmapInfo = CGBitmapInfo(rawValue: alphaInfo.rawValue).union(.byteOrder32Big)

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw ImageExportError.renderFailed
        }

        context.interpolationQuality = .high

        if format.requiresOpaqueBackground {
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        } else {
            context.clear(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        }

        context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        guard let scaledImage = context.makeImage() else {
            throw ImageExportError.renderFailed
        }

        return scaledImage
    }

    private static func renderedCGImage(
        from image: NSImage,
        sourceURL: URL?,
        pixelWidth: Int,
        pixelHeight: Int
    ) throws -> CGImage {
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
            throw ImageExportError.renderFailed
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
            throw ImageExportError.renderFailed
        }

        return cgImage
    }
}

enum ImageExportError: LocalizedError {
    case noImage
    case invalidDimensions
    case unsupportedFormat
    case renderFailed
    case cancelled
    case destinationCreationFailed(String)
    case destinationFinalizeFailed

    var errorDescription: String? {
        switch self {
        case .noImage:
            return "No image loaded."
        case .invalidDimensions:
            return "Export width and height must both be greater than zero."
        case .unsupportedFormat:
            return "The selected export format isn't available on this system."
        case .renderFailed:
            return "Couldn't render the image for export."
        case .cancelled:
            return "Export cancelled."
        case let .destinationCreationFailed(identifier):
            return "Couldn't create an export destination for \(identifier)."
        case .destinationFinalizeFailed:
            return "Couldn't finish writing the exported image."
        }
    }
}
