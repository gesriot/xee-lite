import SwiftUI

@main
struct XeeLiteApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var zoomState = ZoomState()

    var body: some Scene {
        WindowGroup {
            ImageViewerView()
                .environmentObject(appState)
                .environmentObject(zoomState)
                .frame(minWidth: 720, minHeight: 520)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Image...") {
                    appState.openImagePicker()
                }
                .keyboardShortcut("o")
            }

            CommandGroup(after: .toolbar) {
                Divider()

                Button("Toggle Full Screen") {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                }
                .keyboardShortcut("f", modifiers: [.command])

                Divider()

                Button("Zoom In") {
                    zoomState.zoomIn()
                }
                .keyboardShortcut("+", modifiers: [.command])
                .disabled(!zoomState.hasImage || !zoomState.canZoomIn)

                Button("Zoom Out") {
                    zoomState.zoomOut()
                }
                .keyboardShortcut("-", modifiers: [.command])
                .disabled(!zoomState.hasImage || !zoomState.canZoomOut)

                Divider()

                Button("Fit in Window") {
                    zoomState.fitInWindow()
                }
                .keyboardShortcut("0", modifiers: [.command])
                .disabled(!zoomState.hasImage)

                Button("Actual Size") {
                    zoomState.actualSize()
                }
                .keyboardShortcut("1", modifiers: [.command])
                .disabled(!zoomState.hasImage)

                Button("Fit on Screen") {
                    zoomState.fitOnScreen()
                }
                .disabled(!zoomState.hasImage)
            }
        }
    }
}
