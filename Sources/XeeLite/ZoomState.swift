import Foundation
import SwiftUI

@MainActor
final class ZoomState: ObservableObject {
    enum Mode {
        case fitInWindow
        case fitOnScreen
        case actualSize
        case custom
    }

    @Published private(set) var mode: Mode = .fitInWindow
    @Published private(set) var scale: CGFloat = 1
    @Published private(set) var offset: CGSize = .zero
    @Published private(set) var fitOnScreenRequestID: Int = 0

    private let minimumScale: CGFloat = 0.05
    private let maximumScale: CGFloat = 32
    private let discreteZoomStep: CGFloat = 1.25

    private var viewportSize: CGSize = .zero
    private var screenSize: CGSize = .zero
    private var imagePixelSize: CGSize = .zero
    private var backingScaleFactor: CGFloat = 1
    private var dragOrigin: CGSize = .zero

    var hasImage: Bool {
        imagePixelSize.width > 0 && imagePixelSize.height > 0
    }

    var displayedImageSize: CGSize {
        displaySize(for: scale)
    }

    var isAtActualSize: Bool {
        mode == .actualSize
    }

    var statusText: String {
        guard hasImage else { return "Scale --" }

        let percent = Int((scale * 100).rounded())

        switch mode {
        case .fitInWindow:
            return "Scale \(percent)% · Fit"
        case .fitOnScreen:
            return "Scale \(percent)% · Screen"
        case .actualSize:
            return "Scale \(percent)% · Actual"
        case .custom:
            return "Scale \(percent)%"
        }
    }

    var canZoomIn: Bool {
        hasImage && scale < maximumScale - 0.001
    }

    var canZoomOut: Bool {
        hasImage && scale > minimumScale + 0.001
    }

    func updateImagePixelSize(_ size: CGSize?) {
        let nextSize = normalized(size)
        imagePixelSize = nextSize
        dragOrigin = .zero

        if hasImage {
            refreshForCurrentMode(center: true)
        } else {
            reset()
        }
    }

    func updateViewportSize(_ size: CGSize) {
        let nextSize = normalized(size)
        guard viewportSize != nextSize else { return }

        viewportSize = nextSize
        refreshForCurrentMode(center: mode != .custom)
    }

    func updateScreen(visibleFrameSize: CGSize, backingScaleFactor: CGFloat) {
        let nextScreenSize = normalized(visibleFrameSize)
        let nextBackingScale = max(backingScaleFactor, 1)

        guard screenSize != nextScreenSize || self.backingScaleFactor != nextBackingScale else { return }

        screenSize = nextScreenSize
        self.backingScaleFactor = nextBackingScale
        refreshForCurrentMode(center: mode != .custom)
    }

    func fitInWindow() {
        mode = .fitInWindow
        refreshForCurrentMode(center: true)
    }

    func fitOnScreen() {
        mode = .fitOnScreen
        fitOnScreenRequestID &+= 1
        refreshForCurrentMode(center: true)
    }

    func actualSize(anchor: CGPoint? = nil) {
        guard hasImage else { return }

        mode = .actualSize

        if let anchor {
            applyScale(1, anchor: anchor)
        } else {
            scale = 1
            offset = clampedOffset(for: .zero, scale: scale)
            dragOrigin = offset
        }
    }

    func toggleFitAndActualSize(anchor: CGPoint? = nil) {
        if isAtActualSize {
            fitInWindow()
        } else {
            actualSize(anchor: anchor)
        }
    }

    func zoomIn(anchor: CGPoint? = nil) {
        zoom(to: scale * discreteZoomStep, anchor: anchor)
    }

    func zoomOut(anchor: CGPoint? = nil) {
        zoom(to: scale / discreteZoomStep, anchor: anchor)
    }

    func handleWheelZoom(deltaY: CGFloat, anchor: CGPoint) {
        guard hasImage else { return }

        let factor = exp(deltaY * 0.01)
        zoom(to: scale * factor, anchor: anchor)
    }

    func handleMagnify(delta: CGFloat, anchor: CGPoint) {
        guard hasImage else { return }

        zoom(to: scale * max(0.2, 1 + delta), anchor: anchor)
    }

    func beginPan() {
        dragOrigin = offset
    }

    func updatePan(translation: CGSize) {
        guard hasImage else { return }

        let proposed = CGSize(
            width: dragOrigin.width + translation.width,
            height: dragOrigin.height + translation.height
        )

        offset = clampedOffset(for: proposed, scale: scale)
    }

    func endPan() {
        dragOrigin = offset
    }

    private func zoom(to requestedScale: CGFloat, anchor: CGPoint?) {
        guard hasImage else { return }

        mode = .custom
        applyScale(requestedScale, anchor: anchor)
    }

    private func applyScale(_ requestedScale: CGFloat, anchor: CGPoint?) {
        let targetScale = clampedScale(requestedScale)
        guard hasImage else {
            scale = targetScale
            return
        }

        guard abs(targetScale - scale) > 0.0001 else {
            offset = clampedOffset(for: offset, scale: targetScale)
            return
        }

        let anchorPoint = resolvedAnchorPoint(from: anchor)
        let centeredAnchor = CGPoint(
            x: anchorPoint.x - viewportSize.width / 2,
            y: anchorPoint.y - viewportSize.height / 2
        )

        let newOffset = CGSize(
            width: centeredAnchor.x - ((centeredAnchor.x - offset.width) / scale) * targetScale,
            height: centeredAnchor.y - ((centeredAnchor.y - offset.height) / scale) * targetScale
        )

        scale = targetScale
        offset = clampedOffset(for: newOffset, scale: targetScale)
        dragOrigin = offset
    }

    private func refreshForCurrentMode(center: Bool) {
        guard hasImage else {
            reset()
            return
        }

        switch mode {
        case .fitInWindow:
            scale = fitScale(in: viewportSize)
            offset = .zero
        case .fitOnScreen:
            scale = fitScale(in: screenSize == .zero ? viewportSize : screenSize)
            offset = .zero
        case .actualSize:
            scale = 1
            offset = center ? .zero : clampedOffset(for: offset, scale: scale)
        case .custom:
            offset = center ? .zero : clampedOffset(for: offset, scale: scale)
        }

        dragOrigin = offset
    }

    private func fitScale(in targetSize: CGSize) -> CGFloat {
        guard hasImage, targetSize.width > 0, targetSize.height > 0 else { return 1 }

        let scaleX = targetSize.width * backingScaleFactor / imagePixelSize.width
        let scaleY = targetSize.height * backingScaleFactor / imagePixelSize.height
        return clampedScale(min(1, min(scaleX, scaleY)))
    }

    private func displaySize(for scale: CGFloat) -> CGSize {
        guard hasImage else { return .zero }

        return CGSize(
            width: imagePixelSize.width / backingScaleFactor * scale,
            height: imagePixelSize.height / backingScaleFactor * scale
        )
    }

    func fitOnScreenViewportSize() -> CGSize {
        guard hasImage else { return .zero }

        let availableSize = screenSize == .zero ? viewportSize : screenSize
        let fitScale = fitScale(in: availableSize)
        return displaySize(for: fitScale)
    }

    func containsDisplayedImage(point: CGPoint) -> Bool {
        guard hasImage else { return false }

        let imageSize = displayedImageSize
        let imageRect = CGRect(
            x: (viewportSize.width - imageSize.width) / 2 + offset.width,
            y: (viewportSize.height - imageSize.height) / 2 + offset.height,
            width: imageSize.width,
            height: imageSize.height
        )

        return imageRect.contains(point)
    }

    private func clampedOffset(for proposedOffset: CGSize, scale: CGFloat) -> CGSize {
        guard viewportSize.width > 0, viewportSize.height > 0 else { return proposedOffset }

        let imageSize = displaySize(for: scale)
        let maxX = max(0, (imageSize.width - viewportSize.width) / 2)
        let maxY = max(0, (imageSize.height - viewportSize.height) / 2)

        return CGSize(
            width: min(max(proposedOffset.width, -maxX), maxX),
            height: min(max(proposedOffset.height, -maxY), maxY)
        )
    }

    private func resolvedAnchorPoint(from anchor: CGPoint?) -> CGPoint {
        guard
            let anchor,
            anchor.x.isFinite,
            anchor.y.isFinite,
            viewportSize.width > 0,
            viewportSize.height > 0
        else {
            return CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
        }

        return CGPoint(
            x: min(max(anchor.x, 0), viewportSize.width),
            y: min(max(anchor.y, 0), viewportSize.height)
        )
    }

    private func clampedScale(_ requestedScale: CGFloat) -> CGFloat {
        min(max(requestedScale, minimumScale), maximumScale)
    }

    private func normalized(_ size: CGSize?) -> CGSize {
        guard let size else { return .zero }

        return CGSize(
            width: max(size.width, 0),
            height: max(size.height, 0)
        )
    }

    private func reset() {
        mode = .fitInWindow
        scale = 1
        offset = .zero
        dragOrigin = .zero
    }
}
