import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Gradients.primaryButton)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.Corner.large, style: .continuous))
            .shadow(color: DS.Colors.primary.opacity(0.35), radius: 12, y: 4)
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
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                AnimatedExerciseIcon(
                    exerciseType: exercise,
                    characterStyle: characterStyle
                )
                .frame(width: 52, height: 64)
                .padding(4)
                .background(DS.Colors.primary.opacity(0.08))
                .cornerRadius(DS.Corner.small)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack {
                        Text(exercise.displayName)
                            .font(.headline)
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

                VStack(alignment: .trailing) {
                    Text(String(format: Strings.Unlock.minutesPerRep, minutesPerRep))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(DS.Colors.accent)
                }

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.cardBackground)
            .cornerRadius(DS.Corner.medium)
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
