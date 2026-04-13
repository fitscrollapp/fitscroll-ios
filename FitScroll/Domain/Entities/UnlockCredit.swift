import Foundation
import SwiftData

@Model
final class UnlockCredit: Sendable {
    @Attribute(.unique) var id: UUID
    var earnedMinutes: Double
    var remainingMinutes: Double
    var sourceSessionId: UUID
    var createdAt: Date
    var expiresAt: Date?
    var isActive: Bool

    init(
        id: UUID = UUID(),
        earnedMinutes: Double,
        sourceSessionId: UUID,
        createdAt: Date = Date(),
        isActive: Bool = true
    ) {
        self.id = id
        self.earnedMinutes = earnedMinutes
        self.remainingMinutes = earnedMinutes
        self.sourceSessionId = sourceSessionId
        self.createdAt = createdAt
        self.isActive = isActive
    }
}
