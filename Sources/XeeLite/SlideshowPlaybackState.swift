import Combine
import Foundation
import SwiftUI

enum SlideshowTransitionDirection {
    case forward
    case backward
}

enum SlideshowTransitionStyle: String, CaseIterable, Identifiable {
    case fade
    case slide

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .fade:
            return "Fade"
        case .slide:
            return "Slide"
        }
    }

    func transition(for direction: SlideshowTransitionDirection) -> AnyTransition {
        switch self {
        case .fade:
            return .opacity
        case .slide:
            let insertionEdge: Edge = direction == .forward ? .trailing : .leading
            let removalEdge: Edge = direction == .forward ? .leading : .trailing

            return .asymmetric(
                insertion: .move(edge: insertionEdge).combined(with: .opacity),
                removal: .move(edge: removalEdge).combined(with: .opacity)
            )
        }
    }
}

@MainActor
final class SlideshowPlaybackState: ObservableObject {
    private static let intervalDefaultsKey = "slideshow.interval.v1"
    private static let transitionDefaultsKey = "slideshow.transition.v1"
    private static let defaultInterval: TimeInterval = 3.0

    @Published private(set) var isPlaying = false
    @Published private(set) var interval: TimeInterval
    @Published private(set) var transitionStyle: SlideshowTransitionStyle

    let availableIntervals: [TimeInterval] = [1.5, 2.0, 3.0, 5.0, 8.0, 12.0]

    var onAdvance: (() -> Void)?

    private let userDefaults: UserDefaults
    private var timerCancellable: AnyCancellable?
    private var defaultsDidChangeCancellable: AnyCancellable?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        interval = Self.resolvedInterval(from: userDefaults)
        transitionStyle = Self.resolvedTransitionStyle(from: userDefaults)

        defaultsDidChangeCancellable = NotificationCenter.default.publisher(
            for: UserDefaults.didChangeNotification,
            object: userDefaults
        )
        .sink { [weak self] _ in
            self?.reloadDefaultsIfNeeded()
        }
    }

    var intervalText: String {
        let rounded = interval.rounded()
        if abs(interval - rounded) < 0.001 {
            return "\(Int(rounded))s"
        }

        return "\(interval.formatted(.number.precision(.fractionLength(1))))s"
    }

    var playbackButtonTitle: String {
        isPlaying ? "Pause Slideshow" : "Start Slideshow"
    }

    func start() {
        guard !isPlaying else { return }
        reloadDefaultsIfNeeded()
        isPlaying = true
        scheduleTimer()
    }

    func pause() {
        guard isPlaying else { return }
        isPlaying = false
        timerCancellable?.cancel()
        timerCancellable = nil
        reloadDefaultsIfNeeded()
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            start()
        }
    }

    func setInterval(_ interval: TimeInterval) {
        guard availableIntervals.contains(where: { abs($0 - interval) < 0.001 }) else { return }

        self.interval = interval
        userDefaults.set(interval, forKey: Self.intervalDefaultsKey)

        if isPlaying {
            scheduleTimer()
        }
    }

    func setTransitionStyle(_ style: SlideshowTransitionStyle) {
        guard transitionStyle != style else { return }
        transitionStyle = style
        userDefaults.set(style.rawValue, forKey: Self.transitionDefaultsKey)
    }

    private func reloadDefaultsIfNeeded() {
        guard !isPlaying else { return }

        let storedInterval = Self.resolvedInterval(from: userDefaults)
        if abs(interval - storedInterval) > 0.001 {
            interval = storedInterval
        }

        let storedTransitionStyle = Self.resolvedTransitionStyle(from: userDefaults)
        if transitionStyle != storedTransitionStyle {
            transitionStyle = storedTransitionStyle
        }
    }

    private func scheduleTimer() {
        timerCancellable?.cancel()

        timerCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.onAdvance?()
            }
    }

    private static func resolvedInterval(from userDefaults: UserDefaults) -> TimeInterval {
        let storedInterval = userDefaults.double(forKey: intervalDefaultsKey)
        return storedInterval > 0 ? storedInterval : defaultInterval
    }

    private static func resolvedTransitionStyle(from userDefaults: UserDefaults) -> SlideshowTransitionStyle {
        guard
            let rawValue = userDefaults.string(forKey: transitionDefaultsKey),
            let storedTransition = SlideshowTransitionStyle(rawValue: rawValue)
        else {
            return .fade
        }

        return storedTransition
    }
}
