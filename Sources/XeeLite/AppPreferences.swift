import Combine
import Foundation

enum ImageOpenZoomBehavior: String, CaseIterable, Identifiable {
    case rememberCurrent
    case fitInWindow
    case fitOnScreen
    case actualSize

    static let appStorageKey = "imageOpenZoomBehavior.v1"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rememberCurrent:
            return "Remember Current"
        case .fitInWindow:
            return "Fit in Window"
        case .fitOnScreen:
            return "Fit on Screen"
        case .actualSize:
            return "Actual Size"
        }
    }

    var detail: String {
        switch self {
        case .rememberCurrent:
            return "Keep the current zoom mode and custom scale when switching to another image."
        case .fitInWindow:
            return "Always resize the new image to fit inside the current viewer window."
        case .fitOnScreen:
            return "Resize the window to fit the new image within the current display."
        case .actualSize:
            return "Open every new image at 100% scale."
        }
    }
}

enum AppPreferences {
    static let fileActionDestinationsDefaultsKey = "fileActionDestinations.v1"

    static func loadFileActionDestinations(userDefaults: UserDefaults = .standard) -> [FileActionDestination] {
        let defaultSlots = (1...9).map(FileActionDestination.empty(slotNumber:))

        guard
            let data = userDefaults.data(forKey: fileActionDestinationsDefaultsKey),
            let storedSlots = try? JSONDecoder().decode([FileActionDestination].self, from: data)
        else {
            return defaultSlots
        }

        var slotsByNumber = Dictionary(uniqueKeysWithValues: defaultSlots.map { ($0.slotNumber, $0) })
        for slot in storedSlots where (1...9).contains(slot.slotNumber) {
            slotsByNumber[slot.slotNumber] = slot
        }

        return (1...9).compactMap { slotsByNumber[$0] }
    }

    static func saveFileActionDestinations(
        _ destinations: [FileActionDestination],
        userDefaults: UserDefaults = .standard
    ) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(destinations) else { return }
        userDefaults.set(data, forKey: fileActionDestinationsDefaultsKey)
    }
}

@MainActor
final class PreferencesStore: ObservableObject {
    @Published private(set) var fileActionDestinations: [FileActionDestination]

    private let userDefaults: UserDefaults
    private var didChangeCancellable: AnyCancellable?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        fileActionDestinations = AppPreferences.loadFileActionDestinations(userDefaults: userDefaults)

        didChangeCancellable = NotificationCenter.default.publisher(
            for: UserDefaults.didChangeNotification,
            object: userDefaults
        )
        .sink { [weak self] _ in
            self?.reloadFileActionDestinations()
        }
    }

    func setDestination(_ folderURL: URL, forSlot slotNumber: Int) {
        guard let index = fileActionDestinations.firstIndex(where: { $0.slotNumber == slotNumber }) else { return }
        fileActionDestinations[index].path = folderURL.standardizedFileURL.path
        persistFileActionDestinations()
    }

    func clearDestination(forSlot slotNumber: Int) {
        guard let index = fileActionDestinations.firstIndex(where: { $0.slotNumber == slotNumber }) else { return }
        fileActionDestinations[index].path = nil
        persistFileActionDestinations()
    }

    private func persistFileActionDestinations() {
        AppPreferences.saveFileActionDestinations(fileActionDestinations, userDefaults: userDefaults)
    }

    private func reloadFileActionDestinations() {
        let storedDestinations = AppPreferences.loadFileActionDestinations(userDefaults: userDefaults)
        guard storedDestinations != fileActionDestinations else { return }
        fileActionDestinations = storedDestinations
    }
}
