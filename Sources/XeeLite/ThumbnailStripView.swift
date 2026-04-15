import SwiftUI

struct ThumbnailStripView: View {
    @ObservedObject var thumbnailStripState: ThumbnailStripState

    let imageURLs: [URL]
    let selectedIndex: Int
    let isFullScreen: Bool
    let onSelectIndex: (Int) -> Void
    let onPointerActivity: () -> Void

    private let thumbnailSize = CGSize(width: 76, height: 56)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(Array(imageURLs.enumerated()), id: \.element) { index, url in
                        Button {
                            onPointerActivity()
                            onSelectIndex(index)
                        } label: {
                            thumbnailCell(for: url, isSelected: index == selectedIndex)
                        }
                        .buttonStyle(.plain)
                        .id(thumbnailID(for: url))
                        .help(url.lastPathComponent)
                        .onAppear {
                            thumbnailStripState.requestThumbnail(for: url)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .frame(height: 88)
            .background(isFullScreen ? Color.black.opacity(0.58) : Color.black.opacity(0.84))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.white.opacity(isFullScreen ? 0.10 : 0.08))
                    .frame(height: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: isFullScreen ? 12 : 0, style: .continuous))
            .onAppear {
                scrollToCurrentThumbnail(with: proxy, animated: false)
            }
            .onChange(of: selectedIndex) { _, _ in
                scrollToCurrentThumbnail(with: proxy, animated: true)
            }
        }
    }

    @ViewBuilder
    private func thumbnailCell(for url: URL, isSelected: Bool) -> some View {
        let thumbnail = thumbnailStripState.thumbnail(for: url)

        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(isSelected ? 0.12 : 0.04))

            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: thumbnailSize.width - 10, height: thumbnailSize.height - 10)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.46))
            }
        }
        .frame(width: thumbnailSize.width, height: thumbnailSize.height)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    isSelected ? .white.opacity(0.94) : .white.opacity(0.10),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .overlay(alignment: .bottomTrailing) {
            if isSelected {
                Image(systemName: "eye.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.black.opacity(0.86))
                    .padding(5)
                    .background(.white.opacity(0.94), in: Circle())
                    .padding(6)
            }
        }
    }

    private func thumbnailID(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    private func scrollToCurrentThumbnail(with proxy: ScrollViewProxy, animated: Bool) {
        guard imageURLs.indices.contains(selectedIndex) else { return }
        let selectedID = thumbnailID(for: imageURLs[selectedIndex])

        let action = {
            proxy.scrollTo(selectedID, anchor: .center)
        }

        if animated {
            withAnimation(.easeOut(duration: 0.18)) {
                action()
            }
        } else {
            action()
        }
    }
}
