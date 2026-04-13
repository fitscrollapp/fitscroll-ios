import XCTest
@testable import FitScroll

final class JointAngleCalculatorTests: XCTestCase {

    func testStraightLineAngleIs180() {
        let angle = JointAngleCalculator.angle(
            pointA: CGPoint(x: 0, y: 0),
            vertex: CGPoint(x: 0.5, y: 0),
            pointC: CGPoint(x: 1, y: 0)
        )
        XCTAssertEqual(angle, 180.0, accuracy: 0.1)
    }

    func testRightAngleIs90() {
        let angle = JointAngleCalculator.angle(
            pointA: CGPoint(x: 0, y: 1),
            vertex: CGPoint(x: 0, y: 0),
            pointC: CGPoint(x: 1, y: 0)
        )
        XCTAssertEqual(angle, 90.0, accuracy: 0.1)
    }

    func testZeroAngle() {
        let angle = JointAngleCalculator.angle(
            pointA: CGPoint(x: 1, y: 0),
            vertex: CGPoint(x: 0, y: 0),
            pointC: CGPoint(x: 1, y: 0)
        )
        XCTAssertEqual(angle, 0.0, accuracy: 0.1)
    }

    func testCoincidentPointsReturnZero() {
        let angle = JointAngleCalculator.angle(
            pointA: CGPoint(x: 0, y: 0),
            vertex: CGPoint(x: 0, y: 0),
            pointC: CGPoint(x: 1, y: 0)
        )
        XCTAssertEqual(angle, 0.0, accuracy: 0.1)
    }

    func test45DegreeAngle() {
        let angle = JointAngleCalculator.angle(
            pointA: CGPoint(x: 1, y: 0),
            vertex: CGPoint(x: 0, y: 0),
            pointC: CGPoint(x: 1, y: 1)
        )
        XCTAssertEqual(angle, 45.0, accuracy: 0.1)
    }

    func testDistanceBetweenPoints() {
        let d = JointAngleCalculator.distance(
            from: CGPoint(x: 0, y: 0),
            to: CGPoint(x: 3, y: 4)
        )
        XCTAssertEqual(d, 5.0, accuracy: 0.001)
    }

    func testDistanceSamePointIsZero() {
        let d = JointAngleCalculator.distance(
            from: CGPoint(x: 2, y: 3),
            to: CGPoint(x: 2, y: 3)
        )
        XCTAssertEqual(d, 0.0, accuracy: 0.001)
    }

    func testVerticalAngle() {
        let angle = JointAngleCalculator.verticalAngle(
            from: CGPoint(x: 0, y: 0),
            to: CGPoint(x: 0, y: 1)
        )
        XCTAssertEqual(angle, 0.0, accuracy: 0.1)
    }
}
