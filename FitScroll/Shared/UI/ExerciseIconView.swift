import SwiftUI

/// Renders a distinctive icon for each exercise type.
/// Uses custom-drawn SwiftUI shapes because SF Symbols doesn't ship
/// dedicated push-up or squat pictograms.
struct ExerciseIconView: View {
    let exerciseType: ExerciseType
    var size: CGFloat = 28
    var color: Color = .primary

    var body: some View {
        Group {
            switch exerciseType {
            case .pushUp:
                PushUpIconShape()
                    .fill(color)
            case .squat:
                SquatIconShape()
                    .fill(color)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Stick-figure push-up: side-view plank with bent arms touching ground,
/// straight legs angled up to the right, head (circle) on the right side.
struct PushUpIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Normalized to a 100 × 100 design canvas, then scaled to rect.
        let w = rect.width
        let h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w / 100, y: rect.minY + y * h / 100)
        }

        // Ground line (thick bar at bottom)
        path.addRect(CGRect(x: rect.minX, y: rect.minY + h * 0.92, width: w, height: h * 0.05))

        // Head (circle on the right)
        let headRadius = h * 0.09
        let headCenter = p(78, 48)
        path.addEllipse(in: CGRect(
            x: headCenter.x - headRadius,
            y: headCenter.y - headRadius,
            width: headRadius * 2,
            height: headRadius * 2
        ))

        // Body (thick path): hip → shoulder horizontal, then shoulder → elbow (bent arm),
        // elbow → wrist (on ground), plus hip → ankle (back leg)
        //
        // We model the body as a filled polygon representing the thick stick-figure look.

        // Approximate points
        let shoulder = p(68, 55)
        let elbow = p(45, 62)
        let wrist = p(45, 90)
        let hip = p(82, 70)
        let ankle = p(95, 90)

        let thickness: CGFloat = h * 0.055

        // Helper: thick line segment as a rounded-rect polygon along (a → b)
        func thickLine(from a: CGPoint, to b: CGPoint, thickness: CGFloat, into path: inout Path) {
            let dx = b.x - a.x
            let dy = b.y - a.y
            let length = sqrt(dx * dx + dy * dy)
            guard length > 0 else { return }
            let nx = -dy / length * thickness / 2
            let ny = dx / length * thickness / 2

            var segment = Path()
            segment.move(to: CGPoint(x: a.x + nx, y: a.y + ny))
            segment.addLine(to: CGPoint(x: b.x + nx, y: b.y + ny))
            segment.addLine(to: CGPoint(x: b.x - nx, y: b.y - ny))
            segment.addLine(to: CGPoint(x: a.x - nx, y: a.y - ny))
            segment.closeSubpath()
            path.addPath(segment)
        }

        // Torso: shoulder → hip
        thickLine(from: shoulder, to: hip, thickness: thickness, into: &path)
        // Upper arm: shoulder → elbow
        thickLine(from: shoulder, to: elbow, thickness: thickness, into: &path)
        // Forearm: elbow → wrist
        thickLine(from: elbow, to: wrist, thickness: thickness, into: &path)
        // Leg: hip → ankle
        thickLine(from: hip, to: ankle, thickness: thickness, into: &path)

        // Joint caps (small circles at elbow, shoulder, hip for smoother look)
        let jointR: CGFloat = thickness / 2
        for point in [shoulder, elbow, wrist, hip, ankle] {
            path.addEllipse(in: CGRect(
                x: point.x - jointR, y: point.y - jointR,
                width: jointR * 2, height: jointR * 2
            ))
        }

        return path
    }
}

/// Stick-figure squat: standing upright figure with bent knees (squat pose).
/// Head on top, straight torso, thighs angled outward, shins vertical.
struct SquatIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let w = rect.width
        let h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w / 100, y: rect.minY + y * h / 100)
        }

        // Ground line
        path.addRect(CGRect(x: rect.minX, y: rect.minY + h * 0.92, width: w, height: h * 0.05))

        // Head
        let headRadius = h * 0.09
        let headCenter = p(50, 18)
        path.addEllipse(in: CGRect(
            x: headCenter.x - headRadius,
            y: headCenter.y - headRadius,
            width: headRadius * 2,
            height: headRadius * 2
        ))

        // Key points
        let shoulder = p(50, 32)
        let hip = p(50, 55)
        let leftKnee = p(32, 72)
        let rightKnee = p(68, 72)
        let leftAnkle = p(32, 90)
        let rightAnkle = p(68, 90)

        // Arms (reaching forward in squat) — drawn as two short lines from shoulders
        let leftHand = p(32, 48)
        let rightHand = p(68, 48)

        let thickness: CGFloat = h * 0.055

        func thickLine(from a: CGPoint, to b: CGPoint, thickness: CGFloat, into path: inout Path) {
            let dx = b.x - a.x
            let dy = b.y - a.y
            let length = sqrt(dx * dx + dy * dy)
            guard length > 0 else { return }
            let nx = -dy / length * thickness / 2
            let ny = dx / length * thickness / 2

            var segment = Path()
            segment.move(to: CGPoint(x: a.x + nx, y: a.y + ny))
            segment.addLine(to: CGPoint(x: b.x + nx, y: b.y + ny))
            segment.addLine(to: CGPoint(x: b.x - nx, y: b.y - ny))
            segment.addLine(to: CGPoint(x: a.x - nx, y: a.y - ny))
            segment.closeSubpath()
            path.addPath(segment)
        }

        // Torso
        thickLine(from: shoulder, to: hip, thickness: thickness, into: &path)
        // Thighs
        thickLine(from: hip, to: leftKnee, thickness: thickness, into: &path)
        thickLine(from: hip, to: rightKnee, thickness: thickness, into: &path)
        // Shins
        thickLine(from: leftKnee, to: leftAnkle, thickness: thickness, into: &path)
        thickLine(from: rightKnee, to: rightAnkle, thickness: thickness, into: &path)
        // Arms (forward)
        thickLine(from: shoulder, to: leftHand, thickness: thickness, into: &path)
        thickLine(from: shoulder, to: rightHand, thickness: thickness, into: &path)

        // Joint caps
        let jointR: CGFloat = thickness / 2
        for point in [shoulder, hip, leftKnee, rightKnee, leftAnkle, rightAnkle] {
            path.addEllipse(in: CGRect(
                x: point.x - jointR, y: point.y - jointR,
                width: jointR * 2, height: jointR * 2
            ))
        }

        return path
    }
}

#Preview {
    HStack(spacing: 40) {
        VStack {
            ExerciseIconView(exerciseType: .pushUp, size: 80, color: .primary)
            Text("Push-up")
        }
        VStack {
            ExerciseIconView(exerciseType: .squat, size: 80, color: .primary)
            Text("Squat")
        }
    }
    .padding()
}
