import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    @Query private var rewardRules: [ExerciseRewardRule]
    @EnvironmentObject private var screenTimeService: ScreenTimeService
    @State private var showResetConfirmation = false

    private var userSettings: UserSettings? {
        settings.first
    }

    var body: some View {
        NavigationStack {
            List {
                avatarSection
                exerciseRewardsSection
                limitsSection
                preferencesSection
                aboutSection
                dangerSection
            }
            .navigationTitle(Strings.Settings.title)
        }
    }

    private var avatarSection: some View {
        Section(Strings.Settings.characterStyle) {
            HStack(spacing: DS.Spacing.md) {
                ForEach(CharacterStyle.allCases) { style in
                    AvatarCard(
                        style: style,
                        isSelected: (userSettings?.characterStyle ?? .woman) == style
                    ) {
                        userSettings?.characterStyle = style
                        try? modelContext.save()
                    }
                }
            }
            .padding(.vertical, DS.Spacing.sm)
            .listRowInsets(EdgeInsets(top: 0, leading: DS.Spacing.md, bottom: 0, trailing: DS.Spacing.md))
            .listRowBackground(Color.clear)
        }
    }

    private var exerciseRewardsSection: some View {
        Section(Strings.Settings.exerciseRewards) {
            ForEach(rewardRules, id: \.exerciseTypeRaw) { rule in
                if let exercise = rule.exerciseType {
                    HStack {
                        ExerciseIconView(exerciseType: exercise, size: 22, color: DS.Colors.primary)
                            .frame(width: 28)

                        Text(exercise.displayName)

                        Spacer()

                        Stepper(
                            value: Binding(
                                get: { rule.minutesPerRep },
                                set: { newValue in
                                    rule.minutesPerRep = newValue
                                    rule.updatedAt = Date()
                                    try? modelContext.save()
                                }
                            ),
                            in: 0.5...10.0,
                            step: 0.5
                        ) {
                            Text(String(format: "%.1f min", rule.minutesPerRep))
                                .font(.subheadline)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private var limitsSection: some View {
        Section(Strings.Limits.title) {
            HStack {
                Text(Strings.Settings.dailyMaxUnlock)
                Spacer()
                Stepper(
                    "\(userSettings?.dailyMaxUnlockMinutes ?? 120) min",
                    value: Binding(
                        get: { userSettings?.dailyMaxUnlockMinutes ?? 120 },
                        set: { newValue in
                            userSettings?.dailyMaxUnlockMinutes = newValue
                            try? modelContext.save()
                        }
                    ),
                    in: 10...480,
                    step: 10
                )
            }

            HStack {
                Text(Strings.Settings.defaultLimit)
                Spacer()
                Stepper(
                    "\(userSettings?.defaultDailyLimitMinutes ?? 30) min",
                    value: Binding(
                        get: { userSettings?.defaultDailyLimitMinutes ?? 30 },
                        set: { newValue in
                            userSettings?.defaultDailyLimitMinutes = newValue
                            try? modelContext.save()
                        }
                    ),
                    in: 5...240,
                    step: 5
                )
            }
        }
    }

    private var preferencesSection: some View {
        Section(Strings.Settings.preferences) {
            Toggle(Strings.Settings.hapticFeedback, isOn: Binding(
                get: { userSettings?.hapticFeedbackEnabled ?? true },
                set: { newValue in
                    userSettings?.hapticFeedbackEnabled = newValue
                    try? modelContext.save()
                }
            ))
        }
    }

    private var aboutSection: some View {
        Section(Strings.Settings.about) {
            HStack {
                Text(Strings.Settings.version)
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }

            Text(Strings.Settings.privacyNote)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                Label(Strings.Settings.resetAll, systemImage: "trash")
            }
        }
        .confirmationDialog("Are you sure?", isPresented: $showResetConfirmation) {
            Button("Reset All Data", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("This will delete all workout sessions, settings, and unlock history.")
        }
    }

    private func resetAllData() {
        do {
            try modelContext.delete(model: WorkoutSession.self)
            try modelContext.delete(model: UnlockCredit.self)
            try modelContext.delete(model: ExerciseRewardRule.self)
            try modelContext.delete(model: UsageLimitRule.self)
            try modelContext.delete(model: UserSettings.self)
            try modelContext.save()
        } catch {
            Logger.log("Failed to reset data: \(error)", level: .error)
        }
    }
}

/// Selectable avatar card showing the character's "up" (standing) image.
/// Used in Settings to let the user pick between woman/man characters.
private struct AvatarCard: View {
    let style: CharacterStyle
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DS.Spacing.sm) {
                Image(style.upImageName(for: .squat))
                    .resizable()
                    .scaledToFit()
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .padding(.top, DS.Spacing.sm)

                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? DS.Colors.primary : .secondary.opacity(0.4))
                    .font(.title3)
            }
            .padding(.vertical, DS.Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(
                isSelected
                ? DS.Colors.primary.opacity(0.08)
                : DS.Colors.cardBackground
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Corner.medium)
                    .stroke(
                        isSelected ? DS.Colors.primary : Color.clear,
                        lineWidth: 2
                    )
            )
            .cornerRadius(DS.Corner.medium)
        }
        .buttonStyle(.plain)
    }
}
