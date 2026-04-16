import AppKit
import SwiftUI

struct CommonAppCommands: Commands {
    @AppStorage("showsStatusBar") private var showsStatusBar = true
    @AppStorage("showsInspector") private var showsInspector = false
    @AppStorage("showsThumbnailStrip") private var showsThumbnailStrip = true

    let onNewTab: () -> Void
    let onOpenImage: () -> Void
    let onShowBrowser: () -> Void

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Tab") {
                onNewTab()
            }
            .keyboardShortcut("t", modifiers: [.command])

            Button("Open Image...") {
                onOpenImage()
            }
            .keyboardShortcut("o")
        }

        CommandGroup(after: .toolbar) {
            Divider()

            Button("Toggle Full Screen") {
                NSApp.keyWindow?.toggleFullScreen(nil)
            }
            .keyboardShortcut("f", modifiers: [.command])

            Divider()

            Toggle("Show Status Bar", isOn: $showsStatusBar)
                .keyboardShortcut("/", modifiers: [.command])

            Divider()

            Toggle("Show Inspector", isOn: $showsInspector)
                .keyboardShortcut("i", modifiers: [.command])

            Divider()

            Toggle("Show Thumbnail Strip", isOn: $showsThumbnailStrip)
                .keyboardShortcut("t", modifiers: [.command, .option])

            Divider()

            Button("Show Browser") {
                onShowBrowser()
            }
            .keyboardShortcut("b", modifiers: [.command])
        }
    }
}

struct ActiveViewerCommands: Commands {
    @ObservedObject var appState: AppState
    @ObservedObject var zoomState: ZoomState
    @ObservedObject var slideshowState: SlideshowPlaybackState
    @ObservedObject var cropState: CropState
    @ObservedObject var colorAdjustmentState: ColorAdjustmentState

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Button("Copy Image") {
                appState.requestCopyCurrentImage()
            }
            .disabled(!appState.canCopyCurrentImage)

            Button("Open Image from Clipboard") {
                appState.pasteImageFromClipboard()
            }
        }

        CommandGroup(replacing: .printItem) {
            Button("Print…") {
                appState.requestPrintCurrentImage()
            }
            .keyboardShortcut("p", modifiers: [.command])
            .disabled(!appState.canPrintCurrentImage || cropState.isActive)
        }

        CommandGroup(after: .newItem) {
            Button("Export…") {
                appState.requestExportCurrentImage()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(!appState.canExportCurrentImage || cropState.isActive)

            Button("Set as Desktop Picture") {
                appState.setCurrentImageAsDesktopPicture()
            }
            .disabled(!appState.canSetDesktopPicture || cropState.isActive)

            Button("Rename...") {
                appState.requestRenameCurrentImage()
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(!appState.canRenameCurrentImage)

            Button("Move to Trash") {
                appState.requestDeleteCurrentImage()
            }
            .keyboardShortcut(.delete, modifiers: [.command])
            .disabled(!appState.canDeleteCurrentImage)
        }

        CommandMenu("Transfer") {
            Menu("Copy to") {
                ForEach(appState.fileActionDestinations) { destination in
                    Button(destination.menuTitle) {
                        appState.copyCurrentImage(toDestinationSlot: destination.slotNumber)
                    }
                    .disabled(!destination.isConfigured || !appState.canTransferCurrentImage)
                }
            }

            Menu("Move to") {
                ForEach(appState.fileActionDestinations) { destination in
                    Button(destination.menuTitle) {
                        appState.moveCurrentImage(toDestinationSlot: destination.slotNumber)
                    }
                    .disabled(!destination.isConfigured || !appState.canTransferCurrentImage)
                }
            }

            Divider()

            Button("Manage Destinations…") {
                appState.requestManageDestinations()
            }
        }

        CommandMenu("Labels") {
            Button(labelMenuTitle(for: .none)) {
                appState.setFinderLabel(.none)
            }
            .keyboardShortcut("0", modifiers: [.command, .option])
            .disabled(!appState.canSetFinderLabel)

            Divider()

            ForEach(FinderLabel.coloredCases) { label in
                Button(labelMenuTitle(for: label)) {
                    appState.setFinderLabel(label)
                }
                .keyboardShortcut(
                    KeyEquivalent(label.keyboardCharacter),
                    modifiers: [.command, .option]
                )
                .disabled(!appState.canSetFinderLabel)
            }
        }

        CommandMenu("Slideshow") {
            Button(slideshowState.playbackButtonTitle) {
                slideshowState.togglePlayback()
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
            .disabled(!appState.canRunSlideshow)

            Button("Previous Slide") {
                appState.showPreviousImage(wrapping: true)
            }
            .disabled(!appState.canRunSlideshow)

            Button("Next Slide") {
                appState.showNextImage(wrapping: true)
            }
            .disabled(!appState.canRunSlideshow)

            Divider()

            Menu("Interval") {
                ForEach(slideshowState.availableIntervals, id: \.self) { interval in
                    Button(intervalMenuTitle(for: interval)) {
                        slideshowState.setInterval(interval)
                    }
                    .disabled(!appState.canRunSlideshow)
                }
            }

            Menu("Transition") {
                ForEach(SlideshowTransitionStyle.allCases) { style in
                    Button(transitionMenuTitle(for: style)) {
                        slideshowState.setTransitionStyle(style)
                    }
                }
            }
        }

        CommandMenu("Crop") {
            Button(cropState.isActive ? "Reset Crop" : "Crop") {
                cropState.requestActivate()
            }
            .keyboardShortcut("k", modifiers: [.command])
            .disabled(!appState.canCropCurrentImage)

            Button("Save Crop") {
                cropState.requestSave()
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(!canSaveCropInPlace)

            Button("Save Crop As…") {
                cropState.requestSaveAs()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(!canSaveCropAs)

            Button("Cancel Crop") {
                cropState.deactivate()
            }
            .disabled(!cropState.isActive)

            Divider()

            Menu("Aspect Ratio") {
                ForEach(CropAspectRatioPreset.allCases) { preset in
                    Button(aspectRatioMenuTitle(for: preset)) {
                        cropState.setAspectRatioPreset(preset, imagePixelSize: appState.currentImagePixelSize)
                    }
                    .disabled(!cropState.isActive)
                }
            }
        }

        CommandMenu("Adjustments") {
            Button(colorAdjustmentState.isActive ? "Hide Color Adjustments" : "Adjust Color…") {
                if colorAdjustmentState.isActive {
                    colorAdjustmentState.deactivate()
                } else {
                    colorAdjustmentState.requestActivate()
                }
            }
            .keyboardShortcut("c", modifiers: [.command, .option])
            .disabled(!appState.canCropCurrentImage)

            Button("Reset Color Adjustments") {
                colorAdjustmentState.reset()
            }
            .disabled(!colorAdjustmentState.isActive || !colorAdjustmentState.canReset)
        }

        CommandGroup(after: .toolbar) {
            Divider()

            Button("Zoom In") {
                zoomState.zoomIn()
            }
            .keyboardShortcut("+", modifiers: [.command])
            .disabled(!zoomState.hasImage || !zoomState.canZoomIn)

            Button("Zoom Out") {
                zoomState.zoomOut()
            }
            .keyboardShortcut("-", modifiers: [.command])
            .disabled(!zoomState.hasImage || !zoomState.canZoomOut)

            Divider()

            Button("Fit in Window") {
                zoomState.fitInWindow()
            }
            .keyboardShortcut("0", modifiers: [.command])
            .disabled(!zoomState.hasImage)

            Button("Actual Size") {
                zoomState.actualSize()
            }
            .keyboardShortcut("1", modifiers: [.command])
            .disabled(!zoomState.hasImage)

            Button("Fit on Screen") {
                zoomState.fitOnScreen()
            }
            .disabled(!zoomState.hasImage)
        }
    }

    private func labelMenuTitle(for label: FinderLabel) -> String {
        if appState.currentImageFinderLabel == label {
            return "✓ \(label.title)"
        }

        return label.title
    }

    private func intervalMenuTitle(for interval: TimeInterval) -> String {
        let rounded = interval.rounded()
        let label: String
        if abs(interval - rounded) < 0.001 {
            label = "\(Int(rounded)) seconds"
        } else {
            label = "\(interval.formatted(.number.precision(.fractionLength(1)))) seconds"
        }

        if abs(slideshowState.interval - interval) < 0.001 {
            return "✓ \(label)"
        }

        return label
    }

    private func transitionMenuTitle(for style: SlideshowTransitionStyle) -> String {
        if slideshowState.transitionStyle == style {
            return "✓ \(style.title)"
        }

        return style.title
    }

    private var canSaveCropInPlace: Bool {
        guard cropState.canSaveSelection, let currentImageURL = appState.currentImageURL else { return false }

        return CropExporter.canOverwrite(
            url: currentImageURL,
            isAnimatedSource: appState.currentAnimatedImage?.isAnimated ?? false
        )
    }

    private var canSaveCropAs: Bool {
        cropState.canSaveSelection && appState.canCropCurrentImage
    }

    private func aspectRatioMenuTitle(for preset: CropAspectRatioPreset) -> String {
        if cropState.aspectRatioPreset == preset {
            return "✓ \(preset.title)"
        }

        return preset.title
    }
}
