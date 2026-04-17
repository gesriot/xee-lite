import Foundation

struct ArchiveImageSource {
    struct Entry: Identifiable, Hashable {
        let archivePath: String
        let extractedURL: URL
        let fileSize: Int64?

        var id: String {
            archivePath
        }

        var fileName: String {
            URL(fileURLWithPath: archivePath).lastPathComponent
        }
    }

    let archiveURL: URL
    let extractedRootURL: URL
    let entries: [Entry]

    func entry(forExtractedURL url: URL?) -> Entry? {
        guard let url = url?.standardizedFileURL else { return nil }
        return entries.first(where: { $0.extractedURL.standardizedFileURL == url })
    }
}

enum ArchiveImageSourceLoader {
    private static let executableURL = URL(fileURLWithPath: "/usr/bin/bsdtar")
    private static let noPassphraseSentinel = "__xee_lite_no_passphrase__"
    private static let extractionDirectoryRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("XeeLite-Archives", isDirectory: true)
        .standardizedFileURL

    static func load(from archiveURL: URL, passphrase: String?) throws -> ArchiveImageSource {
        let standardizedArchiveURL = archiveURL.standardizedFileURL
        let archiveEntries = try listImageEntries(in: standardizedArchiveURL, passphrase: passphrase)

        guard !archiveEntries.isEmpty else {
            throw ArchiveImageSourceError.noImagesFound
        }

        try FileManager.default.createDirectory(
            at: extractionDirectoryRoot,
            withIntermediateDirectories: true
        )

        let extractedRootURL = extractionDirectoryRoot
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .standardizedFileURL

        try FileManager.default.createDirectory(
            at: extractedRootURL,
            withIntermediateDirectories: true
        )

        do {
            try extractEntries(
                archiveEntries,
                from: standardizedArchiveURL,
                into: extractedRootURL,
                passphrase: passphrase
            )
        } catch {
            try? FileManager.default.removeItem(at: extractedRootURL)
            throw error
        }

        let resolvedEntries = archiveEntries.compactMap { listedEntry -> ArchiveImageSource.Entry? in
            let extractedURL = extractedRootURL
                .appendingPathComponent(listedEntry.archivePath)
                .standardizedFileURL

            guard FileManager.default.fileExists(atPath: extractedURL.path) else { return nil }

            return ArchiveImageSource.Entry(
                archivePath: listedEntry.archivePath,
                extractedURL: extractedURL,
                fileSize: listedEntry.fileSize
            )
        }

        guard !resolvedEntries.isEmpty else {
            try? FileManager.default.removeItem(at: extractedRootURL)
            throw ArchiveImageSourceError.extractionFailed("No readable image files were extracted from the archive.")
        }

        return ArchiveImageSource(
            archiveURL: standardizedArchiveURL,
            extractedRootURL: extractedRootURL,
            entries: resolvedEntries
        )
    }

    static func cleanup(_ archiveImageSource: ArchiveImageSource?) {
        guard let extractedRootURL = archiveImageSource?.extractedRootURL else { return }
        try? FileManager.default.removeItem(at: extractedRootURL)
    }

    static func cleanupStaleExtractions() {
        guard FileManager.default.fileExists(atPath: extractionDirectoryRoot.path) else { return }
        try? FileManager.default.removeItem(at: extractionDirectoryRoot)
    }

    private static func listImageEntries(in archiveURL: URL, passphrase: String?) throws -> [ListedArchiveEntry] {
        let result = try runBSDTar(
            arguments: [
                "--passphrase", effectivePassphrase(from: passphrase),
                "-tf", archiveURL.path
            ],
            userPassphraseProvided: passphrase != nil
        )

        return result.stdout
            .split(whereSeparator: \.isNewline)
            .compactMap { String($0) }
            .compactMap(parseArchivePath(_:))
            .compactMap { archivePath in
                let fileName = URL(fileURLWithPath: archivePath).lastPathComponent
                let lowercasedExtension = URL(fileURLWithPath: fileName).pathExtension.lowercased()
                guard SupportedImageFormats.folderExtensions.contains(lowercasedExtension) else { return nil }

                return ListedArchiveEntry(
                    archivePath: archivePath,
                    fileSize: nil
                )
            }
    }

    private static func extractEntries(
        _ entries: [ListedArchiveEntry],
        from archiveURL: URL,
        into extractedRootURL: URL,
        passphrase: String?
    ) throws {
        let arguments = [
            "--passphrase", effectivePassphrase(from: passphrase),
            "-xf", archiveURL.path,
            "-C", extractedRootURL.path,
            "--"
        ] + entries.map(\.archivePath)

        _ = try runBSDTar(arguments: arguments, userPassphraseProvided: passphrase != nil)
    }

    private static func parseArchivePath(_ rawPath: String) -> String? {
        let trimmedPath = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return nil }

        var normalizedPath = trimmedPath.replacingOccurrences(of: "\\", with: "/")
        while normalizedPath.hasPrefix("./") {
            normalizedPath.removeFirst(2)
        }

        guard !normalizedPath.isEmpty else { return nil }
        guard !normalizedPath.hasSuffix("/") else { return nil }
        guard !normalizedPath.hasPrefix("/") else { return nil }
        guard !normalizedPath.hasPrefix("__MACOSX/") else { return nil }

        let components = normalizedPath.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.contains("..") else { return nil }

        return normalizedPath
    }

    private static func runBSDTar(
        arguments: [String],
        userPassphraseProvided: Bool
    ) throws -> CommandResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw ArchiveImageSourceError.unavailable(error.localizedDescription)
        }

        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(decoding: stdoutData, as: UTF8.self)
        let stderr = String(decoding: stderrData, as: UTF8.self)

        guard process.terminationStatus == 0 else {
            throw archiveError(
                stdout: stdout,
                stderr: stderr,
                userPassphraseProvided: userPassphraseProvided
            )
        }

        return CommandResult(stdout: stdout, stderr: stderr)
    }

    private static func archiveError(
        stdout: String,
        stderr: String,
        userPassphraseProvided: Bool
    ) -> ArchiveImageSourceError {
        let combinedMessage = [stderr, stdout]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let lowercasedMessage = combinedMessage.lowercased()

        if lowercasedMessage.contains("incorrect passphrase")
            || lowercasedMessage.contains("too many incorrect passphrases")
            || lowercasedMessage.contains("passphrase required")
            || lowercasedMessage.contains("password required")
        {
            return userPassphraseProvided ? .incorrectPassword : .passwordRequired
        }

        if lowercasedMessage.contains("encrypted data is not currently supported")
            || lowercasedMessage.contains("encryption is not supported")
        {
            return .unsupportedEncryption
        }

        if lowercasedMessage.contains("unrecognized archive format")
            || lowercasedMessage.contains("error opening archive")
        {
            return .unsupportedArchive(combinedMessage)
        }

        return .extractionFailed(combinedMessage.isEmpty ? "The archive could not be read." : combinedMessage)
    }

    private static func effectivePassphrase(from passphrase: String?) -> String {
        guard let passphrase, !passphrase.isEmpty else { return noPassphraseSentinel }
        return passphrase
    }
}

private struct ListedArchiveEntry {
    let archivePath: String
    let fileSize: Int64?
}

private struct CommandResult {
    let stdout: String
    let stderr: String
}

enum ArchiveImageSourceError: LocalizedError {
    case unavailable(String)
    case unsupportedArchive(String)
    case noImagesFound
    case passwordRequired
    case incorrectPassword
    case unsupportedEncryption
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case let .unavailable(message):
            return "The built-in archive reader could not start: \(message)"
        case let .unsupportedArchive(message):
            return "This archive format couldn't be opened: \(message)"
        case .noImagesFound:
            return "The archive doesn't contain any supported image files."
        case .passwordRequired:
            return "This archive is password-protected."
        case .incorrectPassword:
            return "The archive password was incorrect."
        case .unsupportedEncryption:
            return "This archive uses encryption that the built-in archive reader can't extract."
        case let .extractionFailed(message):
            return "The archive couldn't be extracted: \(message)"
        }
    }
}
