import AVFoundation
import Vision
import UIKit

final class VisionPoseProvider: NSObject, PoseProvider, @unchecked Sendable {
    var onPoseFrame: (@Sendable (PoseFrame) -> Void)?

    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.fitscroll.posedetection", qos: .userInteractive)
    private let sessionQueue = DispatchQueue(label: "com.fitscroll.session", qos: .userInitiated)
    private var isRunning = false
    private var isConfigured = false

    /// Push-ups put the user very close to the camera, so we widen the FOV
    /// just for that exercise. Other exercises use the standard preset
    /// because changing the active format hurts joint detection accuracy.
    var preferWideFieldOfView: Bool = false

    // Throttle: process every Nth frame to reduce CPU usage
    private let frameProcessingInterval = 2
    private var frameCount = 0

    func startProviding() async {
        guard !isRunning else { return }

        // Ensure camera permission
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                Logger.log("Camera permission denied", level: .error)
                return
            }
        } else if status != .authorized {
            Logger.log("Camera not authorized: \(status.rawValue)", level: .error)
            return
        }

        isRunning = true

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                if !self.isConfigured {
                    self.configureSession()
                    self.isConfigured = true
                }
                if !self.captureSession.isRunning {
                    self.captureSession.startRunning()
                }
                continuation.resume()
            }
        }
    }

    func stopProviding() async {
        isRunning = false
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self] in
                if self?.captureSession.isRunning == true {
                    self?.captureSession.stopRunning()
                }
                continuation.resume()
            }
        }
    }

    var captureSessionForPreview: AVCaptureSession {
        captureSession
    }

    private func configureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .medium

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            Logger.log("Failed to create camera input", level: .error)
            captureSession.commitConfiguration()
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        // For push-ups specifically, try to widen the FOV by selecting a
        // 1280×720 (or 1920×1080) format with the largest videoFieldOfView
        // among 4:3/16:9 BiPlanar formats. Filtering out depth and other
        // exotic formats keeps Vision happy.
        if preferWideFieldOfView {
            let candidates = camera.formats.filter { format in
                let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let mediaSubType = CMFormatDescriptionGetMediaSubType(format.formatDescription)
                let isYUV =
                    mediaSubType == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange ||
                    mediaSubType == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                return isYUV && dims.width >= 1280 && dims.height >= 720
            }
            if let widest = candidates.max(by: { $0.videoFieldOfView < $1.videoFieldOfView }) {
                do {
                    try camera.lockForConfiguration()
                    camera.activeFormat = widest
                    if camera.minAvailableVideoZoomFactor < 1.0 {
                        camera.videoZoomFactor = camera.minAvailableVideoZoomFactor
                    }
                    camera.unlockForConfiguration()
                    Logger.log("Wide format for push-up: FOV \(widest.videoFieldOfView)°", level: .info)
                } catch {
                    Logger.log("Could not apply wide format: \(error)", level: .warning)
                }
            }
        }

        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }

        captureSession.commitConfiguration()
    }

    private func detectPose(in sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // The connection's `videoRotationAngle = 90` already rotates the
        // pixel buffer to portrait at the AVFoundation layer, so the buffer
        // dimensions reported here are the rotated (portrait) dimensions.
        // Vision normalizes joint coordinates against the buffer it
        // receives, so we pass these dimensions through directly — no swap,
        // no extra orientation flag.
        let bufferWidth = CVPixelBufferGetWidth(pixelBuffer)
        let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)
        let imageSize = CGSize(width: bufferWidth, height: bufferHeight)

        let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard error == nil,
                  let observation = request.results?.first as? VNHumanBodyPoseObservation else {
                return
            }
            self?.processPoseObservation(observation, imageSize: imageSize)
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    private func processPoseObservation(_ observation: VNHumanBodyPoseObservation, imageSize: CGSize) {
        var joints: [PoseFrame.JointName: PoseFrame.JointPosition] = [:]

        let mapping: [(VNHumanBodyPoseObservation.JointName, PoseFrame.JointName)] = [
            (.nose, .nose),
            (.leftEye, .leftEye), (.rightEye, .rightEye),
            (.leftEar, .leftEar), (.rightEar, .rightEar),
            (.leftShoulder, .leftShoulder), (.rightShoulder, .rightShoulder),
            (.leftElbow, .leftElbow), (.rightElbow, .rightElbow),
            (.leftWrist, .leftWrist), (.rightWrist, .rightWrist),
            (.leftHip, .leftHip), (.rightHip, .rightHip),
            (.leftKnee, .leftKnee), (.rightKnee, .rightKnee),
            (.leftAnkle, .leftAnkle), (.rightAnkle, .rightAnkle),
        ]

        var totalConfidence: Float = 0
        var jointCount: Float = 0

        for (visionName, frameName) in mapping {
            if let point = try? observation.recognizedPoint(visionName),
               point.confidence > 0.1 {
                joints[frameName] = PoseFrame.JointPosition(
                    x: point.location.x,
                    y: point.location.y,
                    confidence: point.confidence
                )
                totalConfidence += point.confidence
                jointCount += 1
            }
        }

        let avgConfidence = jointCount > 0 ? totalConfidence / jointCount : 0

        let frame = PoseFrame(
            timestamp: Date(),
            joints: joints,
            confidence: avgConfidence,
            imageSize: imageSize
        )

        onPoseFrame?(frame)
    }
}

extension VisionPoseProvider: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameCount += 1
        guard frameCount % frameProcessingInterval == 0 else { return }
        detectPose(in: sampleBuffer)
    }
}
