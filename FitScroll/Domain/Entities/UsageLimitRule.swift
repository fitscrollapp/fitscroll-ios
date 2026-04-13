import Foundation
import SwiftData

@Model
final class UsageLimitRule: Sendable {
    @Attribute(.unique) var id: UUID
    var dailyLimitMinutes: Int
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        dailyLimitMinutes: Int = 30,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.dailyLimitMinutes = dailyLimitMinutes
        self.isEnabled = isEnabled
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
