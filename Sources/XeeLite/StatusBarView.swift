import SwiftUI

struct StatusBarView: View {
    let fileName: String?
    let pixelSize: CGSize?
    let fileSize: Int64?
    let format: String?
    let positionText: String?
    let zoomText: String
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
            if let fileName, !fileName.isEmpty {
                Text(fileName)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            ForEach(Array(metadataItems.enumerated()), id: \.offset) { _, item in
                separator
                Text(item)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            if let positionText {
                Text(positionText)
                    .foregroundStyle(.white.opacity(0.74))

                separator
            }

            Text(zoomText)
                .monospacedDigit()
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.84))
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(isFullScreen ? Color.black.opacity(0.58) : Color.black.opacity(0.84))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(isFullScreen ? 0.10 : 0.08))
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
            .foregroundStyle(.white.opacity(0.34))
    }
}
