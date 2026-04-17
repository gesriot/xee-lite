import AppKit
import SwiftUI

struct MetadataInspectorView: View {
    @Environment(\.xeeThemePalette) private var theme
    let metadata: ImageMetadata
    let isFullScreen: Bool

    @State private var expandedSections = Set<String>()
    @State private var copiedItemID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Inspector")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.inspectorPrimaryText)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if metadata.sections.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No metadata found")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.inspectorPrimaryText)
                    Text("This image does not expose EXIF, IPTC, GPS, or XMP fields.")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.inspectorSecondaryText)
                }
                .padding(14)

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
                                        .foregroundStyle(theme.inspectorPrimaryText)
                                }
                            )
                            .padding(12)
                            .background(isFullScreen ? theme.inspectorSectionBackgroundFullScreen : theme.inspectorSectionBackgroundWindowed)
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
                .fill(isFullScreen ? theme.inspectorBorderFullScreen : theme.inspectorBorderWindowed)
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
        isFullScreen ? theme.inspectorBackgroundFullScreen : theme.inspectorBackgroundWindowed
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
    @Environment(\.xeeThemePalette) private var theme
    let item: MetadataItem
    let isCopied: Bool
    let onCopy: () -> Void

    var body: some View {
        Button(action: onCopy) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(item.key)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.inspectorMutedText)
                    .frame(width: 96, alignment: .leading)

                Text(item.value)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.inspectorSecondaryText)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)

                Spacer(minLength: 0)

                if isCopied {
                    Text("Copied")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.inspectorCopiedText)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(theme.inspectorRowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
