import AppKit
import CoreImage
import Foundation

@MainActor
final class ColorAdjustmentState: ObservableObject {
    @Published var brightness: Double = 0
    @Published var contrast: Double = 1
    @Published var gamma: Double = 1
    @Published private(set) var isActive = false
    @Published private(set) var previewImage: NSImage?
    @Published private(set) var activateRequestID: UInt64 = 0

    private static let ciContext = CIContext(options: [
        .cacheIntermediates: false
    ])

    var hasAdjustments: Bool {
        abs(brightness) > 0.001 || abs(contrast - 1) > 0.001 || abs(gamma - 1) > 0.001
    }

    var canReset: Bool {
        hasAdjustments
    }

    func requestActivate() {
        activateRequestID &+= 1
    }

    func activate() {
        isActive = true
    }

    func deactivate() {
        isActive = false
        reset()
        previewImage = nil
    }

    func reset() {
        brightness = 0
        contrast = 1
        gamma = 1
        previewImage = nil
    }

    func refreshPreview(from sourceImage: NSImage?) {
        guard isActive, let sourceImage else {
            previewImage = nil
            return
        }

        guard hasAdjustments else {
            previewImage = nil
            return
        }

        previewImage = Self.adjustedImage(
            from: sourceImage,
            brightness: brightness,
            contrast: contrast,
            gamma: gamma
        )
    }

    private static func adjustedImage(
        from sourceImage: NSImage,
        brightness: Double,
        contrast: Double,
        gamma: Double
    ) -> NSImage? {
        guard let ciImage = ciImage(from: sourceImage) else { return nil }

        guard
            let colorControls = CIFilter(name: "CIColorControls"),
            let gammaAdjust = CIFilter(name: "CIGammaAdjust")
        else {
            return nil
        }

        colorControls.setValue(ciImage, forKey: kCIInputImageKey)
        colorControls.setValue(brightness, forKey: kCIInputBrightnessKey)
        colorControls.setValue(contrast, forKey: kCIInputContrastKey)

        gammaAdjust.setValue(colorControls.outputImage, forKey: kCIInputImageKey)
        gammaAdjust.setValue(gamma, forKey: "inputPower")

        guard
            let outputImage = gammaAdjust.outputImage,
            let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent)
        else {
            return nil
        }

        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
    }

    private static func ciImage(from image: NSImage) -> CIImage? {
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return CIImage(cgImage: cgImage)
        }

        if let tiffData = image.tiffRepresentation {
            return CIImage(data: tiffData)
        }

        return nil
    }
}
