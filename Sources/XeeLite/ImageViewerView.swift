import AppKit
import SwiftUI

struct ImageViewerView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var zoomState: ZoomState
    @State private var window: NSWindow?
    @State private var isFullScreen = false
    @State private var isChromeVisible = true
    @State private var autoHideWorkItem: DispatchWorkItem?
    private let statusBarHeight: CGFloat = 26
    private let fullScreenChromeInset: CGFloat = 10
    private let fullScreenAutoHideDelay: TimeInterval = 1.8

    var body: some View {
        Group {
            if isFullScreen {
                ZStack(alignment: .bottom) {
                    viewerContent

                    if isChromeVisible {
                        statusBar
                            .padding(.horizontal, fullScreenChromeInset)
                            .padding(.bottom, fullScreenChromeInset)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            } else {
                VStack(spacing: 0) {
                    viewerContent
                    statusBar
                }
            }
        }
        .background(Color.black.opacity(0.92))
        .animation(.easeOut(duration: 0.16), value: isChromeVisible)
        .onAppear {
            appState.loadInitialImage()
            zoomState.updateImagePixelSize(appState.currentImagePixelSize)
        }
        .onChange(of: appState.currentImageURL) { _, newURL in
            updateWindowTitle(with: newURL)
        }
        .onChange(of: appState.currentImagePixelSize) { _, newSize in
            zoomState.updateImagePixelSize(newSize)
        }
        .onChange(of: zoomState.fitOnScreenRequestID) { _, _ in
            guard let window else { return }
            resizeWindowForFitOnScreen(window)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { notification in
            guard let resolvedWindow = matchingWindow(from: notification.object) else { return }
            handleFullScreenTransition(isFullScreen: true, window: resolvedWindow)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { notification in
            guard let resolvedWindow = matchingWindow(from: notification.object) else { return }
            handleFullScreenTransition(isFullScreen: false, window: resolvedWindow)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didChangeScreenNotification)) { notification in
            guard let resolvedWindow = matchingWindow(from: notification.object) else { return }
            updateZoomContext(for: resolvedWindow)
        }
        .background {
            KeyboardHandlerView(
                onLeftArrow: appState.showPreviousImage,
                onRightArrow: appState.showNextImage
            )
        }
        .background {
            WindowAccessor { nsWindow in
                let isNewWindow = window !== nsWindow
                window = nsWindow

                if isNewWindow {
                    configureWindow(nsWindow)
                    updateWindowTitle(with: appState.currentImageURL)
                }

                isFullScreen = nsWindow.styleMask.contains(.fullScreen)
                updateZoomContext(for: nsWindow)
            }
        }
    }

    @ViewBuilder
    private var viewerContent: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            if let image = appState.currentImage {
                GeometryReader { proxy in
                    ZStack {
                        // Use a blurred version of the same image as a backdrop so
                        // the main image can stay fully visible without black bars.
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .blur(radius: 24)
                            .opacity(0.75)
                            .clipped()

                        Image(nsImage: image)
                            .resizable()
                            .frame(
                                width: max(zoomState.displayedImageSize.width, 1),
                                height: max(zoomState.displayedImageSize.height, 1)
                            )
                            .offset(zoomState.offset)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .overlay {
                        ImageInteractionView(
                            onWheelZoom: { deltaY, anchor in
                                zoomState.handleWheelZoom(deltaY: deltaY, anchor: anchor)
                            },
                            onMagnify: { delta, anchor in
                                zoomState.handleMagnify(delta: delta, anchor: anchor)
                            },
                            onDoubleClick: { anchor in
                                if zoomState.containsDisplayedImage(point: anchor) {
                                    zoomState.toggleFitAndActualSize(anchor: anchor)
                                } else {
                                    toggleFullScreen()
                                }
                            },
                            onPointerActivity: registerUserActivity,
                            onPanStart: {
                                zoomState.beginPan()
                            },
                            onPanChange: { translation in
                                zoomState.updatePan(translation: translation)
                            },
                            onPanEnd: {
                                zoomState.endPan()
                            }
                        )
                    }
                    .onAppear {
                        zoomState.updateViewportSize(proxy.size)
                    }
                    .onChange(of: proxy.size) { _, newSize in
                        zoomState.updateViewportSize(newSize)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Text("No image loaded")
                        .font(.title2.weight(.semibold))
                    Text("Choose an image to start browsing the folder.")
                        .foregroundStyle(.secondary)
                    Button("Open Image") {
                        appState.openImagePicker()
                    }
                }
                .padding(24)
                .foregroundStyle(.white)
            }
        }
    }

    private var statusBar: some View {
        HStack {
            Spacer(minLength: 0)

            Text(zoomState.statusText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.84))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: statusBarHeight)
        .background(isFullScreen ? Color.black.opacity(0.58) : Color.black.opacity(0.84))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(isFullScreen ? 0.10 : 0.08))
                .frame(height: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: isFullScreen ? 8 : 0, style: .continuous))
        .onHover { hovering in
            if hovering {
                registerUserActivity()
            }
        }
    }

    private func configureWindow(_ window: NSWindow) {
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false

        if let screen = window.screen ?? NSScreen.main {
            let frame = screen.visibleFrame
            window.setFrame(frame, display: true)
        } else {
            window.zoom(nil)
        }
    }

    private func updateWindowTitle(with url: URL?) {
        window?.title = url?.lastPathComponent ?? "Open Image"
    }

    private func updateZoomContext(for window: NSWindow) {
        let screen = window.screen ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? .zero
        let availableContentSize = window.contentRect(forFrameRect: visibleFrame).size
        let fitOnScreenViewportHeight = max(0, availableContentSize.height - statusBarHeight)

        zoomState.updateScreen(
            visibleFrameSize: CGSize(width: availableContentSize.width, height: fitOnScreenViewportHeight),
            backingScaleFactor: window.backingScaleFactor
        )
    }

    private func resizeWindowForFitOnScreen(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else { return }

        let visibleFrame = screen.visibleFrame
        let availableContentRect = window.contentRect(forFrameRect: visibleFrame)
        let maxContentSize = availableContentRect.size
        let targetViewportSize = zoomState.fitOnScreenViewportSize()

        guard targetViewportSize != .zero else { return }

        let contentSize = CGSize(
            width: min(targetViewportSize.width, maxContentSize.width),
            height: min(targetViewportSize.height + statusBarHeight, maxContentSize.height)
        )

        let targetFrame = centeredFrame(
            forContentSize: contentSize,
            in: visibleFrame,
            window: window
        )

        window.setFrame(targetFrame, display: true, animate: true)
    }

    private func centeredFrame(forContentSize contentSize: CGSize, in visibleFrame: NSRect, window: NSWindow) -> NSRect {
        let frameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
        let origin = CGPoint(
            x: visibleFrame.midX - frameSize.width / 2,
            y: visibleFrame.midY - frameSize.height / 2
        )

        return NSRect(origin: origin, size: frameSize)
    }

    private func toggleFullScreen() {
        registerUserActivity()
        window?.toggleFullScreen(nil)
    }

    private func matchingWindow(from notificationObject: Any?) -> NSWindow? {
        guard let resolvedWindow = notificationObject as? NSWindow, resolvedWindow === window else { return nil }
        return resolvedWindow
    }

    private func handleFullScreenTransition(isFullScreen: Bool, window: NSWindow) {
        self.isFullScreen = isFullScreen
        updateZoomContext(for: window)

        if isFullScreen {
            registerUserActivity()
        } else {
            cancelAutoHide()
            isChromeVisible = true
        }
    }

    private func registerUserActivity() {
        guard isFullScreen else { return }

        cancelAutoHide()

        if !isChromeVisible {
            isChromeVisible = true
        }

        let workItem = DispatchWorkItem {
            guard isFullScreen else { return }
            isChromeVisible = false
            NSCursor.setHiddenUntilMouseMoves(true)
        }

        autoHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + fullScreenAutoHideDelay, execute: workItem)
    }

    private func cancelAutoHide() {
        autoHideWorkItem?.cancel()
        autoHideWorkItem = nil
    }
}

private struct KeyboardHandlerView: NSViewRepresentable {
    let onLeftArrow: () -> Void
    let onRightArrow: () -> Void

    func makeNSView(context: Context) -> KeyAwareView {
        let view = KeyAwareView()
        view.onLeftArrow = onLeftArrow
        view.onRightArrow = onRightArrow

        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_ nsView: KeyAwareView, context: Context) {
        nsView.onLeftArrow = onLeftArrow
        nsView.onRightArrow = onRightArrow

        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class KeyAwareView: NSView {
    var onLeftArrow: (() -> Void)?
    var onRightArrow: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123:
            onLeftArrow?()
        case 124:
            onRightArrow?()
        default:
            super.keyDown(with: event)
        }
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onResolve(window)
            }
        }
    }
}

private struct ImageInteractionView: NSViewRepresentable {
    let onWheelZoom: (CGFloat, CGPoint) -> Void
    let onMagnify: (CGFloat, CGPoint) -> Void
    let onDoubleClick: (CGPoint) -> Void
    let onPointerActivity: () -> Void
    let onPanStart: () -> Void
    let onPanChange: (CGSize) -> Void
    let onPanEnd: () -> Void

    func makeNSView(context: Context) -> ImageInteractionNSView {
        let view = ImageInteractionNSView()
        view.onWheelZoom = onWheelZoom
        view.onMagnify = onMagnify
        view.onDoubleClick = onDoubleClick
        view.onPointerActivity = onPointerActivity
        view.onPanStart = onPanStart
        view.onPanChange = onPanChange
        view.onPanEnd = onPanEnd
        return view
    }

    func updateNSView(_ nsView: ImageInteractionNSView, context: Context) {
        nsView.onWheelZoom = onWheelZoom
        nsView.onMagnify = onMagnify
        nsView.onDoubleClick = onDoubleClick
        nsView.onPointerActivity = onPointerActivity
        nsView.onPanStart = onPanStart
        nsView.onPanChange = onPanChange
        nsView.onPanEnd = onPanEnd
    }
}

private final class ImageInteractionNSView: NSView {
    var onWheelZoom: ((CGFloat, CGPoint) -> Void)?
    var onMagnify: ((CGFloat, CGPoint) -> Void)?
    var onDoubleClick: ((CGPoint) -> Void)?
    var onPointerActivity: (() -> Void)?
    var onPanStart: (() -> Void)?
    var onPanChange: ((CGSize) -> Void)?
    var onPanEnd: (() -> Void)?

    private var dragStartLocation: CGPoint?
    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool {
        true
    }

    override var isOpaque: Bool {
        false
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        self
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let nextTrackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseMoved],
            owner: self,
            userInfo: nil
        )

        addTrackingArea(nextTrackingArea)
        trackingArea = nextTrackingArea
    }

    override func scrollWheel(with event: NSEvent) {
        onPointerActivity?()
        let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 8
        onWheelZoom?(event.scrollingDeltaY * multiplier, convertedLocation(for: event))
    }

    override func magnify(with event: NSEvent) {
        onPointerActivity?()
        onMagnify?(event.magnification, convertedLocation(for: event))
    }

    override func mouseMoved(with event: NSEvent) {
        onPointerActivity?()
    }

    override func mouseDown(with event: NSEvent) {
        onPointerActivity?()

        if event.clickCount == 2 {
            dragStartLocation = nil
            onDoubleClick?(convertedLocation(for: event))
            return
        }

        dragStartLocation = convertedLocation(for: event)
        onPanStart?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStartLocation else { return }

        onPointerActivity?()
        let currentLocation = convertedLocation(for: event)
        onPanChange?(
            CGSize(
                width: currentLocation.x - dragStartLocation.x,
                height: currentLocation.y - dragStartLocation.y
            )
        )
    }

    override func mouseUp(with event: NSEvent) {
        onPointerActivity?()
        dragStartLocation = nil
        onPanEnd?()
    }

    private func convertedLocation(for event: NSEvent) -> CGPoint {
        let point = convert(event.locationInWindow, from: nil)
        return CGPoint(x: point.x, y: bounds.height - point.y)
    }
}
