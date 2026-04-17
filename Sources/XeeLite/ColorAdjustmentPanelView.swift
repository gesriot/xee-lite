import SwiftUI

struct ColorAdjustmentPanelView: View {
    @Environment(\.xeeThemePalette) private var theme
    @ObservedObject var colorAdjustmentState: ColorAdjustmentState
    let onPointerActivity: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Adjust Color")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.floatingPanelPrimaryText)

                Spacer(minLength: 12)

                Button("Reset") {
                    colorAdjustmentState.reset()
                }
                .buttonStyle(.plain)
                .foregroundStyle(colorAdjustmentState.canReset ? theme.floatingPanelSecondaryText : theme.floatingPanelMutedText)
                .disabled(!colorAdjustmentState.canReset)

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.floatingPanelSecondaryText)
                }
                .buttonStyle(.plain)
            }

            adjustmentSlider(
                title: "Brightness",
                value: brightnessBinding,
                range: -1...1,
                formattedValue: colorAdjustmentState.brightness.formatted(.number.precision(.fractionLength(2)))
            )

            adjustmentSlider(
                title: "Contrast",
                value: contrastBinding,
                range: 0.5...2,
                formattedValue: colorAdjustmentState.contrast.formatted(.number.precision(.fractionLength(2)))
            )

            adjustmentSlider(
                title: "Gamma",
                value: gammaBinding,
                range: 0.25...3,
                formattedValue: colorAdjustmentState.gamma.formatted(.number.precision(.fractionLength(2)))
            )
        }
        .padding(16)
        .frame(width: 272)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.floatingPanelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.floatingPanelBorder, lineWidth: 1)
        )
        .shadow(color: theme.floatingPanelShadow, radius: 18, x: 0, y: 10)
        .onHover { hovering in
            if hovering {
                onPointerActivity()
            }
        }
    }

    private var brightnessBinding: Binding<Double> {
        Binding(
            get: { colorAdjustmentState.brightness },
            set: { colorAdjustmentState.brightness = $0 }
        )
    }

    private var contrastBinding: Binding<Double> {
        Binding(
            get: { colorAdjustmentState.contrast },
            set: { colorAdjustmentState.contrast = $0 }
        )
    }

    private var gammaBinding: Binding<Double> {
        Binding(
            get: { colorAdjustmentState.gamma },
            set: { colorAdjustmentState.gamma = $0 }
        )
    }

    @ViewBuilder
    private func adjustmentSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        formattedValue: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.floatingPanelSecondaryText)

                Spacer(minLength: 12)

                Text(formattedValue)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.floatingPanelMutedText)
            }

            Slider(value: value, in: range)
                .tint(theme.floatingPanelTint)
        }
    }
}
