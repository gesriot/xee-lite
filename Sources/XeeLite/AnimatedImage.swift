import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct AnimatedImage {
    let frames: [AnimatedImageFrame]
    let pixelSize: CGSize
    let loopCount: Int?

    var posterImage: NSImage? {
        frames.first?.image
    }

    var frameCount: Int {
        frames.count
    }

    var isAnimated: Bool {
        frameCount > 1
    }
}

struct AnimatedImageFrame {
    let image: NSImage
    let duration: TimeInterval
}

enum AnimatedImageLoader {
    private static let defaultFrameDuration: TimeInterval = 0.1
    private static let minimumFrameDuration: TimeInterval = 0.02

    static func load(from url: URL) -> AnimatedImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 1 else { return nil }

        guard let format = animationFormat(for: source) else { return nil }

        let rootProperties = CGImageSourceCopyProperties(source, nil) as? [CFString: Any] ?? [:]
        let rootDictionary = animationDictionary(for: format, in: rootProperties)
        let loopCount = loopCount(from: rootDictionary, format: format)

        var frames: [AnimatedImageFrame] = []
        var fallbackPixelSize = CGSize.zero

        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }

            if fallbackPixelSize == .zero {
                fallbackPixelSize = CGSize(width: cgImage.width, height: cgImage.height)
            }

            let frameProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] ?? [:]
            let frameDictionary = animationDictionary(for: format, in: frameProperties)
            let duration = frameDuration(from: frameDictionary, format: format)

            frames.append(
                AnimatedImageFrame(
                    image: NSImage(
                        cgImage: cgImage,
                        size: NSSize(width: cgImage.width, height: cgImage.height)
                    ),
                    duration: duration
                )
            )
        }

        guard frames.count > 1 else { return nil }

        return AnimatedImage(
            frames: frames,
            pixelSize: pixelSize(from: rootDictionary, format: format) ?? fallbackPixelSize,
            loopCount: loopCount
        )
    }

    private static func animationFormat(for source: CGImageSource) -> AnimatedFormat? {
        guard let sourceType = CGImageSourceGetType(source) as String? else { return nil }

        switch sourceType {
        case UTType.gif.identifier:
            return .gif
        case UTType.png.identifier:
            return .apng
        default:
            return nil
        }
    }

    private static func animationDictionary(
        for format: AnimatedFormat,
        in properties: [CFString: Any]
    ) -> [CFString: Any] {
        switch format {
        case .gif:
            return properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] ?? [:]
        case .apng:
            return properties[kCGImagePropertyPNGDictionary] as? [CFString: Any] ?? [:]
        }
    }

    private static func loopCount(from dictionary: [CFString: Any], format: AnimatedFormat) -> Int? {
        let key: CFString = switch format {
        case .gif:
            kCGImagePropertyGIFLoopCount
        case .apng:
            kCGImagePropertyAPNGLoopCount
        }

        guard let number = dictionary[key] as? NSNumber else { return nil }
        let value = number.intValue
        return value == 0 ? nil : value
    }

    private static func pixelSize(from dictionary: [CFString: Any], format: AnimatedFormat) -> CGSize? {
        let widthKey: CFString = switch format {
        case .gif:
            kCGImagePropertyGIFCanvasPixelWidth
        case .apng:
            kCGImagePropertyAPNGCanvasPixelWidth
        }

        let heightKey: CFString = switch format {
        case .gif:
            kCGImagePropertyGIFCanvasPixelHeight
        case .apng:
            kCGImagePropertyAPNGCanvasPixelHeight
        }

        guard
            let width = (dictionary[widthKey] as? NSNumber)?.doubleValue,
            let height = (dictionary[heightKey] as? NSNumber)?.doubleValue,
            width > 0,
            height > 0
        else {
            return nil
        }

        return CGSize(width: width, height: height)
    }

    private static func frameDuration(from dictionary: [CFString: Any], format: AnimatedFormat) -> TimeInterval {
        let unclampedKey: CFString = switch format {
        case .gif:
            kCGImagePropertyGIFUnclampedDelayTime
        case .apng:
            kCGImagePropertyAPNGUnclampedDelayTime
        }

        let clampedKey: CFString = switch format {
        case .gif:
            kCGImagePropertyGIFDelayTime
        case .apng:
            kCGImagePropertyAPNGDelayTime
        }

        let delay = (dictionary[unclampedKey] as? NSNumber)?.doubleValue
            ?? (dictionary[clampedKey] as? NSNumber)?.doubleValue
            ?? defaultFrameDuration

        guard delay > 0 else { return defaultFrameDuration }
        return max(delay, minimumFrameDuration)
    }
}

private enum AnimatedFormat {
    case gif
    case apng
}

@MainActor
final class AnimatedImagePlaybackState: ObservableObject {
    @Published private(set) var currentFrameIndex = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var playbackRate = 1.0

    let availablePlaybackRates: [Double] = [0.5, 1.0, 1.5, 2.0]

    private var animatedImage: AnimatedImage?
    private var playbackTask: Task<Void, Never>?
    private var completedLoops = 0

    deinit {
        playbackTask?.cancel()
    }

    var currentFrameImage: NSImage? {
        guard
            let animatedImage,
            animatedImage.frames.indices.contains(currentFrameIndex)
        else {
            return nil
        }

        return animatedImage.frames[currentFrameIndex].image
    }

    var isAnimated: Bool {
        animatedImage?.isAnimated ?? false
    }

    var frameStatusText: String? {
        guard let animatedImage, animatedImage.isAnimated else { return nil }
        return "\(currentFrameIndex + 1)/\(animatedImage.frameCount)"
    }

    var playbackRateText: String {
        let rounded = playbackRate.rounded()
        if abs(playbackRate - rounded) < 0.001 {
            return "\(Int(rounded))x"
        }

        return "\(playbackRate.formatted(.number.precision(.fractionLength(1))))x"
    }

    func setAnimatedImage(_ animatedImage: AnimatedImage?) {
        playbackTask?.cancel()
        playbackTask = nil

        self.animatedImage = animatedImage
        currentFrameIndex = 0
        completedLoops = 0
        isPlaying = animatedImage?.isAnimated == true

        startPlaybackLoopIfNeeded()
    }

    func togglePlayback() {
        guard isAnimated else { return }

        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard isAnimated else { return }
        isPlaying = true
        startPlaybackLoopIfNeeded()
    }

    func pause() {
        isPlaying = false
        playbackTask?.cancel()
        playbackTask = nil
    }

    func stepForward() {
        guard let animatedImage, animatedImage.isAnimated else { return }
        pause()
        currentFrameIndex = (currentFrameIndex + 1) % animatedImage.frameCount
    }

    func stepBackward() {
        guard let animatedImage, animatedImage.isAnimated else { return }
        pause()
        currentFrameIndex = currentFrameIndex == 0 ? animatedImage.frameCount - 1 : currentFrameIndex - 1
    }

    func setPlaybackRate(_ newRate: Double) {
        guard availablePlaybackRates.contains(newRate) else { return }
        playbackRate = newRate

        if isPlaying {
            startPlaybackLoopIfNeeded()
        }
    }

    private func startPlaybackLoopIfNeeded() {
        playbackTask?.cancel()
        playbackTask = nil

        guard let animatedImage, animatedImage.isAnimated, isPlaying else { return }

        playbackTask = Task { [weak self] in
            await self?.runPlaybackLoop(for: animatedImage)
        }
    }

    private func runPlaybackLoop(for animatedImage: AnimatedImage) async {
        while !Task.isCancelled, isPlaying {
            let duration = animatedImage.frames[currentFrameIndex].duration / max(playbackRate, 0.01)
            let delay = UInt64(max(duration, 0.02) * 1_000_000_000)

            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }

            guard !Task.isCancelled, isPlaying else { return }
            advancePlaybackFrame()
        }
    }

    private func advancePlaybackFrame() {
        guard let animatedImage, animatedImage.isAnimated else { return }

        if currentFrameIndex + 1 < animatedImage.frameCount {
            currentFrameIndex += 1
            return
        }

        if let loopCount = animatedImage.loopCount, completedLoops + 1 >= loopCount {
            currentFrameIndex = animatedImage.frameCount - 1
            pause()
            return
        }

        completedLoops += 1
        currentFrameIndex = 0
    }
}
