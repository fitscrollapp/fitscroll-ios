import XCTest
@testable import FitScroll

final class ManageUnlockUseCaseTests: XCTestCase {

    let sut = ManageUnlockUseCase()

    func testCanUnlockWithActiveCredit() {
        let credit = UnlockCredit(earnedMinutes: 10, sourceSessionId: UUID())
        XCTAssertTrue(sut.canUnlock(credit: credit))
    }

    func testCannotUnlockWithInactiveCredit() {
        let credit = UnlockCredit(earnedMinutes: 10, sourceSessionId: UUID())
        credit.isActive = false
        XCTAssertFalse(sut.canUnlock(credit: credit))
    }

    func testCannotUnlockWithZeroMinutes() {
        let credit = UnlockCredit(earnedMinutes: 0, sourceSessionId: UUID())
        credit.remainingMinutes = 0
        XCTAssertFalse(sut.canUnlock(credit: credit))
    }

    func testCalculateTotalAvailableMinutes() {
        let credits = [
            UnlockCredit(earnedMinutes: 5, sourceSessionId: UUID()),
            UnlockCredit(earnedMinutes: 10, sourceSessionId: UUID()),
            UnlockCredit(earnedMinutes: 3, sourceSessionId: UUID()),
        ]
        let total = sut.calculateTotalAvailableMinutes(credits: credits)
        XCTAssertEqual(total, 18.0, accuracy: 0.01)
    }

    func testCalculateTotalExcludesInactive() {
        let active = UnlockCredit(earnedMinutes: 5, sourceSessionId: UUID())
        let inactive = UnlockCredit(earnedMinutes: 10, sourceSessionId: UUID())
        inactive.isActive = false

        let total = sut.calculateTotalAvailableMinutes(credits: [active, inactive])
        XCTAssertEqual(total, 5.0, accuracy: 0.01)
    }

    func testIsWithinDailyLimit() {
        XCTAssertTrue(sut.isWithinDailyLimit(earnedToday: 50, newMinutes: 10, dailyMax: 120))
        XCTAssertTrue(sut.isWithinDailyLimit(earnedToday: 110, newMinutes: 10, dailyMax: 120))
        XCTAssertFalse(sut.isWithinDailyLimit(earnedToday: 115, newMinutes: 10, dailyMax: 120))
    }

    func testClampToDailyLimit() {
        let clamped = sut.clampToDailyLimit(earnedToday: 115, requestedMinutes: 10, dailyMax: 120)
        XCTAssertEqual(clamped, 5.0, accuracy: 0.01)
    }

    func testClampWhenAlreadyAtLimit() {
        let clamped = sut.clampToDailyLimit(earnedToday: 120, requestedMinutes: 10, dailyMax: 120)
        XCTAssertEqual(clamped, 0.0, accuracy: 0.01)
    }

    func testClampWhenWellBelowLimit() {
        let clamped = sut.clampToDailyLimit(earnedToday: 10, requestedMinutes: 15, dailyMax: 120)
        XCTAssertEqual(clamped, 15.0, accuracy: 0.01)
    }

    func testCreateUnlockWindow() {
        let credit = UnlockCredit(earnedMinutes: 10, sourceSessionId: UUID())
        let window = sut.createUnlockWindow(from: credit)
        XCTAssertEqual(window.durationMinutes, 10.0, accuracy: 0.01)
        XCTAssertTrue(window.isActive)
    }
}
