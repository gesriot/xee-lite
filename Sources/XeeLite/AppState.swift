import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    private static let clipboardImportDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("XeeLite-Clipboard", isDirectory: true)
        .standardizedFileURL
    private static var didConsumeLaunchImageArgument = false

    @Published private(set) var imageURLs: [URL] = []
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var currentImage: NSImage?
    @Published private(set) var currentImageURL: URL?
    @Published private(set) var currentImagePixelSize: CGSize?
    @Published private(set) var currentImageFileSize: Int64?
    @Published private(set) var currentImageFinderLabel: FinderLabel?
    @Published private(set) var currentMetadata = ImageMetadata(sections: [])
    @Published private(set) var currentAnimatedImage: AnimatedImage?
    @Published private(set) var currentArchiveSource: ArchiveImageSource?
    @Published private(set) var currentImageContentVersion: UInt64 = 0
    @Published private(set) var renameRequestID: UInt64 = 0
    @Published private(set) var manageDestinationsRequestID: UInt64 = 0
    @Published private(set) var deleteRequestID: UInt64 = 0
    @Published private(set) var exportRequestID: UInt64 = 0
    @Published private(set) var printRequestID: UInt64 = 0
    @Published private(set) var copyImageRequestID: UInt64 = 0
    @Published private(set) var fileActionDestinations: [FileActionDestination]
    @Published private(set) var fileActionMessage: String?
    @Published var activeAlert: FileActionAlertState?

    private weak var viewerWindow: NSWindow?
    private var fileActionMessageDismissWorkItem: DispatchWorkItem?
    private let fileSystemWatcherQueue = DispatchQueue(label: "XeeLite.FileSystemWatcher.Events", qos: .utility)
    private var folderWatcher: FileSystemWatcher?
    private var currentFileWatcher: FileSystemWatcher?
    private var watchedFolderURL: URL?
    private var watchedFileURL: URL?
    private var fileSystemRefreshWorkItem: DispatchWorkItem?
    private var isFolderScopedObservationEnabled = false
    private var currentImageFileIdentity: NSObject?
    private var userDefaultsDidChangeCancellable: AnyCancellable?

    var isViewingArchive: Bool {
        currentArchiveSource != nil
    }

    init() {
        fileActionDestinations = AppPreferences.loadFileActionDestinations()

        userDefaultsDidChangeCancellable = NotificationCenter.default.publisher(
            for: UserDefaults.didChangeNotification,
            object: UserDefaults.standard
        )
        .sink { [weak self] _ in
            self?.reloadFileActionDestinationsFromDefaults()
        }
    }

    func openImagePicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = []

        if panel.runModal() == .OK, let url = panel.url {
            loadImage(at: url)
        }
    }

    func loadInitialImage() {
        guard currentImageURL == nil, imageURLs.isEmpty else { return }

        if let path = Self.consumeLaunchImageArgument() {
            loadImage(at: URL(fileURLWithPath: path))
            return
        }

        openImagePicker()
    }

    func loadImage(at url: URL) {
        let standardizedURL = url.standardizedFileURL

        if SupportedArchiveFormats.contains(standardizedURL) {
            openArchive(at: standardizedURL)
            return
        }

        replaceArchiveSource(with: nil)
        let folderURL = standardizedURL.deletingLastPathComponent()

        do {
            let images = try scanImageURLs(in: folderURL)

            guard !images.isEmpty else {
                setSingleImage(url: standardizedURL)
                return
            }

            isFolderScopedObservationEnabled = true
            imageURLs = images
            currentIndex = images.firstIndex(of: standardizedURL) ?? 0
            updateDisplayedImage()
        } catch {
            imageURLs = []
            currentIndex = 0
            setSingleImage(url: standardizedURL, error: error)
        }
    }

    func showPreviousImage(wrapping: Bool = false) {
        stepImage(by: -1, wrapping: wrapping)
    }

    func showNextImage(wrapping: Bool = false) {
        stepImage(by: 1, wrapping: wrapping)
    }

    func showFirstImage() {
        guard !imageURLs.isEmpty, currentIndex != 0 else { return }
        currentIndex = 0
        updateDisplayedImage()
    }

    func showLastImage() {
        guard let lastIndex = imageURLs.indices.last, currentIndex != lastIndex else { return }
        currentIndex = lastIndex
        updateDisplayedImage()
    }

    func showImage(at index: Int) {
        guard imageURLs.indices.contains(index), currentIndex != index else { return }
        currentIndex = index
        updateDisplayedImage()
    }

    func jumpImages(by delta: Int) {
        guard !imageURLs.isEmpty, delta != 0 else { return }

        let nextIndex = min(max(currentIndex + delta, 0), imageURLs.count - 1)
        guard nextIndex != currentIndex else { return }

        currentIndex = nextIndex
        updateDisplayedImage()
    }

    private func stepImage(by delta: Int, wrapping: Bool) {
        guard !imageURLs.isEmpty, delta != 0 else { return }

        if wrapping {
            let imageCount = imageURLs.count
            guard imageCount > 1 else { return }

            let nextIndex = ((currentIndex + delta) % imageCount + imageCount) % imageCount
            guard nextIndex != currentIndex else { return }

            currentIndex = nextIndex
            updateDisplayedImage()
            return
        }

        let nextIndex = currentIndex + delta
        guard imageURLs.indices.contains(nextIndex) else { return }

        currentIndex = nextIndex
        updateDisplayedImage()
    }

    var canShowPrevious: Bool {
        currentIndex > 0
    }

    var canShowNext: Bool {
        currentIndex + 1 < imageURLs.count
    }

    var canRenameCurrentImage: Bool {
        currentImageURL != nil && !isViewingArchive
    }

    var canTransferCurrentImage: Bool {
        currentImageURL != nil && !isViewingArchive
    }

    var canDeleteCurrentImage: Bool {
        currentImageURL != nil && !isViewingArchive
    }

    var canSetFinderLabel: Bool {
        currentImageURL != nil && !isViewingArchive
    }

    var canRunSlideshow: Bool {
        currentImageURL != nil && imageURLs.count > 1
    }

    var canCropCurrentImage: Bool {
        currentImageURL != nil && currentImagePixelSize != nil && !isViewingArchive
    }

    var canExportCurrentImage: Bool {
        currentImage != nil && currentImageURL != nil && currentImagePixelSize != nil
    }

    var canPrintCurrentImage: Bool {
        currentImage != nil && currentImageURL != nil && currentImagePixelSize != nil
    }

    var canCopyCurrentImage: Bool {
        currentImage != nil
    }

    var canSetDesktopPicture: Bool {
        guard let currentImageURL else { return false }
        return !isViewingArchive && !isTemporaryClipboardImageURL(currentImageURL)
    }

    var currentImagePositionText: String? {
        guard imageURLs.indices.contains(currentIndex) else { return nil }
        return "\(currentIndex + 1)/\(imageURLs.count)"
    }

    var currentImageFormatText: String? {
        guard let pathExtension = currentImageURL?.pathExtension.lowercased(), !pathExtension.isEmpty else { return nil }
        return SupportedImageFormats.displayName(for: pathExtension)
    }

    var currentImageDisplayName: String? {
        currentArchiveSource?.entry(forExtractedURL: currentImageURL)?.fileName ?? currentImageURL?.lastPathComponent
    }

    func requestRenameCurrentImage() {
        guard canRenameCurrentImage else { return }
        renameRequestID &+= 1
    }

    func requestManageDestinations() {
        manageDestinationsRequestID &+= 1
    }

    func requestDeleteCurrentImage() {
        guard canDeleteCurrentImage else { return }
        deleteRequestID &+= 1
    }

    func requestExportCurrentImage() {
        guard canExportCurrentImage else { return }
        exportRequestID &+= 1
    }

    func requestPrintCurrentImage() {
        guard canPrintCurrentImage else { return }
        printRequestID &+= 1
    }

    func requestCopyCurrentImage() {
        guard canCopyCurrentImage else { return }
        copyImageRequestID &+= 1
    }

    func setCurrentImageAsDesktopPicture() {
        guard let currentImageURL = currentImageURL?.standardizedFileURL else {
            presentAlert(
                title: "Set Desktop Picture Failed",
                message: FileTransferError.noImage.localizedDescription
            )
            return
        }

        guard !isViewingArchive else {
            presentAlert(
                title: "Set Desktop Picture Failed",
                message: DesktopPictureError.archiveImage.localizedDescription
            )
            return
        }

        guard !isTemporaryClipboardImageURL(currentImageURL) else {
            presentAlert(
                title: "Set Desktop Picture Failed",
                message: DesktopPictureError.temporaryClipboardImage.localizedDescription
            )
            return
        }

        guard let screen = currentDesktopPictureScreen() else {
            presentAlert(
                title: "Set Desktop Picture Failed",
                message: DesktopPictureError.noScreen.localizedDescription
            )
            return
        }

        do {
            let options = NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
            try NSWorkspace.shared.setDesktopImageURL(currentImageURL, for: screen, options: options)
            presentFileActionMessage("Set as Desktop Picture")
        } catch {
            presentAlert(
                title: "Set Desktop Picture Failed",
                message: error.localizedDescription
            )
        }
    }

    func showArchiveEntry(at extractedURL: URL) {
        let standardizedURL = extractedURL.standardizedFileURL

        if let archiveIndex = currentArchiveSource?.entries.firstIndex(where: {
            $0.extractedURL.standardizedFileURL == standardizedURL
        }) {
            showImage(at: archiveIndex)
            return
        }

        openImageInViewer(at: standardizedURL)
    }

    func pasteImageFromClipboard() {
        switch ClipboardImageTransfer.readFromPasteboard() {
        case let .success(source):
            importImageSource(
                source,
                successMessage: "Opened image from clipboard",
                failureTitle: "Paste Failed"
            )
        case let .failure(error as LocalizedError):
            if let description = error.errorDescription {
                presentAlert(title: "Paste Failed", message: description)
            }
        case let .failure(error):
            presentAlert(title: "Paste Failed", message: error.localizedDescription)
        }
    }

    func importImageSource(
        _ source: ImportedImageSource,
        successMessage: String,
        failureTitle: String
    ) {
        do {
            switch source {
            case let .fileURL(url):
                loadImage(at: url)
            case let .bitmap(image):
                let temporaryURL = try writeTemporaryImportedImage(image)
                setSingleImage(url: temporaryURL)
            }

            presentFileActionMessage(successMessage)
        } catch let error as LocalizedError {
            if let description = error.errorDescription {
                presentAlert(title: failureTitle, message: description)
            }
        } catch {
            presentAlert(title: failureTitle, message: error.localizedDescription)
        }
    }

    private func openArchive(at archiveURL: URL) {
        do {
            let archiveSource = try ArchiveImageSourceLoader.load(from: archiveURL, passphrase: nil)
            installArchiveSource(archiveSource)
        } catch let error as ArchiveImageSourceError {
            switch error {
            case .passwordRequired:
                promptToOpenArchive(at: archiveURL, invalidPassword: false)
            default:
                if let description = error.errorDescription {
                    presentAlert(title: "Open Archive Failed", message: description)
                }
            }
        } catch {
            presentAlert(title: "Open Archive Failed", message: error.localizedDescription)
        }
    }

    private func promptToOpenArchive(at archiveURL: URL, invalidPassword: Bool) {
        var showsInvalidPasswordState = invalidPassword

        while let passphrase = promptArchivePassphrase(for: archiveURL, invalidPassword: showsInvalidPasswordState) {
            do {
                let archiveSource = try ArchiveImageSourceLoader.load(from: archiveURL, passphrase: passphrase)
                installArchiveSource(archiveSource)
                return
            } catch let error as ArchiveImageSourceError {
                switch error {
                case .incorrectPassword, .passwordRequired:
                    showsInvalidPasswordState = true
                    continue
                default:
                    if let description = error.errorDescription {
                        presentAlert(title: "Open Archive Failed", message: description)
                    }
                    return
                }
            } catch {
                presentAlert(title: "Open Archive Failed", message: error.localizedDescription)
                return
            }
        }
    }

    func setFileActionDestination(_ folderURL: URL, forSlot slotNumber: Int) {
        guard (1...9).contains(slotNumber) else { return }
        updateFileActionDestination(
            forSlot: slotNumber,
            path: folderURL.standardizedFileURL.path
        )
    }

    func clearFileActionDestination(forSlot slotNumber: Int) {
        guard (1...9).contains(slotNumber) else { return }
        updateFileActionDestination(forSlot: slotNumber, path: nil)
    }

    func copyCurrentImage(toDestinationSlot slotNumber: Int) {
        performCurrentImageTransfer(.copy, toDestinationSlot: slotNumber)
    }

    func moveCurrentImage(toDestinationSlot slotNumber: Int) {
        performCurrentImageTransfer(.move, toDestinationSlot: slotNumber)
    }

    func trashCurrentImage() {
        guard canDeleteCurrentImage else { return }

        guard let currentImageURL else {
            presentAlert(
                title: "Move to Trash Failed",
                message: FileTransferError.noImage.localizedDescription
            )
            return
        }

        trashImage(at: currentImageURL)
    }

    func setFinderLabel(_ label: FinderLabel) {
        guard canSetFinderLabel else { return }

        guard let currentImageURL = currentImageURL?.standardizedFileURL else {
            presentAlert(
                title: "Set Finder Label Failed",
                message: FileTransferError.noImage.localizedDescription
            )
            return
        }

        do {
            var resourceValues = URLResourceValues()
            resourceValues.labelNumber = label.rawValue
            var mutableURL = currentImageURL
            try mutableURL.setResourceValues(resourceValues)
            currentImageFinderLabel = label
            presentFileActionMessage(label.appliedStatusMessage)
        } catch {
            presentAlert(
                title: "Set Finder Label Failed",
                message: error.localizedDescription
            )
        }
    }

    func renameValidationMessage(forBaseName baseName: String) -> String? {
        guard let currentImageURL else {
            return RenameImageError.noImage.localizedDescription
        }

        return renameValidationMessage(forBaseName: baseName, imageURL: currentImageURL)
    }

    func renameValidationMessage(forBaseName baseName: String, imageURL: URL) -> String? {
        do {
            _ = try renamedImageURL(forBaseName: baseName, from: imageURL)
            return nil
        } catch let error as RenameImageError {
            return error.localizedDescription
        } catch {
            return error.localizedDescription
        }
    }

    func showErrorAlert(title: String, message: String) {
        presentAlert(title: title, message: message)
    }

    func showFileActionMessage(_ message: String) {
        presentFileActionMessage(message)
    }

    func registerViewerWindow(_ window: NSWindow) {
        viewerWindow = window
    }

    func viewerWillClose() {
        fileActionMessageDismissWorkItem?.cancel()
        fileSystemRefreshWorkItem?.cancel()
        folderWatcher = nil
        currentFileWatcher = nil
        watchedFolderURL = nil
        watchedFileURL = nil
        replaceArchiveSource(with: nil)
    }

    func openImageInViewer(at url: URL) {
        loadImage(at: url)
        viewerWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func renameCurrentImage(toBaseName baseName: String) throws {
        guard let currentImageURL else {
            throw RenameImageError.noImage
        }

        try renameImage(at: currentImageURL, toBaseName: baseName)
    }

    func renameImage(at imageURL: URL, toBaseName baseName: String) throws {
        let destinationURL = try renamedImageURL(forBaseName: baseName, from: imageURL)
        guard destinationURL != imageURL else { return }

        let fileManager = FileManager.default

        do {
            if isCaseOnlyRename(from: imageURL, to: destinationURL) {
                let temporaryURL = uniqueTemporaryRenameURL(for: imageURL)
                try fileManager.moveItem(at: imageURL, to: temporaryURL)

                do {
                    try fileManager.moveItem(at: temporaryURL, to: destinationURL)
                } catch {
                    try? fileManager.moveItem(at: temporaryURL, to: imageURL)
                    throw error
                }
            } else {
                try fileManager.moveItem(at: imageURL, to: destinationURL)
            }
        } catch {
            throw RenameImageError.moveFailed(error)
        }

        loadImage(at: destinationURL)
    }

    private func updateDisplayedImage() {
        guard imageURLs.indices.contains(currentIndex) else {
            replaceArchiveSource(with: nil)
            currentImage = nil
            currentImageURL = nil
            currentImagePixelSize = nil
            currentImageFileSize = nil
            currentImageFinderLabel = nil
            currentMetadata = ImageMetadata(sections: [])
            currentAnimatedImage = nil
            currentImageFileIdentity = nil
            bumpCurrentImageContentVersion()
            refreshFileSystemWatchers()
            return
        }

        let url = imageURLs[currentIndex]
        let animatedImage = AnimatedImageLoader.load(from: url)

        guard let image = animatedImage?.posterImage ?? NSImage(contentsOf: url) else {
            currentImage = nil
            currentImageURL = url
            currentImagePixelSize = nil
            currentImageFileSize = fileSize(for: url)
            currentImageFinderLabel = finderLabel(for: url)
            currentMetadata = ImageMetadataLoader.load(from: url)
            currentAnimatedImage = animatedImage
            currentImageFileIdentity = fileIdentity(for: url)
            bumpCurrentImageContentVersion()
            refreshFileSystemWatchers()
            return
        }

        currentImage = image
        currentImageURL = url
        currentImagePixelSize = animatedImage?.pixelSize ?? pixelSize(for: image)
        currentImageFileSize = fileSize(for: url)
        currentImageFinderLabel = finderLabel(for: url)
        currentMetadata = ImageMetadataLoader.load(from: url)
        currentAnimatedImage = animatedImage
        currentImageFileIdentity = fileIdentity(for: url)
        bumpCurrentImageContentVersion()
        refreshFileSystemWatchers()
    }

    private func setSingleImage(url: URL, error: Error? = nil) {
        let standardizedURL = url.standardizedFileURL
        replaceArchiveSource(with: nil)
        isFolderScopedObservationEnabled = false
        imageURLs = [standardizedURL]
        currentIndex = 0
        currentImageURL = standardizedURL
        let animatedImage = AnimatedImageLoader.load(from: standardizedURL)

        if let image = animatedImage?.posterImage ?? NSImage(contentsOf: standardizedURL) {
            currentImage = image
            currentImagePixelSize = animatedImage?.pixelSize ?? pixelSize(for: image)
            currentImageFileSize = fileSize(for: standardizedURL)
            currentImageFinderLabel = finderLabel(for: standardizedURL)
            currentMetadata = ImageMetadataLoader.load(from: standardizedURL)
            currentAnimatedImage = animatedImage
            currentImageFileIdentity = fileIdentity(for: standardizedURL)
        } else {
            currentImage = nil
            currentImagePixelSize = nil
            currentImageFileSize = fileSize(for: standardizedURL)
            currentImageFinderLabel = finderLabel(for: standardizedURL)
            currentMetadata = ImageMetadataLoader.load(from: standardizedURL)
            currentAnimatedImage = animatedImage
            currentImageFileIdentity = fileIdentity(for: standardizedURL)
        }

        bumpCurrentImageContentVersion()
        refreshFileSystemWatchers()
    }

    private func installArchiveSource(_ archiveSource: ArchiveImageSource) {
        replaceArchiveSource(with: archiveSource)
        isFolderScopedObservationEnabled = false
        imageURLs = archiveSource.entries.map(\.extractedURL)
        currentIndex = 0
        updateDisplayedImage()
    }

    private func pixelSize(for image: NSImage) -> CGSize? {
        if let representation = image.representations.first(where: { $0.pixelsWide > 0 && $0.pixelsHigh > 0 }) {
            return CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
        }

        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }

        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        return size
    }

    private func fileSize(for url: URL) -> Int64? {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = attributes[.size] as? NSNumber
        else {
            return nil
        }

        return size.int64Value
    }

    private func fileIdentity(for url: URL) -> NSObject? {
        let resourceValues = try? url.resourceValues(forKeys: [.fileResourceIdentifierKey])
        return resourceValues?.fileResourceIdentifier as? NSObject
    }

    private func finderLabel(for url: URL) -> FinderLabel {
        let resourceValues = try? url.resourceValues(forKeys: [.labelNumberKey])
        let labelNumber = resourceValues?.labelNumber ?? FinderLabel.none.rawValue
        return FinderLabel(rawValue: labelNumber) ?? .none
    }

    private func currentDesktopPictureScreen() -> NSScreen? {
        viewerWindow?.screen ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func isTemporaryClipboardImageURL(_ url: URL) -> Bool {
        let standardizedURL = url.standardizedFileURL
        let basePath = Self.clipboardImportDirectoryURL.path
        let standardizedPath = standardizedURL.path

        return standardizedPath == basePath || standardizedPath.hasPrefix(basePath + "/")
    }

    private func scanImageURLs(in folderURL: URL) throws -> [URL] {
        let folderContents = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.fileResourceIdentifierKey],
            options: [.skipsHiddenFiles]
        )

        return folderContents
            .map(\.standardizedFileURL)
            .filter { SupportedImageFormats.folderExtensions.contains($0.pathExtension.lowercased()) }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
    }

    private func bumpCurrentImageContentVersion() {
        currentImageContentVersion &+= 1
    }

    private func performCurrentImageTransfer(_ action: FileTransferAction, toDestinationSlot slotNumber: Int) {
        guard canTransferCurrentImage else { return }

        guard let currentImageURL = currentImageURL?.standardizedFileURL else {
            presentAlert(
                title: "\(action.verb) Failed",
                message: FileTransferError.noImage.localizedDescription
            )
            return
        }

        guard let destination = fileActionDestinations.first(where: { $0.slotNumber == slotNumber }) else { return }

        guard let destinationFolderURL = destination.url?.standardizedFileURL else {
            requestManageDestinations()
            return
        }

        do {
            let transferTargetURL = try transferTargetURL(
                for: currentImageURL,
                destinationFolderURL: destinationFolderURL
            )

            switch action {
            case .copy:
                try FileManager.default.copyItem(at: currentImageURL, to: transferTargetURL)
                presentFileActionMessage("\(action.pastTenseVerb) to \(destination.displayName)")
            case .move:
                try FileManager.default.moveItem(at: currentImageURL, to: transferTargetURL)
                updateAfterMovingCurrentImage(from: currentImageURL, to: transferTargetURL)
                presentFileActionMessage("\(action.pastTenseVerb) to \(destination.displayName)")
            }
        } catch let error as FileTransferError {
            presentAlert(title: "\(action.verb) Failed", message: error.localizedDescription)
        } catch {
            presentAlert(title: "\(action.verb) Failed", message: error.localizedDescription)
        }
    }

    private func trashImage(at imageURL: URL) {
        let standardizedURL = imageURL.standardizedFileURL

        do {
            var resultingItemURL: NSURL?
            try FileManager.default.trashItem(
                at: standardizedURL,
                resultingItemURL: &resultingItemURL
            )

            updateAfterTrashingCurrentImage(at: standardizedURL)
            presentFileActionMessage("Moved to Trash")
        } catch {
            presentAlert(
                title: "Move to Trash Failed",
                message: error.localizedDescription
            )
        }
    }

    private func transferTargetURL(for sourceURL: URL, destinationFolderURL: URL) throws -> URL {
        let resourceValues = try destinationFolderURL.resourceValues(forKeys: [.isDirectoryKey])
        guard resourceValues.isDirectory == true else {
            throw FileTransferError.invalidDestinationFolder
        }

        if sourceURL.deletingLastPathComponent() == destinationFolderURL {
            throw FileTransferError.sameLocation
        }

        let targetURL = destinationFolderURL.appendingPathComponent(sourceURL.lastPathComponent)
        guard !FileManager.default.fileExists(atPath: targetURL.path) else {
            throw FileTransferError.duplicateName(targetURL.lastPathComponent)
        }

        return targetURL
    }

    private func updateAfterMovingCurrentImage(from sourceURL: URL, to destinationURL: URL) {
        let remainingImageURLs = imageURLs.filter { $0.standardizedFileURL != sourceURL }

        guard !remainingImageURLs.isEmpty else {
            loadImage(at: destinationURL)
            return
        }

        imageURLs = remainingImageURLs
        currentIndex = min(currentIndex, remainingImageURLs.count - 1)
        updateDisplayedImage()
    }

    private func updateAfterTrashingCurrentImage(at sourceURL: URL) {
        let standardizedSourceURL = sourceURL.standardizedFileURL
        let deletedIndex = imageURLs.firstIndex(where: { $0.standardizedFileURL == standardizedSourceURL }) ?? currentIndex
        let remainingImageURLs = imageURLs.filter { $0.standardizedFileURL != standardizedSourceURL }

        guard !remainingImageURLs.isEmpty else {
            clearCurrentImageState()
            return
        }

        imageURLs = remainingImageURLs
        currentIndex = min(deletedIndex, remainingImageURLs.count - 1)
        updateDisplayedImage()
    }

    private func clearCurrentImageState() {
        replaceArchiveSource(with: nil)
        isFolderScopedObservationEnabled = false
        imageURLs = []
        currentIndex = 0
        currentImage = nil
        currentImageURL = nil
        currentImagePixelSize = nil
        currentImageFileSize = nil
        currentImageFinderLabel = nil
        currentMetadata = ImageMetadata(sections: [])
        currentAnimatedImage = nil
        currentImageFileIdentity = nil
        bumpCurrentImageContentVersion()
        refreshFileSystemWatchers()
    }

    private func presentAlert(title: String, message: String) {
        activeAlert = FileActionAlertState(title: title, message: message)
        NSSound.beep()
    }

    private func presentFileActionMessage(_ message: String) {
        fileActionMessageDismissWorkItem?.cancel()
        fileActionMessage = message

        let workItem = DispatchWorkItem { [weak self] in
            self?.fileActionMessage = nil
        }

        fileActionMessageDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }

    private func updateFileActionDestination(forSlot slotNumber: Int, path: String?) {
        guard let index = fileActionDestinations.firstIndex(where: { $0.slotNumber == slotNumber }) else { return }
        fileActionDestinations[index].path = path
        persistFileActionDestinations()
    }

    private func persistFileActionDestinations() {
        AppPreferences.saveFileActionDestinations(fileActionDestinations)
    }

    private func reloadFileActionDestinationsFromDefaults() {
        let storedDestinations = AppPreferences.loadFileActionDestinations()
        guard storedDestinations != fileActionDestinations else { return }
        fileActionDestinations = storedDestinations
    }

    private func refreshObservedFileSystemState() {
        fileSystemRefreshWorkItem = nil

        guard let currentImageURL = currentImageURL?.standardizedFileURL else {
            refreshFileSystemWatchers()
            return
        }

        if isFolderScopedObservationEnabled {
            refreshFolderScopedImageState(currentImageURL: currentImageURL)
        } else {
            refreshIsolatedImageState(currentImageURL: currentImageURL)
        }
    }

    private func refreshFolderScopedImageState(currentImageURL: URL) {
        let folderURL = currentImageURL.deletingLastPathComponent()

        do {
            let images = try scanImageURLs(in: folderURL)

            guard !images.isEmpty else {
                clearCurrentImageState()
                return
            }

            imageURLs = images

            if let preservedIndex = preservedCurrentImageIndex(in: images, currentImageURL: currentImageURL) {
                currentIndex = preservedIndex
            } else {
                currentIndex = min(currentIndex, images.count - 1)
            }

            updateDisplayedImage()
        } catch {
            guard FileManager.default.fileExists(atPath: currentImageURL.path) else {
                clearCurrentImageState()
                return
            }

            guard imageURLs.indices.contains(currentIndex) else {
                clearCurrentImageState()
                return
            }

            updateDisplayedImage()
        }
    }

    private func refreshIsolatedImageState(currentImageURL: URL) {
        guard FileManager.default.fileExists(atPath: currentImageURL.path) else {
            clearCurrentImageState()
            return
        }

        setSingleImage(url: currentImageURL)
    }

    private func preservedCurrentImageIndex(in images: [URL], currentImageURL: URL) -> Int? {
        if let directMatchIndex = images.firstIndex(of: currentImageURL) {
            return directMatchIndex
        }

        guard let currentImageFileIdentity else { return nil }

        return images.firstIndex { url in
            guard let candidateIdentity = fileIdentity(for: url) else { return false }
            return currentImageFileIdentity.isEqual(candidateIdentity)
        }
    }

    private func scheduleObservedFileSystemRefresh() {
        guard currentImageURL != nil else { return }

        fileSystemRefreshWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshObservedFileSystemState()
        }

        fileSystemRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    private func refreshFileSystemWatchers() {
        if currentArchiveSource != nil {
            watchedFolderURL = nil
            folderWatcher = nil
            watchedFileURL = nil
            currentFileWatcher = nil
            return
        }

        let currentURL = currentImageURL?.standardizedFileURL
        let folderURL = isFolderScopedObservationEnabled ? currentURL?.deletingLastPathComponent() : nil

        if watchedFolderURL != folderURL {
            watchedFolderURL = folderURL
            folderWatcher = folderURL.flatMap { observedURL in
                FileSystemWatcher(
                    url: observedURL,
                    eventMask: [.write, .rename, .delete, .attrib, .extend, .link, .revoke],
                    queue: fileSystemWatcherQueue
                ) { [weak self] in
                    DispatchQueue.main.async {
                        self?.scheduleObservedFileSystemRefresh()
                    }
                }
            }
        }

        if watchedFileURL != currentURL {
            watchedFileURL = currentURL
            currentFileWatcher = currentURL.flatMap { observedURL in
                FileSystemWatcher(
                    url: observedURL,
                    eventMask: [.write, .rename, .delete, .attrib, .extend, .revoke],
                    queue: fileSystemWatcherQueue
                ) { [weak self] in
                    DispatchQueue.main.async {
                        self?.scheduleObservedFileSystemRefresh()
                    }
                }
            }
        }
    }

    private func replaceArchiveSource(with archiveSource: ArchiveImageSource?) {
        let previousArchiveSource = currentArchiveSource
        currentArchiveSource = archiveSource

        if previousArchiveSource?.extractedRootURL != archiveSource?.extractedRootURL {
            ArchiveImageSourceLoader.cleanup(previousArchiveSource)
        }
    }

    private func promptArchivePassphrase(for archiveURL: URL, invalidPassword: Bool) -> String? {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = invalidPassword ? "Incorrect Archive Password" : "Archive Password Required"
        alert.informativeText = invalidPassword
            ? "The password for \"\(archiveURL.lastPathComponent)\" was incorrect. Enter it again to view images inside the archive."
            : "\"\(archiveURL.lastPathComponent)\" is password-protected. Enter the password to view images inside the archive."
        alert.addButton(withTitle: "Open")
        alert.addButton(withTitle: "Cancel")

        let secureField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        secureField.placeholderString = "Password"
        secureField.lineBreakMode = .byTruncatingTail
        alert.accessoryView = secureField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }

        let passphrase = secureField.stringValue
        guard !passphrase.isEmpty else { return nil }
        return passphrase
    }

    private static func consumeLaunchImageArgument() -> String? {
        guard !didConsumeLaunchImageArgument else { return nil }
        didConsumeLaunchImageArgument = true
        return CommandLine.arguments.dropFirst().first
    }

    private func renamedImageURL(forBaseName baseName: String, from currentURL: URL) throws -> URL {
        let trimmedBaseName = baseName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedBaseName.isEmpty else {
            throw RenameImageError.emptyName
        }

        guard trimmedBaseName != ".", trimmedBaseName != ".." else {
            throw RenameImageError.invalidCharacters
        }

        let invalidCharacters = CharacterSet(charactersIn: "/:")
        guard trimmedBaseName.rangeOfCharacter(from: invalidCharacters) == nil else {
            throw RenameImageError.invalidCharacters
        }

        let pathExtension = currentURL.pathExtension
        let currentBaseName = currentURL.deletingPathExtension().lastPathComponent
        guard trimmedBaseName != currentBaseName else {
            return currentURL
        }

        let destinationURL = destinationURL(forBaseName: trimmedBaseName, pathExtension: pathExtension, currentURL: currentURL)

        if FileManager.default.fileExists(atPath: destinationURL.path), !isCaseOnlyRename(from: currentURL, to: destinationURL) {
            throw RenameImageError.duplicateName(destinationURL.lastPathComponent)
        }

        return destinationURL
    }

    private func destinationURL(forBaseName baseName: String, pathExtension: String, currentURL: URL) -> URL {
        let fileName: String
        if pathExtension.isEmpty {
            fileName = baseName
        } else {
            fileName = "\(baseName).\(pathExtension)"
        }

        return currentURL.deletingLastPathComponent().appendingPathComponent(fileName)
    }

    private func isCaseOnlyRename(from sourceURL: URL, to destinationURL: URL) -> Bool {
        sourceURL.deletingLastPathComponent() == destinationURL.deletingLastPathComponent()
            && sourceURL.lastPathComponent.caseInsensitiveCompare(destinationURL.lastPathComponent) == .orderedSame
            && sourceURL.lastPathComponent != destinationURL.lastPathComponent
    }

    private func uniqueTemporaryRenameURL(for sourceURL: URL) -> URL {
        let directoryURL = sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let pathExtension = sourceURL.pathExtension

        while true {
            let candidateBaseName = "\(baseName).rename-\(UUID().uuidString)"
            let candidateURL = destinationURL(forBaseName: candidateBaseName, pathExtension: pathExtension, currentURL: sourceURL)

            if !FileManager.default.fileExists(atPath: candidateURL.path) {
                return directoryURL.appendingPathComponent(candidateURL.lastPathComponent)
            }
        }
    }

    private func writeTemporaryImportedImage(_ image: NSImage) throws -> URL {
        let directoryURL = Self.clipboardImportDirectoryURL

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let url = directoryURL.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")

        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw ClipboardImageTransferError.decodeFailed
        }

        try pngData.write(to: url, options: .atomic)
        return url
    }
}

private enum FileTransferError: LocalizedError {
    case noImage
    case invalidDestinationFolder
    case sameLocation
    case duplicateName(String)

    var errorDescription: String? {
        switch self {
        case .noImage:
            return "No image loaded."
        case .invalidDestinationFolder:
            return "The selected destination folder is no longer available."
        case .sameLocation:
            return "The file is already in that folder."
        case let .duplicateName(name):
            return "A file named \"\(name)\" already exists in the destination folder."
        }
    }
}

private enum RenameImageError: LocalizedError {
    case noImage
    case emptyName
    case invalidCharacters
    case duplicateName(String)
    case moveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noImage:
            return "No image loaded."
        case .emptyName:
            return "Name can't be empty."
        case .invalidCharacters:
            return "Name can't contain \"/\" or \":\"."
        case let .duplicateName(name):
            return "A file named \"\(name)\" already exists."
        case let .moveFailed(error):
            return "Couldn't rename the file: \(error.localizedDescription)"
        }
    }
}

private enum DesktopPictureError: LocalizedError {
    case noScreen
    case temporaryClipboardImage
    case archiveImage

    var errorDescription: String? {
        switch self {
        case .noScreen:
            return "Couldn't determine which display should receive the desktop picture."
        case .temporaryClipboardImage:
            return "Clipboard images need to be saved as a regular file before they can be used as a desktop picture."
        case .archiveImage:
            return "Images opened from archives need to be exported first before they can be used as a desktop picture."
        }
    }
}
