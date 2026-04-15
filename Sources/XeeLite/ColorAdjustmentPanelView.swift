import SwiftUI

struct ColorAdjustmentPanelView: View {
    @ObservedObject var colorAdjustmentState: ColorAdjustmentState
    let onPointerActivity: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Adjust Color")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer(minLength: 12)

                Button("Reset") {
                    colorAdjustmentState.reset()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(colorAdjustmentState.canReset ? 0.84 : 0.36))
                .disabled(!colorAdjustmentState.canReset)

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.82))
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
                .fill(.black.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)
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
                    .foregroundStyle(.white.opacity(0.86))

                Spacer(minLength: 12)

                Text(formattedValue)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
            }

            Slider(value: value, in: range)
                .tint(.white)
        }
    }
}
