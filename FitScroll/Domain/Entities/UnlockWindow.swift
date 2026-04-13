import Foundation

struct UnlockWindow: Sendable {
    let creditId: UUID
    let startTime: Date
    let endTime: Date
    let durationMinutes: Double

    var isActive: Bool {
        let now = Date()
        return now >= startTime && now < endTime
    }

    var remainingSeconds: TimeInterval {
        max(0, endTime.timeIntervalSince(Date()))
    }

    init(creditId: UUID, startTime: Date = Date(), durationMinutes: Double) {
        self.creditId = creditId
        self.startTime = startTime
        self.endTime = startTime.addingTimeInterval(durationMinutes * 60)
        self.durationMinutes = durationMinutes
    }
}
