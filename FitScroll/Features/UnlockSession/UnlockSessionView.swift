import SwiftUI
import SwiftData

struct UnlockSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var rewardRules: [ExerciseRewardRule]
    @Query private var settings: [UserSettings]
    @State private var selectedExercise: ExerciseType?
    @State private var showWorkout = false

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
                VStack(spacing: DS.Spacing.lg) {
                    headerSection

                    VStack(spacing: DS.Spacing.sm) {
                        sectionHeader("Stable Exercises")
                        ForEach(enabledExercises.filter { $0.0.stability == .stable }, id: \.0) { exercise, minutes in
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

                        let experimental = enabledExercises.filter { $0.0.stability == .experimental }
                        if !experimental.isEmpty {
                            sectionHeader("Experimental")
                            ForEach(experimental, id: \.0) { exercise, minutes in
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
                    .padding(.horizontal, DS.Spacing.lg)
                }
            }
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
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 40))
                .foregroundColor(DS.Colors.primary)
            Text(Strings.Unlock.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DS.Spacing.lg)
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.top, DS.Spacing.sm)
    }
}
