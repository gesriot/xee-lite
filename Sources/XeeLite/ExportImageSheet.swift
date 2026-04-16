import SwiftUI

struct ExportImageSheet: View {
    let imageURL: URL
    let sourcePixelSize: CGSize
    let isAnimatedSource: Bool
    let onExport: (ImageExportOptions) throws -> URL

    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: ImageExportFormat
    @State private var widthText: String
    @State private var heightText: String
    @State private var preservesAspectRatio = true
    @State private var compressionQuality = 0.9
    @State private var errorMessage: String?
    @State private var isSynchronizingDimensions = false

    init(
        imageURL: URL,
        sourcePixelSize: CGSize,
        isAnimatedSource: Bool,
        onExport: @escaping (ImageExportOptions) throws -> URL
    ) {
        self.imageURL = imageURL
        self.sourcePixelSize = sourcePixelSize
        self.isAnimatedSource = isAnimatedSource
        self.onExport = onExport

        let defaultFormat = ImageExportFormat.defaultFormat(
            for: imageURL,
            isAnimatedSource: isAnimatedSource
        )
        let roundedWidth = max(Int(sourcePixelSize.width.rounded()), 1)
        let roundedHeight = max(Int(sourcePixelSize.height.rounded()), 1)

        _selectedFormat = State(initialValue: defaultFormat)
        _widthText = State(initialValue: String(roundedWidth))
        _heightText = State(initialValue: String(roundedHeight))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Export Image")
                    .font(.title3.weight(.semibold))

                Text(imageURL.lastPathComponent)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("Original: \(sourceSizeText)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if isAnimatedSource {
                Text("Animated images are exported as the currently visible frame.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Picker("Format", selection: $selectedFormat) {
                    ForEach(ImageExportFormat.availableCases) { format in
                        Text(format.title).tag(format)
                    }
                }

                Toggle("Preserve Aspect Ratio", isOn: $preservesAspectRatio)
                    .toggleStyle(.checkbox)
                    .onChange(of: preservesAspectRatio) { _, isEnabled in
                        guard isEnabled else { return }
                        synchronizeHeightFromWidth()
                    }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Width")
                            .foregroundStyle(.secondary)

                        TextField("Width", text: $widthText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 110)
                            .onChange(of: widthText) { _, _ in
                                synchronizeHeightFromWidth()
                            }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Height")
                            .foregroundStyle(.secondary)

                        TextField("Height", text: $heightText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 110)
                            .onChange(of: heightText) { _, _ in
                                synchronizeWidthFromHeight()
                            }
                    }

                    Button("Original Size") {
                        resetDimensions()
                    }
                    .padding(.top, 22)
                }

                if selectedFormat.supportsCompressionQuality {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Quality")
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text("\(Int((compressionQuality * 100).rounded()))%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $compressionQuality, in: 0.1...1.0)
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Export…") {
                    exportImage()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canExport)
            }
        }
        .padding(20)
        .frame(width: 430)
    }

    private var canExport: Bool {
        parsedWidth != nil && parsedHeight != nil && !ImageExportFormat.availableCases.isEmpty
    }

    private var parsedWidth: Int? {
        parsedDimension(from: widthText)
    }

    private var parsedHeight: Int? {
        parsedDimension(from: heightText)
    }

    private var sourceAspectRatio: CGFloat? {
        guard sourcePixelSize.width > 0, sourcePixelSize.height > 0 else { return nil }
        return sourcePixelSize.width / sourcePixelSize.height
    }

    private var sourceSizeText: String {
        "\(Int(sourcePixelSize.width.rounded())) × \(Int(sourcePixelSize.height.rounded())) px"
    }

    private func parsedDimension(from text: String) -> Int? {
        guard let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 else {
            return nil
        }

        return value
    }

    private func resetDimensions() {
        let width = max(Int(sourcePixelSize.width.rounded()), 1)
        let height = max(Int(sourcePixelSize.height.rounded()), 1)
        widthText = String(width)
        heightText = String(height)
    }

    private func synchronizeHeightFromWidth() {
        guard preservesAspectRatio, !isSynchronizingDimensions else { return }
        guard let width = parsedWidth, let aspectRatio = sourceAspectRatio else { return }

        isSynchronizingDimensions = true
        let resolvedHeight = max(Int((CGFloat(width) / aspectRatio).rounded()), 1)
        heightText = String(resolvedHeight)
        isSynchronizingDimensions = false
    }

    private func synchronizeWidthFromHeight() {
        guard preservesAspectRatio, !isSynchronizingDimensions else { return }
        guard let height = parsedHeight, let aspectRatio = sourceAspectRatio else { return }

        isSynchronizingDimensions = true
        let resolvedWidth = max(Int((CGFloat(height) * aspectRatio).rounded()), 1)
        widthText = String(resolvedWidth)
        isSynchronizingDimensions = false
    }

    private func exportImage() {
        guard let width = parsedWidth, let height = parsedHeight else {
            errorMessage = ImageExportError.invalidDimensions.localizedDescription
            return
        }

        do {
            _ = try onExport(
                ImageExportOptions(
                    format: selectedFormat,
                    pixelSize: CGSize(width: width, height: height),
                    compressionQuality: compressionQuality
                )
            )
            dismiss()
        } catch ImageExportError.cancelled {
            errorMessage = nil
        } catch let error as LocalizedError {
            errorMessage = error.errorDescription ?? error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
