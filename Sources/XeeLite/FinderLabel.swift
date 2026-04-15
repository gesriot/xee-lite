import Foundation

enum FinderLabel: Int, CaseIterable, Identifiable {
    case none = 0
    case gray = 1
    case green = 2
    case purple = 3
    case blue = 4
    case yellow = 5
    case red = 6
    case orange = 7

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .none:
            return "None"
        case .gray:
            return "Gray"
        case .green:
            return "Green"
        case .purple:
            return "Purple"
        case .blue:
            return "Blue"
        case .yellow:
            return "Yellow"
        case .red:
            return "Red"
        case .orange:
            return "Orange"
        }
    }

    var keyboardDigit: String {
        "\(rawValue)"
    }

    var keyboardCharacter: Character {
        Character(keyboardDigit)
    }

    var appliedStatusMessage: String {
        switch self {
        case .none:
            return "Removed Finder label"
        default:
            return "Labeled \(title)"
        }
    }

    static let coloredCases: [FinderLabel] = [.gray, .green, .purple, .blue, .yellow, .red, .orange]
}
