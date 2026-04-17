import SwiftUI

struct StatusBarView: View {
    @Environment(\.xeeThemePalette) private var theme

    let fileName: String?
    let pixelSize: CGSize?
    let fileSize: Int64?
    let format: String?
    let positionText: String?
    let zoomText: String
    let actionMessage: String?
    let cropState: StatusBarCropState?
    let slideshowState: StatusBarSlideshowState?
    let animationState: StatusBarAnimationState?
    let isFullScreen: Bool

    private static let fileSizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    var body: some View {
        HStack(spacing: 8) {
            if let cropState {
                HStack(spacing: 6) {
                    Text("Crop")
                        .foregroundStyle(theme.chromePrimaryText)

                    Menu(cropState.aspectRatioPreset.title) {
                        ForEach(CropAspectRatioPreset.allCases) { preset in
                            Button(aspectRatioLabel(for: preset, selected: cropState.aspectRatioPreset == preset)) {
                                cropState.onSelectAspectRatio(preset)
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    if let selectionText = cropState.selectionText {
                        Text(selectionText)
                            .monospacedDigit()
                            .foregroundStyle(theme.chromeSecondaryText)
                    }

                    Button("Save") {
                        cropState.onSave()
                    }
                    .disabled(!cropState.canSaveInPlace)

                    Button("Save As…") {
                        cropState.onSaveAs()
                    }
                    .disabled(!cropState.canSaveAs)

                    Button("Cancel") {
                        cropState.onCancel()
                    }
                }
                .buttonStyle(.plain)

                separator
            } else if let slideshowState {
                HStack(spacing: 4) {
                    Button(action: slideshowState.onPreviousSlide) {
                        Image(systemName: "backward.fill")
                    }
                    .help("Previous Slide")

                    Button(action: slideshowState.onTogglePlayback) {
                        Image(systemName: slideshowState.isPlaying ? "pause.fill" : "play.fill")
                    }
                    .help(slideshowState.isPlaying ? "Pause Slideshow" : "Start Slideshow")

                    Button(action: slideshowState.onNextSlide) {
                        Image(systemName: "forward.fill")
                    }
                    .help("Next Slide")

                    Menu(slideshowState.intervalText) {
                        ForEach(slideshowState.intervals, id: \.self) { interval in
                            Button(intervalLabel(for: interval)) {
                                slideshowState.onSelectInterval(interval)
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .buttonStyle(.plain)

                separator
            }

            if let animationState {
                HStack(spacing: 4) {
                    Button(action: animationState.onStepBackward) {
                        Image(systemName: "backward.frame.fill")
                    }
                    .help("Previous Frame")

                    Button(action: animationState.onTogglePlayback) {
                        Image(systemName: animationState.isPlaying ? "pause.fill" : "play.fill")
                    }
                    .help(animationState.isPlaying ? "Pause" : "Play")

                    Button(action: animationState.onStepForward) {
                        Image(systemName: "forward.frame.fill")
                    }
                    .help("Next Frame")

                    Menu(animationState.playbackRateText) {
                        ForEach(animationState.playbackRates, id: \.self) { rate in
                            Button(rateLabel(for: rate)) {
                                animationState.onSelectPlaybackRate(rate)
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    if let frameText = animationState.frameText {
                        Text(frameText)
                            .monospacedDigit()
                            .foregroundStyle(theme.chromeSecondaryText)
                    }
                }
                .buttonStyle(.plain)

                separator
            }

            if let fileName, !fileName.isEmpty {
                Text(fileName)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if let actionMessage, !actionMessage.isEmpty {
                separator
                Text(actionMessage)
                    .lineLimit(1)
                    .foregroundStyle(theme.chromePrimaryText)
            }

            ForEach(Array(metadataItems.enumerated()), id: \.offset) { _, item in
                separator
                Text(item)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            if let positionText {
                Text(positionText)
                    .foregroundStyle(theme.chromeSecondaryText)

                separator
            }

            Text(zoomText)
                .monospacedDigit()
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(theme.chromeSecondaryText)
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(isFullScreen ? theme.chromeBackgroundFullScreen : theme.chromeBackgroundWindowed)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(isFullScreen ? theme.chromeBorderFullScreen : theme.chromeBorderWindowed)
                .frame(height: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: isFullScreen ? 8 : 0, style: .continuous))
    }

    private var metadataItems: [String] {
        var items: [String] = []

        if let pixelSize {
            items.append("\(Int(pixelSize.width.rounded())) × \(Int(pixelSize.height.rounded())) px")
        }

        if let fileSize {
            items.append(Self.fileSizeFormatter.string(fromByteCount: fileSize))
        }

        if let format, !format.isEmpty {
            items.append(format)
        }

        return items
    }

    private var separator: some View {
        Text("•")
            .foregroundStyle(theme.chromeMutedText)
    }

    private func rateLabel(for rate: Double) -> String {
        let rounded = rate.rounded()
        if abs(rate - rounded) < 0.001 {
            return "\(Int(rounded))x"
        }

        return "\(rate.formatted(.number.precision(.fractionLength(1))))x"
    }

    private func intervalLabel(for interval: TimeInterval) -> String {
        let rounded = interval.rounded()
        if abs(interval - rounded) < 0.001 {
            return "\(Int(rounded)) seconds"
        }

        return "\(interval.formatted(.number.precision(.fractionLength(1)))) seconds"
    }

    private func aspectRatioLabel(for preset: CropAspectRatioPreset, selected: Bool) -> String {
        let title = preset.title
        return selected ? "✓ \(title)" : title
    }
}

struct StatusBarCropState {
    let aspectRatioPreset: CropAspectRatioPreset
    let selectionText: String?
    let canSaveInPlace: Bool
    let canSaveAs: Bool
    let onSelectAspectRatio: (CropAspectRatioPreset) -> Void
    let onSave: () -> Void
    let onSaveAs: () -> Void
    let onCancel: () -> Void
}

struct StatusBarSlideshowState {
    let isPlaying: Bool
    let intervalText: String
    let intervals: [TimeInterval]
    let onTogglePlayback: () -> Void
    let onPreviousSlide: () -> Void
    let onNextSlide: () -> Void
    let onSelectInterval: (TimeInterval) -> Void
}

struct StatusBarAnimationState {
    let isPlaying: Bool
    let frameText: String?
    let playbackRateText: String
    let playbackRates: [Double]
    let onTogglePlayback: () -> Void
    let onStepBackward: () -> Void
    let onStepForward: () -> Void
    let onSelectPlaybackRate: (Double) -> Void
}
