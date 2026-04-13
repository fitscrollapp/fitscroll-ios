import Foundation

struct JointAngleCalculator: Sendable {

    /// Calculate angle at vertex point B given three points A-B-C
    static func angle(
        pointA: CGPoint,
        vertex: CGPoint,
        pointC: CGPoint
    ) -> Double {
        let vectorBA = CGPoint(x: pointA.x - vertex.x, y: pointA.y - vertex.y)
        let vectorBC = CGPoint(x: pointC.x - vertex.x, y: pointC.y - vertex.y)

        let dotProduct = vectorBA.x * vectorBC.x + vectorBA.y * vectorBC.y
        let magnitudeBA = sqrt(vectorBA.x * vectorBA.x + vectorBA.y * vectorBA.y)
        let magnitudeBC = sqrt(vectorBC.x * vectorBC.x + vectorBC.y * vectorBC.y)

        guard magnitudeBA > 0, magnitudeBC > 0 else { return 0 }

        let cosAngle = dotProduct / (magnitudeBA * magnitudeBC)
        let clampedCos = min(max(cosAngle, -1.0), 1.0)

        return acos(clampedCos) * 180.0 / .pi
    }

    /// Calculate the vertical angle of a limb segment relative to vertical axis
    static func verticalAngle(from pointA: CGPoint, to pointB: CGPoint) -> Double {
        let dx = pointB.x - pointA.x
        let dy = pointB.y - pointA.y
        return atan2(dx, dy) * 180.0 / .pi
    }

    /// Calculate distance between two points (normalized coordinates)
    static func distance(from pointA: CGPoint, to pointB: CGPoint) -> Double {
        let dx = pointB.x - pointA.x
        let dy = pointB.y - pointA.y
        return sqrt(dx * dx + dy * dy)
    }
}
