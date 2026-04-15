import AppKit
import SwiftUI

struct ImageViewerView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var zoomState: ZoomState
    @EnvironmentObject private var slideshowState: SlideshowPlaybackState
    @EnvironmentObject private var cropState: CropState
    @EnvironmentObject private var colorAdjustmentState: ColorAdjustmentState
    @AppStorage("showsStatusBar") private var showsStatusBar = true
    @AppStorage("showsInspector") private var showsInspector = false
    @AppStorage("showsThumbnailStrip") private var showsThumbnailStrip = true
    @StateObject private var animatedPlayback = AnimatedImagePlaybackState()
    @StateObject private var thumbnailStripState = ThumbnailStripState()
    @State private var window: NSWindow?
    @State private var activeSheet: ViewerSheet?
    @State private var deleteConfirmationTarget: DeleteConfirmationTarget?
    @State private var isFullScreen = false
    @State private var isChromeVisible = true
    @State private var autoHideWorkItem: DispatchWorkItem?
    @State private var slideshowDirection: SlideshowTransitionDirection = .forward
    private let fullScreenChromeInset: CGFloat = 10
    private let fullScreenAutoHideDelay: TimeInterval = 1.8
    private let inspectorWidth: CGFloat = 300

    var body: some View {
        alertingContent
    }

    private var baseStyledContent: some View {
        rootContent
        .background(Color.black.opacity(0.92))
        .animation(.easeOut(duration: 0.16), value: isChromeVisible)
    }

    private var appearanceObservedContent: some View {
        baseStyledContent
        .onAppear {
            appState.loadInitialImage()
            zoomState.updateImagePixelSize(appState.currentImagePixelSize)
            animatedPlayback.setAnimatedImage(appState.currentAnimatedImage)
            slideshowState.onAdvance = advanceSlideshow
            thumbnailStripState.updateScope(urls: appState.imageURLs)
            refreshColorPreview()
        }
        .onDisappear {
            slideshowState.onAdvance = nil
            slideshowState.pause()
            colorAdjustmentState.deactivate()
        }
    }

    private var imageObservedContent: some View {
        appearanceObservedContent
        .onChange(of: appState.currentImageURL) { _, newURL in
            updateWindowTitle(with: newURL)
            animatedPlayback.setAnimatedImage(appState.currentAnimatedImage)
            if cropState.isActive {
                cropState.deactivate()
            }
            if newURL == nil {
                colorAdjustmentState.deactivate()
            } else {
                refreshColorPreview()
            }
        }
        .onChange(of: appState.currentImagePixelSize) { _, newSize in
            zoomState.updateImagePixelSize(newSize)
            if newSize == nil {
                colorAdjustmentState.deactivate()
            }
        }
        .onChange(of: animatedPlayback.currentFrameIndex) { _, _ in
            refreshColorPreview()
        }
        .onChange(of: appState.imageURLs) { _, newURLs in
            thumbnailStripState.updateScope(urls: newURLs)
        }
    }

    private var lifecycleObservedContent: some View {
        imageObservedContent
        .onChange(of: appState.renameRequestID) { _, _ in
            presentRenameSheetIfPossible()
        }
        .onChange(of: appState.manageDestinationsRequestID) { _, _ in
            activeSheet = .manageDestinations
        }
        .onChange(of: appState.deleteRequestID) { _, _ in
            presentDeleteConfirmationIfPossible()
        }
        .onChange(of: cropState.activateRequestID) { _, _ in
            startCrop()
        }
        .onChange(of: cropState.saveRequestID) { _, _ in
            saveCrop(mode: .overwriteOriginal)
        }
        .onChange(of: cropState.saveAsRequestID) { _, _ in
            saveCrop(mode: .saveAs)
        }
        .onChange(of: appState.imageURLs.count) { _, newCount in
            if newCount < 2 {
                slideshowState.pause()
            }
        }
        .onChange(of: colorAdjustmentState.activateRequestID) { _, _ in
            startColorAdjustment()
        }
        .onChange(of: colorAdjustmentState.isActive) { _, _ in
            refreshColorPreview()
        }
        .onChange(of: colorAdjustmentState.brightness) { _, _ in
            refreshColorPreview()
        }
        .onChange(of: colorAdjustmentState.contrast) { _, _ in
            refreshColorPreview()
        }
        .onChange(of: colorAdjustmentState.gamma) { _, _ in
            refreshColorPreview()
        }
        .onChange(of: slideshowState.isPlaying) { _, isPlaying in
            handleSlideshowPlaybackChange(isPlaying: isPlaying)
        }
        .onChange(of: cropState.isActive) { _, isActive in
            handleCropModeChange(isActive: isActive)
        }
    }

    private var windowObservedContent: some View {
        lifecycleObservedContent
        .onChange(of: showsStatusBar) { _, _ in
            guard let window else { return }
            updateZoomContext(for: window)

            if zoomState.mode == .fitOnScreen, !window.styleMask.contains(.fullScreen) {
                resizeWindowForFitOnScreen(window)
            }
        }
        .onChange(of: showsInspector) { _, _ in
            guard let window else { return }
            updateZoomContext(for: window)

            if zoomState.mode == .fitOnScreen, !window.styleMask.contains(.fullScreen) {
                resizeWindowForFitOnScreen(window)
            }
        }
        .onChange(of: showsThumbnailStrip) { _, _ in
            guard let window else { return }
            updateZoomContext(for: window)

            if zoomState.mode == .fitOnScreen, !window.styleMask.contains(.fullScreen) {
                resizeWindowForFitOnScreen(window)
            }
        }
        .onChange(of: appState.imageURLs.count) { _, _ in
            guard let window else { return }
            updateZoomContext(for: window)

            if zoomState.mode == .fitOnScreen, !window.styleMask.contains(.fullScreen) {
                resizeWindowForFitOnScreen(window)
            }
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
    }

    private var interactionWrappedContent: some View {
        windowObservedContent
        .background {
            KeyboardHandlerView(
                onPrevious: showPreviousImage,
                onNext: showNextImage,
                onFirst: showFirstImage,
                onLast: showLastImage,
                onRename: appState.requestRenameCurrentImage,
                onDelete: appState.requestDeleteCurrentImage,
                onSetFinderLabel: appState.setFinderLabel(_:),
                onMoveToDestinationSlot: appState.moveCurrentImage(toDestinationSlot:),
                onCopyToDestinationSlot: appState.copyCurrentImage(toDestinationSlot:),
                onCancelCrop: cancelCrop,
                onSaveCrop: {
                    cropState.requestSave()
                },
                onCancelColorAdjustments: {
                    colorAdjustmentState.deactivate()
                },
                onToggleSlideshow: toggleSlideshowFromKeyboard,
                onJumpBackward: {
                    jumpImages(by: -10)
                },
                onJumpForward: {
                    jumpImages(by: 10)
                },
                isCropActive: cropState.isActive,
                isColorAdjustmentActive: colorAdjustmentState.isActive,
                isSlideshowPlaying: slideshowState.isPlaying
            )
        }
        .background {
            WindowAccessor { nsWindow in
                let isNewWindow = window !== nsWindow
                window = nsWindow

                if isNewWindow {
                    configureWindow(nsWindow)
                    updateWindowTitle(with: appState.currentImageURL)

                    if slideshowState.isPlaying {
                        handleSlideshowPlaybackChange(isPlaying: true)
                    }
                }

                isFullScreen = nsWindow.styleMask.contains(.fullScreen)
                updateZoomContext(for: nsWindow)
            }
        }
    }

    private var presentedContent: some View {
        interactionWrappedContent
        .sheet(item: $activeSheet, content: sheetView)
        .confirmationDialog(
            "Move to Trash?",
            isPresented: isDeleteConfirmationPresented,
            titleVisibility: .visible,
            presenting: deleteConfirmationTarget
        ) { _ in
            Button("Move to Trash", role: .destructive) {
                appState.trashCurrentImage()
                deleteConfirmationTarget = nil
            }

            Button("Cancel", role: .cancel) {
                deleteConfirmationTarget = nil
            }
        } message: { target in
            Text("Move \"\(target.url.lastPathComponent)\" to the Trash?")
        }
    }

    private var alertingContent: some View {
        presentedContent
        .alert(item: activeAlertBinding) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if isFullScreen {
            ZStack(alignment: .bottom) {
                contentLayout

                if isChromeVisible {
                    fullScreenChrome
                }
            }
        } else {
            VStack(spacing: 0) {
                contentLayout

                windowedChrome
            }
        }
    }

    @ViewBuilder
    private var fullScreenChrome: some View {
        VStack(spacing: 8) {
            if thumbnailStripShouldShow {
                thumbnailStrip
            }

            if showsStatusBar {
                statusBar
            }
        }
        .padding(.horizontal, fullScreenChromeInset)
        .padding(.bottom, fullScreenChromeInset)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    @ViewBuilder
    private var windowedChrome: some View {
        if thumbnailStripShouldShow {
            thumbnailStrip
        }

        if showsStatusBar {
            statusBar
        }
    }

    @ViewBuilder
    private var contentLayout: some View {
        HStack(spacing: 0) {
            viewerContent

            if showsInspector, !slideshowState.isPlaying, !cropState.isActive, !colorAdjustmentState.isActive {
                MetadataInspectorView(
                    metadata: appState.currentMetadata,
                    isFullScreen: isFullScreen
                )
                .onHover { hovering in
                    if hovering {
                        registerUserActivity()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var viewerContent: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            if let foregroundImage = displayedImage {
                GeometryReader { proxy in
                    ZStack {
                        slideImageCanvas(
                            foregroundImage: foregroundImage,
                            backgroundImage: backgroundImage,
                            viewportSize: proxy.size
                        )
                        .id(slideIdentity)
                        .transition(slideshowTransition)

                        if colorAdjustmentState.isActive {
                            VStack {
                                HStack {
                                    Spacer()

                                    ColorAdjustmentPanelView(
                                        colorAdjustmentState: colorAdjustmentState,
                                        onPointerActivity: registerUserActivity,
                                        onClose: {
                                            colorAdjustmentState.deactivate()
                                        }
                                    )
                                }

                                Spacer()
                            }
                            .padding(16)
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .overlay {
                        if cropState.isActive {
                            CropOverlayView(
                                cropState: cropState,
                                viewportSize: proxy.size,
                                onPointerActivity: registerUserActivity
                            )
                        } else {
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
        StatusBarView(
            fileName: appState.currentImageURL?.lastPathComponent,
            pixelSize: appState.currentImagePixelSize,
            fileSize: appState.currentImageFileSize,
            format: appState.currentImageFormatText,
            positionText: appState.currentImagePositionText,
            zoomText: zoomState.statusText,
            actionMessage: appState.fileActionMessage,
            cropState: cropStatusBarState,
            slideshowState: cropState.isActive ? nil : slideshowStatusBarState,
            animationState: cropState.isActive ? nil : animatedStatusBarState,
            isFullScreen: isFullScreen
        )
        .onHover { hovering in
            if hovering {
                registerUserActivity()
            }
        }
    }

    private var thumbnailStrip: some View {
        ThumbnailStripView(
            thumbnailStripState: thumbnailStripState,
            imageURLs: appState.imageURLs,
            selectedIndex: appState.currentIndex,
            isFullScreen: isFullScreen,
            onSelectIndex: selectThumbnail(at:),
            onPointerActivity: registerUserActivity
        )
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
        let availableViewportWidth = max(0, availableContentSize.width - currentInspectorWidth)
        let fitOnScreenViewportHeight = max(
            0,
            availableContentSize.height - currentWindowedStatusBarHeight - currentWindowedThumbnailStripHeight
        )

        zoomState.updateScreen(
            visibleFrameSize: CGSize(width: availableViewportWidth, height: fitOnScreenViewportHeight),
            backingScaleFactor: window.backingScaleFactor
        )
    }

    private func resizeWindowForFitOnScreen(_ window: NSWindow) {
        guard !window.styleMask.contains(.fullScreen) else { return }
        guard let screen = window.screen ?? NSScreen.main else { return }

        let visibleFrame = screen.visibleFrame
        let availableContentRect = window.contentRect(forFrameRect: visibleFrame)
        let maxContentSize = availableContentRect.size
        let targetViewportSize = zoomState.fitOnScreenViewportSize()

        guard targetViewportSize != .zero else { return }

        let contentSize = CGSize(
            width: min(targetViewportSize.width + currentInspectorWidth, maxContentSize.width),
            height: min(
                targetViewportSize.height + currentWindowedStatusBarHeight + currentWindowedThumbnailStripHeight,
                maxContentSize.height
            )
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

    private var currentWindowedStatusBarHeight: CGFloat {
        showsStatusBar && !isFullScreen ? 26 : 0
    }

    private var currentWindowedThumbnailStripHeight: CGFloat {
        thumbnailStripShouldShow && !isFullScreen ? 88 : 0
    }

    private var currentInspectorWidth: CGFloat {
        showsInspector && !slideshowState.isPlaying && !cropState.isActive && !colorAdjustmentState.isActive ? inspectorWidth : 0
    }

    private var thumbnailStripShouldShow: Bool {
        showsThumbnailStrip && appState.imageURLs.count > 1 && !slideshowState.isPlaying && !cropState.isActive
    }

    private var rawDisplayedImage: NSImage? {
        animatedPlayback.currentFrameImage ?? appState.currentImage
    }

    private var displayedImage: NSImage? {
        colorAdjustmentState.previewImage ?? rawDisplayedImage
    }

    private var backgroundImage: NSImage? {
        appState.currentImage ?? rawDisplayedImage
    }

    private var slideIdentity: String {
        appState.currentImageURL?.standardizedFileURL.path ?? "no-image"
    }

    private var canSaveCropInPlace: Bool {
        guard let currentImageURL = appState.currentImageURL else { return false }

        return cropState.canSaveSelection
            && CropExporter.canOverwrite(
                url: currentImageURL,
                isAnimatedSource: appState.currentAnimatedImage?.isAnimated ?? false
            )
    }

    private var cropStatusBarState: StatusBarCropState? {
        guard cropState.isActive else { return nil }

        return StatusBarCropState(
            aspectRatioPreset: cropState.aspectRatioPreset,
            selectionText: cropState.selectionText,
            canSaveInPlace: canSaveCropInPlace,
            canSaveAs: cropState.canSaveSelection && appState.canCropCurrentImage,
            onSelectAspectRatio: { preset in
                registerUserActivity()
                cropState.setAspectRatioPreset(preset, imagePixelSize: appState.currentImagePixelSize)
            },
            onSave: {
                registerUserActivity()
                cropState.requestSave()
            },
            onSaveAs: {
                registerUserActivity()
                cropState.requestSaveAs()
            },
            onCancel: {
                cancelCrop()
            }
        )
    }

    private var slideshowTransition: AnyTransition {
        slideshowState.transitionStyle.transition(for: slideshowDirection)
    }

    private var slideshowAnimation: Animation {
        .easeInOut(duration: 0.28)
    }

    private var slideshowStatusBarState: StatusBarSlideshowState? {
        guard appState.currentImageURL != nil, appState.imageURLs.count > 1 else { return nil }

        return StatusBarSlideshowState(
            isPlaying: slideshowState.isPlaying,
            intervalText: slideshowState.intervalText,
            intervals: slideshowState.availableIntervals,
            onTogglePlayback: {
                registerUserActivity()
                slideshowState.togglePlayback()
            },
            onPreviousSlide: {
                registerUserActivity()
                navigateSlide(direction: .backward, wrapping: true, animated: true) {
                    appState.showPreviousImage(wrapping: true)
                }
            },
            onNextSlide: {
                registerUserActivity()
                navigateSlide(direction: .forward, wrapping: true, animated: true) {
                    appState.showNextImage(wrapping: true)
                }
            },
            onSelectInterval: { interval in
                registerUserActivity()
                slideshowState.setInterval(interval)
            }
        )
    }

    private var animatedStatusBarState: StatusBarAnimationState? {
        guard animatedPlayback.isAnimated else { return nil }

        return StatusBarAnimationState(
            isPlaying: animatedPlayback.isPlaying,
            frameText: animatedPlayback.frameStatusText,
            playbackRateText: animatedPlayback.playbackRateText,
            playbackRates: animatedPlayback.availablePlaybackRates,
            onTogglePlayback: {
                registerUserActivity()
                animatedPlayback.togglePlayback()
            },
            onStepBackward: {
                registerUserActivity()
                animatedPlayback.stepBackward()
            },
            onStepForward: {
                registerUserActivity()
                animatedPlayback.stepForward()
            },
            onSelectPlaybackRate: { rate in
                registerUserActivity()
                animatedPlayback.setPlaybackRate(rate)
            }
        )
    }

    @ViewBuilder
    private func slideImageCanvas(
        foregroundImage: NSImage,
        backgroundImage: NSImage?,
        viewportSize: CGSize
    ) -> some View {
        // Keep a blurred poster behind the main image so transparent or tall/narrow
        // images still fill the canvas while the actual slide stays fully readable.
        if let backgroundImage {
            Image(nsImage: backgroundImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: viewportSize.width, height: viewportSize.height)
                .blur(radius: 24)
                .opacity(0.75)
                .clipped()
        }

        Image(nsImage: foregroundImage)
            .resizable()
            .frame(
                width: max(zoomState.displayedImageSize.width, 1),
                height: max(zoomState.displayedImageSize.height, 1)
            )
            .offset(zoomState.offset)
    }

    private func showPreviousImage() {
        navigateSlide(direction: .backward, wrapping: false, animated: slideshowState.isPlaying) {
            appState.showPreviousImage()
        }
    }

    private func showNextImage() {
        navigateSlide(direction: .forward, wrapping: false, animated: slideshowState.isPlaying) {
            appState.showNextImage()
        }
    }

    private func showFirstImage() {
        navigateSlide(direction: .backward, wrapping: false, animated: slideshowState.isPlaying) {
            appState.showFirstImage()
        }
    }

    private func showLastImage() {
        navigateSlide(direction: .forward, wrapping: false, animated: slideshowState.isPlaying) {
            appState.showLastImage()
        }
    }

    private func selectThumbnail(at index: Int) {
        guard appState.imageURLs.indices.contains(index) else { return }

        let direction: SlideshowTransitionDirection = index >= appState.currentIndex ? .forward : .backward
        navigateSlide(direction: direction, wrapping: false, animated: false) {
            appState.showImage(at: index)
        }
    }

    private func jumpImages(by delta: Int) {
        guard delta != 0 else { return }

        navigateSlide(
            direction: delta > 0 ? .forward : .backward,
            wrapping: false,
            animated: slideshowState.isPlaying
        ) {
            appState.jumpImages(by: delta)
        }
    }

    private func advanceSlideshow() {
        navigateSlide(direction: .forward, wrapping: true, animated: true) {
            appState.showNextImage(wrapping: true)
        }
    }

    private func toggleSlideshowFromKeyboard() {
        guard !cropState.isActive else { return }
        guard slideshowState.isPlaying || appState.canRunSlideshow else { return }
        registerUserActivity()
        slideshowState.togglePlayback()
    }

    private func startColorAdjustment() {
        guard appState.currentImageURL != nil else { return }

        colorAdjustmentState.activate()
        refreshColorPreview()
        registerUserActivity()
    }

    private func refreshColorPreview() {
        colorAdjustmentState.refreshPreview(from: rawDisplayedImage)
    }

    private func startCrop() {
        guard appState.canCropCurrentImage else { return }

        if slideshowState.isPlaying {
            slideshowState.pause()
        }

        if animatedPlayback.isPlaying {
            animatedPlayback.togglePlayback()
        }

        if cropState.isActive {
            cropState.deactivate()
        }

        cropState.activate(imagePixelSize: appState.currentImagePixelSize)
    }

    private func cancelCrop() {
        registerUserActivity()
        cropState.deactivate()
    }

    private func saveCrop(mode: CropSaveMode) {
        guard
            cropState.isActive,
            let sourceImage = rawDisplayedImage,
            let sourcePixelSize = appState.currentImagePixelSize,
            let selectionRect = cropState.normalizedSelectionRect
        else {
            return
        }

        do {
            let destinationURL = try CropExporter.saveCroppedImage(
                from: sourceImage,
                sourcePixelSize: sourcePixelSize,
                cropRect: selectionRect,
                originalURL: appState.currentImageURL,
                isAnimatedSource: appState.currentAnimatedImage?.isAnimated ?? false,
                mode: mode
            )

            cropState.deactivate()
            appState.loadImage(at: destinationURL)

            switch mode {
            case .overwriteOriginal:
                appState.showFileActionMessage("Cropped and saved")
            case .saveAs:
                appState.showFileActionMessage("Saved cropped copy")
            }
        } catch let error as LocalizedError {
            if let description = error.errorDescription {
                appState.showErrorAlert(title: "Crop Failed", message: description)
            }
        } catch {
            appState.showErrorAlert(title: "Crop Failed", message: error.localizedDescription)
        }
    }

    private func navigateSlide(
        direction: SlideshowTransitionDirection,
        wrapping: Bool,
        animated: Bool,
        action: () -> Void
    ) {
        slideshowDirection = direction

        if animated {
            withAnimation(slideshowAnimation) {
                action()
            }
        } else {
            action()
        }

        if wrapping, appState.currentImageURL == nil {
            slideshowState.pause()
        }
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
            if slideshowState.isPlaying {
                slideshowState.pause()
            }
            cancelAutoHide()
            isChromeVisible = true
        }
    }

    private func handleSlideshowPlaybackChange(isPlaying: Bool) {
        guard let window else { return }

        updateZoomContext(for: window)

        if isPlaying {
            guard appState.canRunSlideshow else {
                slideshowState.pause()
                return
            }

            if cropState.isActive {
                cropState.deactivate()
            }

            zoomState.fitOnScreen()

            if !window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            } else {
                registerUserActivity()
            }
        } else {
            cancelAutoHide()
            isChromeVisible = true
        }
    }

    private func handleCropModeChange(isActive: Bool) {
        if let window {
            updateZoomContext(for: window)

            if zoomState.mode == .fitOnScreen, !window.styleMask.contains(.fullScreen) {
                resizeWindowForFitOnScreen(window)
            }
        }

        if isActive {
            cancelAutoHide()
            isChromeVisible = true
            registerUserActivity()
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

    private func presentRenameSheetIfPossible() {
        guard let currentImageURL = appState.currentImageURL else { return }
        activeSheet = .rename(currentImageURL)
    }

    private func presentDeleteConfirmationIfPossible() {
        guard let currentImageURL = appState.currentImageURL else { return }
        deleteConfirmationTarget = DeleteConfirmationTarget(url: currentImageURL)
    }

    private var activeAlertBinding: Binding<FileActionAlertState?> {
        Binding(
            get: { appState.activeAlert },
            set: { appState.activeAlert = $0 }
        )
    }

    private var isDeleteConfirmationPresented: Binding<Bool> {
        Binding(
            get: { deleteConfirmationTarget != nil },
            set: { isPresented in
                if !isPresented {
                    deleteConfirmationTarget = nil
                }
            }
        )
    }

    @ViewBuilder
    private func sheetView(for sheet: ViewerSheet) -> some View {
        switch sheet {
        case let .rename(url):
            RenameImageSheet(
                imageURL: url,
                validationMessage: { baseName in
                    appState.renameValidationMessage(forBaseName: baseName, imageURL: url)
                },
                onRename: { baseName in
                    try appState.renameImage(at: url, toBaseName: baseName)
                }
            )
        case .manageDestinations:
            TransferDestinationsSheet(
                destinations: appState.fileActionDestinations,
                currentImageURL: appState.currentImageURL,
                onChooseDestination: { slotNumber, folderURL in
                    appState.setFileActionDestination(folderURL, forSlot: slotNumber)
                },
                onClearDestination: { slotNumber in
                    appState.clearFileActionDestination(forSlot: slotNumber)
                }
            )
        }
    }
}

private struct KeyboardHandlerView: NSViewRepresentable {
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onFirst: () -> Void
    let onLast: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let onSetFinderLabel: (FinderLabel) -> Void
    let onMoveToDestinationSlot: (Int) -> Void
    let onCopyToDestinationSlot: (Int) -> Void
    let onCancelCrop: () -> Void
    let onSaveCrop: () -> Void
    let onCancelColorAdjustments: () -> Void
    let onToggleSlideshow: () -> Void
    let onJumpBackward: () -> Void
    let onJumpForward: () -> Void
    let isCropActive: Bool
    let isColorAdjustmentActive: Bool
    let isSlideshowPlaying: Bool

    func makeNSView(context: Context) -> KeyAwareView {
        let view = KeyAwareView()
        view.onPrevious = onPrevious
        view.onNext = onNext
        view.onFirst = onFirst
        view.onLast = onLast
        view.onRename = onRename
        view.onDelete = onDelete
        view.onSetFinderLabel = onSetFinderLabel
        view.onMoveToDestinationSlot = onMoveToDestinationSlot
        view.onCopyToDestinationSlot = onCopyToDestinationSlot
        view.onCancelCrop = onCancelCrop
        view.onSaveCrop = onSaveCrop
        view.onCancelColorAdjustments = onCancelColorAdjustments
        view.onToggleSlideshow = onToggleSlideshow
        view.onJumpBackward = onJumpBackward
        view.onJumpForward = onJumpForward
        view.isCropActive = isCropActive
        view.isColorAdjustmentActive = isColorAdjustmentActive
        view.isSlideshowPlaying = isSlideshowPlaying
        return view
    }

    func updateNSView(_ nsView: KeyAwareView, context: Context) {
        nsView.onPrevious = onPrevious
        nsView.onNext = onNext
        nsView.onFirst = onFirst
        nsView.onLast = onLast
        nsView.onRename = onRename
        nsView.onDelete = onDelete
        nsView.onSetFinderLabel = onSetFinderLabel
        nsView.onMoveToDestinationSlot = onMoveToDestinationSlot
        nsView.onCopyToDestinationSlot = onCopyToDestinationSlot
        nsView.onCancelCrop = onCancelCrop
        nsView.onSaveCrop = onSaveCrop
        nsView.onCancelColorAdjustments = onCancelColorAdjustments
        nsView.onToggleSlideshow = onToggleSlideshow
        nsView.onJumpBackward = onJumpBackward
        nsView.onJumpForward = onJumpForward
        nsView.isCropActive = isCropActive
        nsView.isColorAdjustmentActive = isColorAdjustmentActive
        nsView.isSlideshowPlaying = isSlideshowPlaying
    }
}

private final class KeyAwareView: NSView {
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onFirst: (() -> Void)?
    var onLast: (() -> Void)?
    var onRename: (() -> Void)?
    var onDelete: (() -> Void)?
    var onSetFinderLabel: ((FinderLabel) -> Void)?
    var onMoveToDestinationSlot: ((Int) -> Void)?
    var onCopyToDestinationSlot: ((Int) -> Void)?
    var onCancelCrop: (() -> Void)?
    var onSaveCrop: (() -> Void)?
    var onCancelColorAdjustments: (() -> Void)?
    var onToggleSlideshow: (() -> Void)?
    var onJumpBackward: (() -> Void)?
    var onJumpForward: (() -> Void)?
    var isCropActive = false
    var isColorAdjustmentActive = false
    var isSlideshowPlaying = false

    private var eventMonitor: Any?

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard window != nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event) ?? event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        // Don't intercept when a sheet or modal is active (e.g. rename sheet, open panel)
        guard NSApp.modalWindow == nil else { return event }
        guard window?.attachedSheet == nil else { return event }
        guard window?.isKeyWindow == true else { return event }

        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])

        if isCropActive {
            switch event.keyCode {
            case 53:
                if modifiers.isEmpty { onCancelCrop?(); return nil }
            case 36, 76:
                if modifiers.isEmpty { onSaveCrop?(); return nil }
            default:
                break
            }

            return event
        }

        if isColorAdjustmentActive {
            switch event.keyCode {
            case 53:
                if modifiers.isEmpty { onCancelColorAdjustments?(); return nil }
            default:
                break
            }
        }

        if let finderLabel = finderLabel(for: event.keyCode), modifiers == [.command, .option] {
            onSetFinderLabel?(finderLabel)
            return nil
        }

        if let destinationSlot = destinationSlot(for: event.keyCode) {
            if modifiers.isEmpty {
                onMoveToDestinationSlot?(destinationSlot)
                return nil
            }

            if modifiers == [.shift] {
                onCopyToDestinationSlot?(destinationSlot)
                return nil
            }
        }

        switch event.keyCode {
        case 1:
            if modifiers == [.command, .option] { onToggleSlideshow?(); return nil }
        case 53:
            if modifiers.isEmpty, isSlideshowPlaying { onToggleSlideshow?(); return nil }
        case 123:
            if modifiers == [.command] { onJumpBackward?(); return nil }
            if modifiers.isEmpty { onPrevious?(); return nil }
        case 124:
            if modifiers == [.command] { onJumpForward?(); return nil }
            if modifiers.isEmpty { onNext?(); return nil }
        case 49:
            if modifiers.isEmpty { onNext?(); return nil }
        case 51:
            if modifiers == [.command] { onDelete?(); return nil }
            if modifiers.isEmpty { onPrevious?(); return nil }
        case 115:
            if modifiers.isEmpty { onFirst?(); return nil }
        case 119:
            if modifiers.isEmpty { onLast?(); return nil }
        case 36, 76:
            if modifiers.isEmpty { onRename?(); return nil }
        default:
            break
        }

        return event
    }

    private func destinationSlot(for keyCode: UInt16) -> Int? {
        switch keyCode {
        case 18: return 1
        case 19: return 2
        case 20: return 3
        case 21: return 4
        case 23: return 5
        case 22: return 6
        case 26: return 7
        case 28: return 8
        case 25: return 9
        default: return nil
        }
    }

    private func finderLabel(for keyCode: UInt16) -> FinderLabel? {
        switch keyCode {
        case 29: return FinderLabel.none
        case 18: return .gray
        case 19: return .green
        case 20: return .purple
        case 21: return .blue
        case 23: return .yellow
        case 22: return .red
        case 26: return .orange
        default: return nil
        }
    }
}

private enum ViewerSheet: Identifiable {
    case rename(URL)
    case manageDestinations

    var id: String {
        switch self {
        case let .rename(url):
            return "rename:\(url.path)"
        case .manageDestinations:
            return "manage-destinations"
        }
    }
}

private struct DeleteConfirmationTarget: Identifiable {
    let id = UUID()
    let url: URL
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
