import Foundation

enum AppAccessState: String, Sendable {
    case unrestricted
    case restricted
    case temporarilyUnlocked

    var displayName: String {
        switch self {
        case .unrestricted: return "Unrestricted"
        case .restricted: return "Restricted"
        case .temporarilyUnlocked: return "Temporarily Unlocked"
        }
    }
}
