import SwiftUI
import SwiftData

struct UnlockSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var rewardRules: [ExerciseRewardRule]
    @Query private var settings: [UserSettings]

    private var characterStyle: CharacterStyle {
        settings.first?.characterStyle ?? .woman
    }

    private var enabledExercises: [(ExerciseType, Double)] {
        ExerciseType.allCases.compactMap { exercise in
            let rule = rewardRules.first { $0.exerciseTypeRaw == exercise.rawValue }
            let minutesPerRep = rule?.minutesPerRep ?? exercise.defaultMinutesPerRep
            let isEnabled = rule?.isEnabled ?? true
            return isEnabled ? (exercise, minutesPerRep) : nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    headerSection
                    durationReference
                    exerciseList
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle(Strings.Unlock.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Unlock with Exercise")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(DS.Colors.textPrimary)
            Text("Choose a workout and earn screen time.")
                .font(.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
        }
    }

    /// Reps-to-minutes reference. Defaults are 1 rep = 1 minute, so the
    /// math is intentionally trivial — this just sets expectations.
    private var durationReference: some View {
        HStack(spacing: DS.Spacing.sm) {
            conversionPill(reps: 5, minutes: 5, highlighted: false)
            conversionPill(reps: 10, minutes: 10, highlighted: true)
            conversionPill(reps: 30, minutes: 30, highlighted: false)
        }
        .padding(DS.Spacing.sm)
        .dsCard()
    }

    private func conversionPill(reps: Int, minutes: Int, highlighted: Bool) -> some View {
        VStack(spacing: 2) {
            Text("\(reps) reps")
                .font(.caption2)
                .foregroundColor(DS.Colors.textSecondary)
            Text("\(minutes) min")
                .font(.headline)
                .foregroundColor(highlighted ? DS.Colors.primary : DS.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Corner.medium, style: .continuous)
                .fill(highlighted ? DS.Colors.primary.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Corner.medium, style: .continuous)
                .stroke(highlighted ? DS.Colors.primary : Color.clear, lineWidth: 1.5)
        )
    }

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Choose an Exercise")
                .font(.headline)
                .foregroundColor(DS.Colors.textPrimary)
            ForEach(enabledExercises, id: \.0) { exercise, minutes in
                NavigationLink {
                    CameraWorkoutView(exerciseType: exercise)
                } label: {
                    ExerciseRow(
                        exercise: exercise,
                        minutesPerRep: minutes,
                        characterStyle: characterStyle
                    ) {}
                    .allowsHitTesting(false)
                }
            }
        }
    }
}
