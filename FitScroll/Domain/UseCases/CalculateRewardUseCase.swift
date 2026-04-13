import Foundation

struct CalculateRewardUseCase: Sendable {

    func execute(
        exerciseType: ExerciseType,
        repCount: Int,
        customMinutesPerRep: Double? = nil
    ) -> Double {
        let minutesPerRep = customMinutesPerRep ?? exerciseType.defaultMinutesPerRep
        return Double(repCount) * minutesPerRep
    }

    func execute(
        exerciseType: ExerciseType,
        repCount: Int,
        rewardRules: [ExerciseRewardRule]
    ) -> Double {
        let rule = rewardRules.first { $0.exerciseTypeRaw == exerciseType.rawValue }
        let minutesPerRep = rule?.minutesPerRep ?? exerciseType.defaultMinutesPerRep
        return Double(repCount) * minutesPerRep
    }

    func remainingRepsForMinutes(
        targetMinutes: Double,
        currentReps: Int,
        exerciseType: ExerciseType,
        minutesPerRep: Double? = nil
    ) -> Int {
        let rate = minutesPerRep ?? exerciseType.defaultMinutesPerRep
        let currentMinutes = Double(currentReps) * rate
        let remaining = targetMinutes - currentMinutes
        guard remaining > 0 else { return 0 }
        return Int(ceil(remaining / rate))
    }
}
