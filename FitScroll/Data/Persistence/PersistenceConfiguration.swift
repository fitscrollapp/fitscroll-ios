import SwiftData
import Foundation

enum PersistenceConfiguration {
    static let schema = Schema([
        WorkoutSession.self,
        UnlockCredit.self,
        ExerciseRewardRule.self,
        UsageLimitRule.self,
        UserSettings.self,
    ])

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// For use in tests and previews
    static func makeInMemoryContainer() throws -> ModelContainer {
        try makeContainer(inMemory: true)
    }
}
