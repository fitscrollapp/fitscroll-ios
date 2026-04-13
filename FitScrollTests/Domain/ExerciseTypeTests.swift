import XCTest
@testable import FitScroll

final class ExerciseTypeTests: XCTestCase {

    func testAllCasesHaveDisplayName() {
        for exercise in ExerciseType.allCases {
            XCTAssertFalse(exercise.displayName.isEmpty)
        }
    }

    func testAllCasesHaveIconName() {
        for exercise in ExerciseType.allCases {
            XCTAssertFalse(exercise.iconName.isEmpty)
        }
    }

    func testAllCasesHaveDescription() {
        for exercise in ExerciseType.allCases {
            XCTAssertFalse(exercise.description.isEmpty)
        }
    }

    func testDefaultMinutesPerRepArePositive() {
        for exercise in ExerciseType.allCases {
            XCTAssertGreaterThan(exercise.defaultMinutesPerRep, 0)
        }
    }

    func testAllExercisesStable() {
        let stable = ExerciseType.allCases.filter { $0.stability == .stable }
        XCTAssertTrue(stable.contains(.squat))
        XCTAssertTrue(stable.contains(.pushUp))
    }

    func testHasTwoExercises() {
        XCTAssertEqual(ExerciseType.allCases.count, 2)
    }

    func testIdentifiable() {
        let squat = ExerciseType.squat
        XCTAssertEqual(squat.id, "squat")
    }

    func testSpecificRewardValues() {
        XCTAssertEqual(ExerciseType.squat.defaultMinutesPerRep, 1.0)
        XCTAssertEqual(ExerciseType.pushUp.defaultMinutesPerRep, 1.0)
    }
}
