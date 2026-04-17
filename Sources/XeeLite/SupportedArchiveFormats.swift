import Foundation

enum SupportedArchiveFormats {
    private static let suffixDisplayNames: [(suffix: String, displayName: String)] = [
        (".tar.gz", "TAR.GZ"),
        (".tar.bz2", "TAR.BZ2"),
        (".tar.xz", "TAR.XZ"),
        (".tgz", "TAR.GZ"),
        (".tbz2", "TAR.BZ2"),
        (".tbz", "TAR.BZ2"),
        (".txz", "TAR.XZ"),
        (".cbz", "CBZ"),
        (".cbr", "CBR"),
        (".cb7", "CB7"),
        (".cbt", "CBT"),
        (".zip", "ZIP"),
        (".rar", "RAR"),
        (".7z", "7-Zip"),
        (".tar", "TAR")
    ]

    static func contains(_ url: URL) -> Bool {
        displayName(for: url) != nil
    }

    static func displayName(for url: URL) -> String? {
        let fileName = url.lastPathComponent.lowercased()
        return suffixDisplayNames.first(where: { fileName.hasSuffix($0.suffix) })?.displayName
    }
}
