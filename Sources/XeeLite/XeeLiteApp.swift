import SwiftUI

@main
struct XeeLiteApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ImageViewerView()
                .environmentObject(appState)
                .frame(minWidth: 720, minHeight: 520)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Image...") {
                    appState.openImagePicker()
                }
                .keyboardShortcut("o")
            }
        }
    }
}
