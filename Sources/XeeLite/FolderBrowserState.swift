import Foundation

struct FolderBrowserEntry: Identifiable, Hashable {
    let url: URL
    let fileName: String
    let fileSize: Int64?
    let contentModificationDate: Date?
    let pathExtension: String
    let formatName: String

    var id: String {
        url.standardizedFileURL.path
    }
}

struct FolderBrowserFormatOption: Identifiable, Hashable {
    let value: String
    let title: String

    var id: String {
        value
    }
}

enum FolderBrowserSortMode: String, CaseIterable, Identifiable {
    case name
    case modificationDate
    case fileSize

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .name:
            return "Name"
        case .modificationDate:
            return "Date Modified"
        case .fileSize:
            return "File Size"
        }
    }
}

@MainActor
final class FolderBrowserState: ObservableObject {
    nonisolated static let allFormatsFilterValue = "__all_formats__"

    @Published private(set) var allEntries: [FolderBrowserEntry] = [] {
        didSet {
            recomputeDerivedState()
        }
    }
    @Published private(set) var visibleEntries: [FolderBrowserEntry] = []
    @Published private(set) var availableFormatOptions: [FolderBrowserFormatOption] = [
        FolderBrowserFormatOption(
            value: FolderBrowserState.allFormatsFilterValue,
            title: "All Formats"
        )
    ]
    @Published var sortMode: FolderBrowserSortMode = .name {
        didSet {
            recomputeVisibleEntries()
        }
    }
    @Published var formatFilter: String = FolderBrowserState.allFormatsFilterValue {
        didSet {
            recomputeVisibleEntries()
        }
    }
    @Published private(set) var isLoading = false

    private var loadTask: Task<Void, Never>?

    func updateFolder(urls: [URL]) {
        loadTask?.cancel()

        let standardizedURLs = urls.map(\.standardizedFileURL)
        guard !standardizedURLs.isEmpty else {
            allEntries = []
            isLoading = false
            formatFilter = Self.allFormatsFilterValue
            return
        }

        isLoading = true

        loadTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }

            let entries = await Task.detached(priority: .utility) {
                Self.loadEntries(for: standardizedURLs)
            }.value

            guard !Task.isCancelled else { return }

            self.allEntries = entries
            self.isLoading = false

            if self.formatFilter != Self.allFormatsFilterValue,
               !entries.contains(where: { $0.pathExtension == self.formatFilter }) {
                self.formatFilter = Self.allFormatsFilterValue
            }
        }
    }

    deinit {
        loadTask?.cancel()
    }

    private func recomputeDerivedState() {
        availableFormatOptions = Self.makeFormatOptions(from: allEntries)
        recomputeVisibleEntries()
    }

    private func recomputeVisibleEntries() {
        let filteredEntries: [FolderBrowserEntry]
        if formatFilter == Self.allFormatsFilterValue {
            filteredEntries = allEntries
        } else {
            filteredEntries = allEntries.filter { $0.pathExtension == formatFilter }
        }

        visibleEntries = filteredEntries.sorted(by: compareEntries(_:_:))
    }

    private func compareEntries(_ lhs: FolderBrowserEntry, _ rhs: FolderBrowserEntry) -> Bool {
        switch sortMode {
        case .name:
            return compareNames(lhs, rhs)
        case .modificationDate:
            return compareDescending(lhs.contentModificationDate, rhs.contentModificationDate, lhs: lhs, rhs: rhs)
        case .fileSize:
            return compareDescending(lhs.fileSize, rhs.fileSize, lhs: lhs, rhs: rhs)
        }
    }

    private func compareNames(_ lhs: FolderBrowserEntry, _ rhs: FolderBrowserEntry) -> Bool {
        let comparison = lhs.fileName.localizedStandardCompare(rhs.fileName)
        if comparison == .orderedSame {
            return lhs.url.standardizedFileURL.path < rhs.url.standardizedFileURL.path
        }

        return comparison == .orderedAscending
    }

    private func compareDescending<T: Comparable>(
        _ lhsValue: T?,
        _ rhsValue: T?,
        lhs: FolderBrowserEntry,
        rhs: FolderBrowserEntry
    ) -> Bool {
        switch (lhsValue, rhsValue) {
        case let (lhsValue?, rhsValue?) where lhsValue != rhsValue:
            return lhsValue > rhsValue
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        default:
            return compareNames(lhs, rhs)
        }
    }

    nonisolated private static func loadEntries(for urls: [URL]) -> [FolderBrowserEntry] {
        urls.map(loadEntry(for:))
    }

    nonisolated private static func loadEntry(for url: URL) -> FolderBrowserEntry {
        let resourceValues = try? url.resourceValues(forKeys: [
            .contentModificationDateKey,
            .fileSizeKey
        ])

        let pathExtension = url.pathExtension.lowercased()

        return FolderBrowserEntry(
            url: url,
            fileName: url.lastPathComponent,
            fileSize: resourceValues?.fileSize.map(Int64.init),
            contentModificationDate: resourceValues?.contentModificationDate,
            pathExtension: pathExtension,
            formatName: formatDisplayName(for: pathExtension)
        )
    }

    nonisolated private static func makeFormatOptions(
        from entries: [FolderBrowserEntry]
    ) -> [FolderBrowserFormatOption] {
        let extensions = Set(entries.map(\.pathExtension).filter { !$0.isEmpty })
        let sortedExtensions = extensions.sorted {
            formatDisplayName(for: $0).localizedStandardCompare(
                formatDisplayName(for: $1)
            ) == .orderedAscending
        }

        return [
            FolderBrowserFormatOption(
                value: Self.allFormatsFilterValue,
                title: "All Formats"
            )
        ] + sortedExtensions.map {
            FolderBrowserFormatOption(
                value: $0,
                title: formatDisplayName(for: $0)
            )
        }
    }

    nonisolated private static func formatDisplayName(for pathExtension: String) -> String {
        SupportedImageFormats.displayName(for: pathExtension) ?? pathExtension.uppercased()
    }
}
