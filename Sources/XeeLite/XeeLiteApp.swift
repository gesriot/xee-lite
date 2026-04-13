import SwiftUI

@main
struct XeeLiteApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var zoomState = ZoomState()
    @AppStorage("showsStatusBar") private var showsStatusBar = true
    @AppStorage("showsInspector") private var showsInspector = false

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

            CommandGroup(after: .newItem) {
                Button("Rename...") {
                    appState.requestRenameCurrentImage()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(!appState.canRenameCurrentImage)

                Button("Move to Trash") {
                    appState.requestDeleteCurrentImage()
                }
                .keyboardShortcut(.delete, modifiers: [.command])
                .disabled(!appState.canDeleteCurrentImage)
            }

            CommandMenu("Transfer") {
                Menu("Copy to") {
                    ForEach(appState.fileActionDestinations) { destination in
                        Button(destination.menuTitle) {
                            appState.copyCurrentImage(toDestinationSlot: destination.slotNumber)
                        }
                        .disabled(!destination.isConfigured || !appState.canTransferCurrentImage)
                    }
                }

                Menu("Move to") {
                    ForEach(appState.fileActionDestinations) { destination in
                        Button(destination.menuTitle) {
                            appState.moveCurrentImage(toDestinationSlot: destination.slotNumber)
                        }
                        .disabled(!destination.isConfigured || !appState.canTransferCurrentImage)
                    }
                }

                Divider()

                Button("Manage Destinations…") {
                    appState.requestManageDestinations()
                }
            }

            CommandGroup(after: .toolbar) {
                Divider()

                Button("Toggle Full Screen") {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                }
                .keyboardShortcut("f", modifiers: [.command])

                Divider()

                Toggle("Show Status Bar", isOn: $showsStatusBar)
                    .keyboardShortcut("/", modifiers: [.command])

                Divider()

                Toggle("Show Inspector", isOn: $showsInspector)
                    .keyboardShortcut("i", modifiers: [.command])

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
