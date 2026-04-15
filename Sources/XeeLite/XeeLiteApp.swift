import AppKit
import SwiftUI

@main
struct XeeLiteApp: App {
    private static let viewerWindowID = "viewer"
    private static let browserWindowID = "folder-browser"

    @StateObject private var viewerCoordinator = ViewerCoordinator()
    @Environment(\.openWindow) private var openWindow

    init() {
        NSWindow.allowsAutomaticWindowTabbing = true
    }

    var body: some Scene {
        WindowGroup(id: Self.viewerWindowID) {
            ViewerSceneView()
                .environmentObject(viewerCoordinator)
        }

        Window("Browser", id: Self.browserWindowID) {
            FolderBrowserView()
                .environmentObject(viewerCoordinator)
        }
        .defaultSize(width: 1040, height: 720)
        .commands {
            CommonAppCommands(
                onNewTab: openNewTab,
                onOpenImage: openImageInActiveViewerOrNewWindow,
                onShowBrowser: showBrowser
            )

            if let activeSession = viewerCoordinator.activeSession {
                ActiveViewerCommands(
                    appState: activeSession.appState,
                    zoomState: activeSession.zoomState,
                    slideshowState: activeSession.slideshowState,
                    cropState: activeSession.cropState,
                    colorAdjustmentState: activeSession.colorAdjustmentState
                )
            }
        }
    }

    private func openNewTab() {
        viewerCoordinator.prepareForNewTab()
        openWindow(id: Self.viewerWindowID)
    }

    private func openImageInActiveViewerOrNewWindow() {
        if let activeSession = viewerCoordinator.activeSession {
            activeSession.appState.openImagePicker()
        } else {
            openWindow(id: Self.viewerWindowID)
        }
    }

    private func showBrowser() {
        openWindow(id: Self.browserWindowID)
    }
}
