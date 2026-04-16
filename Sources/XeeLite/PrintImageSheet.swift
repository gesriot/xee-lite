import SwiftUI

struct PrintImageSheet: View {
    let imageURL: URL
    let pixelSize: CGSize
    let onPrint: (PrintScalingMode) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var scalingMode: PrintScalingMode = .fit

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Print Image")
                    .font(.title3.weight(.semibold))

                Text(imageURL.lastPathComponent)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("Image Size: \(Int(pixelSize.width.rounded())) × \(Int(pixelSize.height.rounded())) px")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Scaling")
                    .font(.headline)

                Picker("Scaling", selection: $scalingMode) {
                    ForEach(PrintScalingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(scalingMode.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Print…") {
                    performPrint()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func performPrint() {
        let selectedScalingMode = scalingMode
        dismiss()

        DispatchQueue.main.async {
            onPrint(selectedScalingMode)
        }
    }
}
