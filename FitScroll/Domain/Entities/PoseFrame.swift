import Foundation
import Vision

struct PoseFrame: Sendable {
    let timestamp: Date
    let joints: [JointName: JointPosition]
    let confidence: Float
    /// Dimensions of the source camera frame the joints were detected in.
    /// The pose overlay uses this to undo the preview layer's aspect-fill
    /// crop when projecting joints onto the screen — otherwise joints
    /// appear visibly offset from the body.
    let imageSize: CGSize

    struct JointPosition: Sendable {
        let x: CGFloat
        let y: CGFloat
        let confidence: Float

        var point: CGPoint { CGPoint(x: x, y: y) }
    }

    enum JointName: String, CaseIterable, Sendable {
        case nose
        case leftEye, rightEye
        case leftEar, rightEar
        case leftShoulder, rightShoulder
        case leftElbow, rightElbow
        case leftWrist, rightWrist
        case leftHip, rightHip
        case leftKnee, rightKnee
        case leftAnkle, rightAnkle
    }

    func position(for joint: JointName) -> JointPosition? {
        joints[joint]
    }

    var isValid: Bool {
        confidence > 0.3 && joints.count >= 8
    }
}
