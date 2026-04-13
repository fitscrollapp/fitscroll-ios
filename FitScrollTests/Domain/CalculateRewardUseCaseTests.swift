import XCTest
@testable import FitScroll

final class CalculateRewardUseCaseTests: XCTestCase {

    let sut = CalculateRewardUseCase()

    func testSquatDefaultReward() {
        let minutes = sut.execute(exerciseType: .squat, repCount: 5)
        XCTAssertEqual(minutes, 5.0, accuracy: 0.01) // 5 reps * 1.0 min
    }

    func testPushUpDefaultReward() {
        let minutes = sut.execute(exerciseType: .pushUp, repCount: 3)
        XCTAssertEqual(minutes, 3.0, accuracy: 0.01) // 3 reps * 1.0 min
    }


    func testPushUpTenReps() {
        let minutes = sut.execute(exerciseType: .pushUp, repCount: 10)
        XCTAssertEqual(minutes, 10.0, accuracy: 0.01)
    }

    func testSquatTenReps() {
        let minutes = sut.execute(exerciseType: .squat, repCount: 10)
        XCTAssertEqual(minutes, 10.0, accuracy: 0.01)
    }

    func testCustomMinutesPerRep() {
        let minutes = sut.execute(exerciseType: .squat, repCount: 5, customMinutesPerRep: 2.5)
        XCTAssertEqual(minutes, 12.5, accuracy: 0.01)
    }

    func testZeroRepsGiveZeroMinutes() {
        let minutes = sut.execute(exerciseType: .squat, repCount: 0)
        XCTAssertEqual(minutes, 0.0, accuracy: 0.01)
    }

    func testRemainingRepsForMinutes() {
        let remaining = sut.remainingRepsForMinutes(
            targetMinutes: 10,
            currentReps: 3,
            exerciseType: .squat
        )
        XCTAssertEqual(remaining, 7) // Need 10 total, have 3 * 1.0 = 3 min, need 7 more
    }

    func testRemainingRepsWhenAlreadyAchieved() {
        let remaining = sut.remainingRepsForMinutes(
            targetMinutes: 5,
            currentReps: 10,
            exerciseType: .squat
        )
        XCTAssertEqual(remaining, 0)
    }

    func testRemainingRepsWithCustomRate() {
        let remaining = sut.remainingRepsForMinutes(
            targetMinutes: 10,
            currentReps: 0,
            exerciseType: .squat,
            minutesPerRep: 2.5
        )
        XCTAssertEqual(remaining, 4) // 10 / 2.5 = 4
    }
}
