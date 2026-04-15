import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    private static let fileActionDestinationsDefaultsKey = "fileActionDestinations.v1"

    @Published private(set) var imageURLs: [URL] = []
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var currentImage: NSImage?
    @Published private(set) var currentImageURL: URL?
    @Published private(set) var currentImagePixelSize: CGSize?
    @Published private(set) var currentImageFileSize: Int64?
    @Published private(set) var currentImageFinderLabel: FinderLabel?
    @Published private(set) var currentMetadata = ImageMetadata(sections: [])
    @Published private(set) var currentAnimatedImage: AnimatedImage?
    @Published private(set) var renameRequestID: UInt64 = 0
    @Published private(set) var manageDestinationsRequestID: UInt64 = 0
    @Published private(set) var deleteRequestID: UInt64 = 0
    @Published private(set) var fileActionDestinations: [FileActionDestination]
    @Published private(set) var fileActionMessage: String?
    @Published var activeAlert: FileActionAlertState?

    private var fileActionMessageDismissWorkItem: DispatchWorkItem?

    init() {
        fileActionDestinations = Self.loadFileActionDestinations()
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
        if let path = CommandLine.arguments.dropFirst().first {
            loadImage(at: URL(fileURLWithPath: path))
            return
        }

        openImagePicker()
    }

    func loadImage(at url: URL) {
        let standardizedURL = url.standardizedFileURL
        let folderURL = standardizedURL.deletingLastPathComponent()

        do {
            let folderContents = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            let images = folderContents
                .filter { SupportedImageFormats.folderExtensions.contains($0.pathExtension.lowercased()) }
                .sorted {
                    $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
                }

            guard !images.isEmpty else {
                setSingleImage(url: standardizedURL)
                return
            }

            imageURLs = images
            currentIndex = images.firstIndex(of: standardizedURL) ?? 0
            updateDisplayedImage()
        } catch {
            imageURLs = []
            currentIndex = 0
            setSingleImage(url: standardizedURL, error: error)
        }
    }

    func showPreviousImage() {
        guard canShowPrevious else { return }
        currentIndex -= 1
        updateDisplayedImage()
    }

    func showNextImage() {
        guard canShowNext else { return }
        currentIndex += 1
        updateDisplayedImage()
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

    func jumpImages(by delta: Int) {
        guard !imageURLs.isEmpty, delta != 0 else { return }

        let nextIndex = min(max(currentIndex + delta, 0), imageURLs.count - 1)
        guard nextIndex != currentIndex else { return }

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
        currentImageURL != nil
    }

    var canTransferCurrentImage: Bool {
        currentImageURL != nil
    }

    var canDeleteCurrentImage: Bool {
        currentImageURL != nil
    }

    var canSetFinderLabel: Bool {
        currentImageURL != nil
    }

    var currentImagePositionText: String? {
        guard imageURLs.indices.contains(currentIndex) else { return nil }
        return "\(currentIndex + 1)/\(imageURLs.count)"
    }

    var currentImageFormatText: String? {
        guard let pathExtension = currentImageURL?.pathExtension.lowercased(), !pathExtension.isEmpty else { return nil }
        return SupportedImageFormats.displayName(for: pathExtension)
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
            currentImage = nil
            currentImageURL = nil
            currentImagePixelSize = nil
            currentImageFileSize = nil
            currentImageFinderLabel = nil
            currentMetadata = ImageMetadata(sections: [])
            currentAnimatedImage = nil
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
            return
        }

        currentImage = image
        currentImageURL = url
        currentImagePixelSize = animatedImage?.pixelSize ?? pixelSize(for: image)
        currentImageFileSize = fileSize(for: url)
        currentImageFinderLabel = finderLabel(for: url)
        currentMetadata = ImageMetadataLoader.load(from: url)
        currentAnimatedImage = animatedImage
    }

    private func setSingleImage(url: URL, error: Error? = nil) {
        imageURLs = [url]
        currentIndex = 0
        currentImageURL = url
        let animatedImage = AnimatedImageLoader.load(from: url)

        if let image = animatedImage?.posterImage ?? NSImage(contentsOf: url) {
            currentImage = image
            currentImagePixelSize = animatedImage?.pixelSize ?? pixelSize(for: image)
            currentImageFileSize = fileSize(for: url)
            currentImageFinderLabel = finderLabel(for: url)
            currentMetadata = ImageMetadataLoader.load(from: url)
            currentAnimatedImage = animatedImage
        } else {
            currentImage = nil
            currentImagePixelSize = nil
            currentImageFileSize = fileSize(for: url)
            currentImageFinderLabel = finderLabel(for: url)
            currentMetadata = ImageMetadataLoader.load(from: url)
            currentAnimatedImage = animatedImage
        }
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

    private func finderLabel(for url: URL) -> FinderLabel {
        let resourceValues = try? url.resourceValues(forKeys: [.labelNumberKey])
        let labelNumber = resourceValues?.labelNumber ?? FinderLabel.none.rawValue
        return FinderLabel(rawValue: labelNumber) ?? .none
    }

    private func performCurrentImageTransfer(_ action: FileTransferAction, toDestinationSlot slotNumber: Int) {
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
        imageURLs = []
        currentIndex = 0
        currentImage = nil
        currentImageURL = nil
        currentImagePixelSize = nil
        currentImageFileSize = nil
        currentImageFinderLabel = nil
        currentMetadata = ImageMetadata(sections: [])
        currentAnimatedImage = nil
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
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(fileActionDestinations) else { return }
        UserDefaults.standard.set(data, forKey: Self.fileActionDestinationsDefaultsKey)
    }

    private static func loadFileActionDestinations() -> [FileActionDestination] {
        let defaultSlots = (1...9).map(FileActionDestination.empty(slotNumber:))

        guard
            let data = UserDefaults.standard.data(forKey: fileActionDestinationsDefaultsKey),
            let storedSlots = try? JSONDecoder().decode([FileActionDestination].self, from: data)
        else {
            return defaultSlots
        }

        var slotsByNumber = Dictionary(uniqueKeysWithValues: defaultSlots.map { ($0.slotNumber, $0) })
        for slot in storedSlots where (1...9).contains(slot.slotNumber) {
            slotsByNumber[slot.slotNumber] = slot
        }

        return (1...9).compactMap { slotsByNumber[$0] }
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
