import AppKit
import SwiftUI

struct ImageViewerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var window: NSWindow?
    private let controlsHeight: CGFloat = 48

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black.opacity(0.92)
                    .ignoresSafeArea()

                if let image = appState.currentImage {
                    GeometryReader { proxy in
                        ZStack {
                            // Use a blurred version of the same image as a backdrop so
                            // the main image can stay fully visible without black bars.
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .blur(radius: 24)
                                .opacity(0.75)
                                .clipped()

                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("No image loaded")
                            .font(.title2.weight(.semibold))
                        Text("Choose an image to start browsing the folder.")
                            .foregroundStyle(.secondary)
                        Button("Open Image") {
                            appState.openImagePicker()
                        }
                    }
                    .padding(24)
                    .foregroundStyle(.white)
                }
            }

            HStack(spacing: 12) {
                Button("Prev") {
                    appState.showPreviousImage()
                }
                .controlSize(.large)
                .font(.system(size: 18, weight: .semibold))
                .frame(minWidth: 120, maxHeight: .infinity)
                .disabled(!appState.canShowPrevious)

                Button("Next") {
                    appState.showNextImage()
                }
                .controlSize(.large)
                .font(.system(size: 18, weight: .semibold))
                .frame(minWidth: 120, maxHeight: .infinity)
                .disabled(!appState.canShowNext)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 10)
            .frame(height: controlsHeight)
        }
        .background(Color.black.opacity(0.92))
        .onAppear {
            appState.loadInitialImage()
        }
        .onChange(of: appState.currentImageURL) { _, newURL in
            updateWindowTitle(with: newURL)
        }
        .background {
            KeyboardHandlerView(
                onLeftArrow: appState.showPreviousImage,
                onRightArrow: appState.showNextImage
            )
        }
        .background {
            WindowAccessor { nsWindow in
                guard window !== nsWindow else { return }
                window = nsWindow
                configureWindow(nsWindow)
                updateWindowTitle(with: appState.currentImageURL)
            }
        }
    }

    private func configureWindow(_ window: NSWindow) {
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false

        if let screen = window.screen ?? NSScreen.main {
            let frame = screen.visibleFrame
            window.setFrame(frame, display: true)
        } else {
            window.zoom(nil)
        }
    }

    private func updateWindowTitle(with url: URL?) {
        window?.title = url?.lastPathComponent ?? "Open Image"
    }
}

private struct KeyboardHandlerView: NSViewRepresentable {
    let onLeftArrow: () -> Void
    let onRightArrow: () -> Void

    func makeNSView(context: Context) -> KeyAwareView {
        let view = KeyAwareView()
        view.onLeftArrow = onLeftArrow
        view.onRightArrow = onRightArrow

        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_ nsView: KeyAwareView, context: Context) {
        nsView.onLeftArrow = onLeftArrow
        nsView.onRightArrow = onRightArrow

        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class KeyAwareView: NSView {
    var onLeftArrow: (() -> Void)?
    var onRightArrow: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123:
            onLeftArrow?()
        case 124:
            onRightArrow?()
        default:
            super.keyDown(with: event)
        }
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onResolve(window)
            }
        }
    }
}
