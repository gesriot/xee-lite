import AppKit
import SwiftUI

struct MetadataInspectorView: View {
    let metadata: ImageMetadata
    let isFullScreen: Bool

    @State private var expandedSections = Set<String>()
    @State private var copiedItemID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Inspector")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if metadata.sections.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No metadata found")
                        .font(.system(size: 13, weight: .semibold))
                    Text("This image does not expose EXIF, IPTC, GPS, or XMP fields.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .foregroundStyle(.white.opacity(0.82))

                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(metadata.sections) { section in
                            DisclosureGroup(
                                isExpanded: binding(for: section.title),
                                content: {
                                    VStack(spacing: 1) {
                                        ForEach(Array(section.items.enumerated()), id: \.offset) { index, item in
                                            let rowID = identifier(for: section.title, index: index)

                                            MetadataRowView(
                                                item: item,
                                                isCopied: copiedItemID == rowID,
                                                onCopy: {
                                                    copy(item.value, for: rowID)
                                                }
                                            )
                                        }
                                    }
                                    .padding(.top, 8)
                                },
                                label: {
                                    Text(section.title)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.92))
                                }
                            )
                            .padding(12)
                            .background(.white.opacity(isFullScreen ? 0.05 : 0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .padding(12)
                }
                .scrollIndicators(.visible)
            }
        }
        .frame(width: 300)
        .background(backgroundColor)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(.white.opacity(isFullScreen ? 0.1 : 0.08))
                .frame(width: 1)
        }
        .onAppear {
            expandedSections = Set(metadata.sections.map(\.title))
        }
        .onChange(of: metadata) { _, newMetadata in
            let newTitles = Set(newMetadata.sections.map(\.title))
            expandedSections.formUnion(newTitles)
            expandedSections = expandedSections.intersection(newTitles)
        }
    }

    private var backgroundColor: Color {
        isFullScreen ? Color.black.opacity(0.5) : Color.black.opacity(0.72)
    }

    private func binding(for sectionTitle: String) -> Binding<Bool> {
        Binding(
            get: { expandedSections.contains(sectionTitle) },
            set: { isExpanded in
                if isExpanded {
                    expandedSections.insert(sectionTitle)
                } else {
                    expandedSections.remove(sectionTitle)
                }
            }
        )
    }

    private func copy(_ text: String, for itemID: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedItemID = itemID

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedItemID == itemID {
                copiedItemID = nil
            }
        }
    }

    private func identifier(for sectionTitle: String, index: Int) -> String {
        "\(sectionTitle)#\(index)"
    }
}

private struct MetadataRowView: View {
    let item: MetadataItem
    let isCopied: Bool
    let onCopy: () -> Void

    var body: some View {
        Button(action: onCopy) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(item.key)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 96, alignment: .leading)

                Text(item.value)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)

                Spacer(minLength: 0)

                if isCopied {
                    Text("Copied")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.green.opacity(0.95))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.white.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
