import Foundation

@MainActor
final class ViewerSession: ObservableObject, Identifiable {
    let id = UUID()
    let appState = AppState()
    let zoomState = ZoomState()
    let slideshowState = SlideshowPlaybackState()
    let cropState = CropState()
    let colorAdjustmentState = ColorAdjustmentState()
}
