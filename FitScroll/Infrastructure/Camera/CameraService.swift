import AVFoundation

protocol CameraServiceProtocol {
    func requestPermission() async -> Bool
    var isAuthorized: Bool { get }
}

final class CameraService: CameraServiceProtocol, Sendable {
    static let shared = CameraService()

    var isAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    func requestPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
}
