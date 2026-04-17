import AppKit
import Combine
import Foundation

@MainActor
final class ViewerCoordinator: ObservableObject {
    let viewerTabbingIdentifier = "xee-lite.viewer"

    @Published private(set) var activeSession: ViewerSession?
    @Published private(set) var browserImageURLs: [URL] = []
    @Published private(set) var browserCurrentImageURL: URL?
    @Published private(set) var browserArchiveURL: URL?

    private var browserSourceSession: ViewerSession?
    private var browserSourceCancellable: AnyCancellable?
    private weak var activeViewerWindow: NSWindow?
    private weak var pendingTabSourceWindow: NSWindow?

    func activate(_ session: ViewerSession, window: NSWindow?) {
        activeSession = session
        activeViewerWindow = window
        setBrowserSourceSession(session)
    }

    func unregister(_ session: ViewerSession, window: NSWindow?) {
        if activeSession === session {
            activeSession = nil
        }

        if let window, activeViewerWindow === window {
            activeViewerWindow = nil
        }

        if browserSourceSession === session {
            setBrowserSourceSession(nil)
        }
    }

    func prepareForNewTab() {
        pendingTabSourceWindow = activeViewerWindow
    }

    func consumePendingTabSourceWindow(for newWindow: NSWindow) -> NSWindow? {
        defer {
            pendingTabSourceWindow = nil
        }

        guard let sourceWindow = pendingTabSourceWindow, sourceWindow !== newWindow else {
            return nil
        }

        return sourceWindow
    }

    func openImageInBrowserSourceViewer(at url: URL) {
        let targetSession = browserSourceSession ?? activeSession
        targetSession?.appState.showArchiveEntry(at: url)

        if let targetSession {
            activeSession = targetSession
        }
    }

    private func setBrowserSourceSession(_ session: ViewerSession?) {
        guard browserSourceSession !== session else { return }

        browserSourceSession = session
        browserSourceCancellable = nil

        guard let session else {
            browserImageURLs = []
            browserCurrentImageURL = nil
            browserArchiveURL = nil
            return
        }

        browserImageURLs = session.appState.imageURLs
        browserCurrentImageURL = session.appState.currentImageURL
        browserArchiveURL = session.appState.currentArchiveSource?.archiveURL

        browserSourceCancellable = Publishers.CombineLatest3(
            session.appState.$imageURLs,
            session.appState.$currentImageURL,
            session.appState.$currentArchiveSource
        )
        .sink { [weak self] imageURLs, currentImageURL, currentArchiveSource in
            self?.browserImageURLs = imageURLs
            self?.browserCurrentImageURL = currentImageURL
            self?.browserArchiveURL = currentArchiveSource?.archiveURL
        }
    }
}
