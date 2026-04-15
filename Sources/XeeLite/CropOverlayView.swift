import SwiftUI

struct CropOverlayView: View {
    @EnvironmentObject private var zoomState: ZoomState

    @ObservedObject var cropState: CropState
    let viewportSize: CGSize
    let onPointerActivity: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            dimmingLayer

            if let imageRect {
                Rectangle()
                    .stroke(.white.opacity(0.18), lineWidth: 1)
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)
            }

            if let selectionRect {
                Rectangle()
                    .stroke(.white.opacity(0.98), lineWidth: 2)
                    .background(
                        Rectangle()
                            .fill(.white.opacity(0.10))
                    )
                    .frame(width: selectionRect.width, height: selectionRect.height)
                    .position(x: selectionRect.midX, y: selectionRect.midY)

                if let selectionText = cropState.selectionText {
                    Text(selectionText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.76), in: Capsule())
                        .position(selectionLabelPosition(for: selectionRect))
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(cropGesture)
    }

    private var imageRect: CGRect? {
        let rect = zoomState.displayedImageRect
        guard rect.width > 0, rect.height > 0 else { return nil }
        return rect
    }

    private var selectionRect: CGRect? {
        guard let selection = cropState.normalizedSelectionRect else { return nil }
        let viewportRect = zoomState.viewportRect(forImagePixelRect: selection)
        guard viewportRect.width > 0, viewportRect.height > 0 else { return nil }
        return viewportRect
    }

    private var dimmingLayer: some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: viewportSize))

            if let selectionRect {
                path.addRect(selectionRect)
            }
        }
        .fill(.black.opacity(0.46), style: FillStyle(eoFill: true))
    }

    private var cropGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                onPointerActivity()
                cropState.beginSelectionIfNeeded(at: value.startLocation, zoomState: zoomState)
                cropState.updateSelection(to: value.location, zoomState: zoomState)
            }
            .onEnded { _ in
                onPointerActivity()
                cropState.endSelection(imagePixelSize: zoomState.currentImagePixelSize)
            }
    }

    private func selectionLabelPosition(for selectionRect: CGRect) -> CGPoint {
        let horizontalPadding: CGFloat = 68
        let verticalPadding: CGFloat = 18
        let defaultX = selectionRect.minX + horizontalPadding
        let x = min(max(defaultX, horizontalPadding), max(viewportSize.width - horizontalPadding, horizontalPadding))

        let preferredY = selectionRect.minY - verticalPadding
        let fallbackY = selectionRect.maxY + verticalPadding
        let y = preferredY > 18 ? preferredY : min(fallbackY, viewportSize.height - 18)

        return CGPoint(x: x, y: y)
    }
}
