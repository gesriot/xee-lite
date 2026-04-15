import SwiftUI

struct FolderBrowserView: View {
    @EnvironmentObject private var viewerCoordinator: ViewerCoordinator
    @StateObject private var browserState = FolderBrowserState()
    @StateObject private var thumbnailState = ThumbnailStripState()

    private let gridSpacing: CGFloat = 16
    private let minimumCellWidth: CGFloat = 180

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .overlay(.white.opacity(0.08))

            content
        }
        .frame(minWidth: 860, minHeight: 600)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.96),
                    Color.black.opacity(0.88)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .foregroundStyle(.white)
        .onAppear {
            refreshBrowserData(using: viewerCoordinator.browserImageURLs)
        }
        .onChange(of: viewerCoordinator.browserImageURLs) { _, newURLs in
            refreshBrowserData(using: newURLs)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(currentFolderTitle)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)

                Text(summaryText)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer(minLength: 16)

            Picker("Sort", selection: $browserState.sortMode) {
                ForEach(FolderBrowserSortMode.allCases) { sortMode in
                    Text(sortMode.title).tag(sortMode)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 170)

            Picker("Format", selection: $browserState.formatFilter) {
                ForEach(browserState.availableFormatOptions) { option in
                    Text(option.title).tag(option.value)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 170)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.74))
    }

    @ViewBuilder
    private var content: some View {
        if viewerCoordinator.browserImageURLs.isEmpty {
            emptyState(
                title: "No Folder to Browse",
                message: "Open an image in the viewer to populate the folder browser."
            )
        } else if browserState.isLoading, browserState.allEntries.isEmpty {
            loadingState
        } else if browserState.visibleEntries.isEmpty {
            emptyState(
                title: "No Matching Images",
                message: "This folder has images, but none match the selected format filter."
            )
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: minimumCellWidth), spacing: gridSpacing)],
                    spacing: gridSpacing
                ) {
                    ForEach(browserState.visibleEntries) { entry in
                        FolderBrowserCellView(
                            entry: entry,
                            thumbnail: thumbnailState.thumbnail(for: entry.url),
                            isCurrentImage: entry.url.standardizedFileURL == viewerCoordinator.browserCurrentImageURL?.standardizedFileURL,
                            metadataText: metadataText(for: entry),
                            onOpen: {
                                viewerCoordinator.openImageInBrowserSourceViewer(at: entry.url)
                            }
                        )
                            .onAppear {
                                thumbnailState.requestThumbnail(for: entry.url, maxPixelSize: 420)
                            }
                    }
                }
                .padding(18)
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)

            Text("Loading Folder")
                .font(.title3.weight(.semibold))

            Text("Collecting file metadata and preparing thumbnails.")
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyState(title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))

            Text(message)
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func refreshBrowserData(using urls: [URL]) {
        browserState.updateFolder(urls: urls)
        thumbnailState.updateScope(urls: urls)
    }

    private var currentFolderTitle: String {
        let folderURL = viewerCoordinator.browserCurrentImageURL?.deletingLastPathComponent()
            ?? viewerCoordinator.browserImageURLs.first?.deletingLastPathComponent()

        return folderURL?.lastPathComponent ?? "Folder Browser"
    }

    private var summaryText: String {
        if viewerCoordinator.browserImageURLs.isEmpty {
            return "Open an image in the main viewer first."
        }

        let totalCount = browserState.allEntries.count
        let visibleCount = browserState.visibleEntries.count

        if browserState.isLoading, totalCount == 0 {
            return "Loading current folder…"
        }

        if browserState.formatFilter == FolderBrowserState.allFormatsFilterValue {
            return "\(visibleCount) image\(visibleCount == 1 ? "" : "s") in the current folder"
        }

        return "\(visibleCount) of \(totalCount) images shown"
    }

    private func metadataText(for entry: FolderBrowserEntry) -> String {
        var components = [entry.formatName]

        if let fileSize = entry.fileSize {
            components.append(Self.byteCountFormatter.string(fromByteCount: fileSize))
        }

        if let contentModificationDate = entry.contentModificationDate {
            components.append(contentModificationDate.formatted(date: .abbreviated, time: .omitted))
        }

        return components.joined(separator: " • ")
    }

    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter
    }()
}

private struct FolderBrowserCellView: View {
    let entry: FolderBrowserEntry
    let thumbnail: NSImage?
    let isCurrentImage: Bool
    let metadataText: String
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(isCurrentImage ? 0.10 : 0.04))

                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .padding(10)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(.white.opacity(0.36))
                }
            }
            .frame(height: 150)
            .overlay(alignment: .topTrailing) {
                if isCurrentImage {
                    Text("Current")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.94), in: Capsule())
                        .foregroundStyle(.black.opacity(0.86))
                        .padding(10)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.fileName)
                    .font(.system(size: 13, weight: isCurrentImage ? .semibold : .regular))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(metadataText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(isCurrentImage ? 0.08 : 0.02))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isCurrentImage ? .white.opacity(0.86) : .white.opacity(0.08),
                    lineWidth: isCurrentImage ? 2 : 1
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture(count: 2) {
            onOpen()
        }
        .help(entry.url.lastPathComponent)
    }
}
