import Foundation

struct FileActionDestination: Codable, Identifiable, Equatable {
    let slotNumber: Int
    var path: String?

    var id: Int {
        slotNumber
    }

    var url: URL? {
        guard let path else { return nil }
        return URL(fileURLWithPath: path)
    }

    var isConfigured: Bool {
        url != nil
    }

    var displayName: String {
        url?.lastPathComponent ?? "Not Set"
    }

    var displayPath: String? {
        url?.path
    }

    var menuTitle: String {
        "\(slotNumber). \(displayName)"
    }

    static func empty(slotNumber: Int) -> FileActionDestination {
        FileActionDestination(slotNumber: slotNumber, path: nil)
    }
}

enum FileTransferAction {
    case copy
    case move

    var verb: String {
        switch self {
        case .copy:
            return "Copy"
        case .move:
            return "Move"
        }
    }

    var pastTenseVerb: String {
        switch self {
        case .copy:
            return "Copied"
        case .move:
            return "Moved"
        }
    }
}

struct FileActionAlertState: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
