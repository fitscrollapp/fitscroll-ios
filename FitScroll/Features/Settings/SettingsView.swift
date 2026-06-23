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
                headerSection
                avatarSection
                exerciseRewardsSection
                    .listRowBackground(DS.Colors.cardBackground)
                limitsSection
                    .listRowBackground(DS.Colors.cardBackground)
                preferencesSection
                    .listRowBackground(DS.Colors.cardBackground)
                aboutSection
                    .listRowBackground(DS.Colors.cardBackground)
                dangerSection
                    .listRowBackground(DS.Colors.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle(Strings.Settings.title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { seedMissingRewardRules() }
        }
    }

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Settings")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Colors.textPrimary)
                Text("Customize your experience.")
                    .font(.subheadline)
                    .foregroundColor(DS.Colors.textSecondary)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: DS.Spacing.sm, leading: DS.Spacing.xs, bottom: DS.Spacing.sm, trailing: 0))
        }
    }

    /// Ensure every currently-known ExerciseType has a reward rule in
    /// the database. Existing installs from before new exercises were
    /// added wouldn't otherwise see those exercises in the rewards
    /// section — this backfills them using each type's default rate.
    private func seedMissingRewardRules() {
        let existingTypes = Set(rewardRules.compactMap { $0.exerciseType })
        let missing = ExerciseType.allCases.filter { !existingTypes.contains($0) }
        guard !missing.isEmpty else { return }
        for type in missing {
            modelContext.insert(ExerciseRewardRule(exerciseType: type))
        }
        try? modelContext.save()
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
                        ExerciseIconView(exerciseType: exercise, size: 22, color: DS.Colors.neon)
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

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? DS.Colors.primary : DS.Colors.textSecondary.opacity(0.5))
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
