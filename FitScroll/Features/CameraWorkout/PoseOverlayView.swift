import SwiftUI

struct PoseOverlayView: View {
    let frame: PoseFrame?
    var lineColor: Color = Color(red: 0.0, green: 0.95, blue: 0.85)
    var jointColor: Color = .white
    var lineWidth: CGFloat = 4
    var jointRadius: CGFloat = 6

    // Skeleton connections (pairs of joints that form bones)
    private static let connections: [(PoseFrame.JointName, PoseFrame.JointName)] = [
        // Torso
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftHip),
        (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        // Left arm
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        // Right arm
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
        // Left leg
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        // Right leg
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle),
    ]

    // Joint points to draw as dots
    private static let keyJoints: [PoseFrame.JointName] = [
        .leftShoulder, .rightShoulder,
        .leftElbow, .rightElbow,
        .leftWrist, .rightWrist,
        .leftHip, .rightHip,
        .leftKnee, .rightKnee,
        .leftAnkle, .rightAnkle,
    ]

    private let minConfidence: Float = 0.2

    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                guard let frame else { return }
                let transform = AspectFillTransform(
                    imageSize: frame.imageSize,
                    viewSize: size
                )

                // Draw connections (bones)
                for (startJoint, endJoint) in Self.connections {
                    guard let start = frame.position(for: startJoint),
                          let end = frame.position(for: endJoint),
                          start.confidence >= minConfidence,
                          end.confidence >= minConfidence else {
                        continue
                    }

                    let startPoint = transform.apply(start.point)
                    let endPoint = transform.apply(end.point)

                    var path = Path()
                    path.move(to: startPoint)
                    path.addLine(to: endPoint)

                    context.stroke(
                        path,
                        with: .color(lineColor),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                }

                // Draw joints (dots)
                for joint in Self.keyJoints {
                    guard let position = frame.position(for: joint),
                          position.confidence >= minConfidence else {
                        continue
                    }

                    let point = transform.apply(position.point)
                    let rect = CGRect(
                        x: point.x - jointRadius,
                        y: point.y - jointRadius,
                        width: jointRadius * 2,
                        height: jointRadius * 2
                    )

                    // Outer glow
                    context.fill(
                        Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)),
                        with: .color(lineColor.opacity(0.4))
                    )
                    // Solid dot
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(jointColor)
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }
}

/// Maps Vision's normalized image coordinates onto a view that displays the
/// same camera frame with `videoGravity = resizeAspectFill`. The preview
/// layer crops the image so it fully covers the view; we apply the same
/// scale + translation so joints land where the eyes/shoulders/etc actually
/// appear on screen.
private struct AspectFillTransform {
    let scale: CGFloat
    let scaledImageSize: CGSize
    let offset: CGPoint
    let viewSize: CGSize

    init(imageSize: CGSize, viewSize: CGSize) {
        self.viewSize = viewSize
        // resizeAspectFill: scale so BOTH dimensions are covered → take max.
        let scaleX = viewSize.width / imageSize.width
        let scaleY = viewSize.height / imageSize.height
        self.scale = max(scaleX, scaleY)
        self.scaledImageSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        self.offset = CGPoint(
            x: (viewSize.width - scaledImageSize.width) / 2,
            y: (viewSize.height - scaledImageSize.height) / 2
        )
    }

    /// Apply the transform to a Vision-normalized point.
    /// Vision uses bottom-left origin; SwiftUI uses top-left → flip Y.
    func apply(_ point: CGPoint) -> CGPoint {
        let x = point.x * scaledImageSize.width + offset.x
        let y = (1.0 - point.y) * scaledImageSize.height + offset.y
        return CGPoint(x: x, y: y)
    }
}
