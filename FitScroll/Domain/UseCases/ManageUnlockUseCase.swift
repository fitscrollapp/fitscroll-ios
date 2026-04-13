import Foundation

struct ManageUnlockUseCase: Sendable {

    func createUnlockWindow(from credit: UnlockCredit) -> UnlockWindow {
        UnlockWindow(
            creditId: credit.id,
            durationMinutes: credit.remainingMinutes
        )
    }

    func canUnlock(credit: UnlockCredit) -> Bool {
        credit.isActive && credit.remainingMinutes > 0
    }

    func calculateTotalAvailableMinutes(credits: [UnlockCredit]) -> Double {
        credits
            .filter { $0.isActive && $0.remainingMinutes > 0 }
            .reduce(0) { $0 + $1.remainingMinutes }
    }

    func isWithinDailyLimit(
        earnedToday: Double,
        newMinutes: Double,
        dailyMax: Int
    ) -> Bool {
        (earnedToday + newMinutes) <= Double(dailyMax)
    }

    func clampToDailyLimit(
        earnedToday: Double,
        requestedMinutes: Double,
        dailyMax: Int
    ) -> Double {
        let remaining = Double(dailyMax) - earnedToday
        return min(requestedMinutes, max(0, remaining))
    }
}
