import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false

    var body: some View {
        // Duolingo-style candy button: every primary CTA across the app
        // (onboarding, permissions, summary, challenge) shares this look.
        DuoButton(fill: DS.Colors.neon, foreground: DS.Colors.background) {
            action()
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(DS.Colors.background)
                }
                Text(title)
            }
        }
        .disabled(isLoading)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = DS.Colors.primary

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(DS.Colors.textPrimary)
            Text(title)
                .font(.caption)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.md)
        .dsCard(cornerRadius: DS.Corner.medium)
    }
}

struct ExerciseRow: View {
    let exercise: ExerciseType
    let minutesPerRep: Double
    var characterStyle: CharacterStyle = .woman
    let action: () -> Void

    var body: some View {
        // Duolingo-style exercise card: the animated character sits on the
        // exercise's own colour, the rate is a matching pill, and the card
        // gets chunky corners + a coloured hairline.
        let tint = Duo.color(for: exercise)
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                AnimatedExerciseIcon(
                    exerciseType: exercise,
                    characterStyle: characterStyle
                )
                .frame(width: 52, height: 64)
                .padding(4)
                .background(tint.opacity(0.16))
                .cornerRadius(14)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack {
                        Text(exercise.displayName)
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundColor(DS.Colors.textPrimary)
                        if exercise.stability == .experimental {
                            Text(Strings.Unlock.experimentalLabel)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DS.Colors.warning.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    Text(exercise.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(String(format: Strings.Unlock.minutesPerRep, minutesPerRep))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(tint.opacity(0.15)))

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.secondary)
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Corner.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Corner.xl, style: .continuous)
                    .stroke(tint.opacity(0.35), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ErrorBanner: View {
    let message: String
    let recovery: String?
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(DS.Colors.warning)
                Text(message)
                    .font(.subheadline)
            }
            if let recovery {
                Text(recovery)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let onRetry {
                Button(Strings.Errors.tryAgain, action: onRetry)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(DS.Colors.warning.opacity(0.1))
        .cornerRadius(DS.Corner.medium)
    }
}

struct RepCounterDisplay: View {
    let count: Int
    let label: String

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text("\(count)")
                .font(.system(size: DS.FontSize.hero, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(DS.Spacing.lg)
        .background(.ultraThinMaterial)
        .cornerRadius(DS.Corner.large)
    }
}
