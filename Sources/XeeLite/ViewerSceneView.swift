import SwiftUI

struct ViewerSceneView: View {
    @EnvironmentObject private var viewerCoordinator: ViewerCoordinator
    @StateObject private var viewerSession = ViewerSession()

    var body: some View {
        ImageViewerView()
            .environmentObject(viewerCoordinator)
            .environmentObject(viewerSession)
            .environmentObject(viewerSession.appState)
            .environmentObject(viewerSession.zoomState)
            .environmentObject(viewerSession.slideshowState)
            .environmentObject(viewerSession.cropState)
            .environmentObject(viewerSession.colorAdjustmentState)
            .frame(minWidth: 720, minHeight: 520)
    }
}
