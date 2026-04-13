import Foundation

enum FitScrollError: LocalizedError {
    case cameraPermissionDenied
    case screenTimePermissionDenied
    case noAppsSelected
    case poseNotDetected
    case lowLightCondition
    case userOutOfFrame
    case incompleteMotion
    case persistenceError(String)
    case unlockCalculationFailed
    case restrictionApplicationFailed
    case sessionAlreadyInProgress
    case unknownExercise

    var errorDescription: String? {
        switch self {
        case .cameraPermissionDenied:
            return Strings.Errors.cameraPermissionDenied
        case .screenTimePermissionDenied:
            return Strings.Errors.screenTimePermissionDenied
        case .noAppsSelected:
            return Strings.Errors.noAppsSelected
        case .poseNotDetected:
            return Strings.Errors.poseNotDetected
        case .lowLightCondition:
            return Strings.Errors.lowLight
        case .userOutOfFrame:
            return Strings.Errors.outOfFrame
        case .incompleteMotion:
            return Strings.Errors.incompleteMotion
        case .persistenceError(let detail):
            return "Storage error: \(detail)"
        case .unlockCalculationFailed:
            return "Could not calculate unlock duration"
        case .restrictionApplicationFailed:
            return "Failed to apply app restrictions"
        case .sessionAlreadyInProgress:
            return "A workout session is already in progress"
        case .unknownExercise:
            return "Unknown exercise type"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .cameraPermissionDenied:
            return Strings.Errors.cameraRecovery
        case .screenTimePermissionDenied:
            return Strings.Errors.screenTimeRecovery
        case .poseNotDetected, .userOutOfFrame:
            return Strings.Errors.poseRecovery
        case .lowLightCondition:
            return Strings.Errors.lightRecovery
        default:
            return nil
        }
    }
}
