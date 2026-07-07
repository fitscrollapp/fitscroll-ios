import SwiftUI

/// First-open gate for the Leaderboard tab: pick a public username (min 3
/// chars) before seeing the boards. No login — the device is identified via
/// hashed device id + App Attest (see `FitScrollAPI`).
struct UsernameGateView: View {
    /// Called with the confirmed username once registration succeeds.
    var onComplete: (String) -> Void

    @State private var name = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool { trimmed.count >= 3 && trimmed.count <= 24 }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()

            DuoIconBadge(systemName: "trophy.fill", color: DS.Colors.accent, size: 96)

            VStack(spacing: DS.Spacing.sm) {
                Text("Pick your name")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(DS.Colors.textPrimary)
                Text("This is how you'll appear on the leaderboard.\nNo account needed.")
                    .font(.subheadline)
                    .foregroundColor(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                TextField("Min 3 characters", text: $name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Colors.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focused)
                    .padding(DS.Spacing.md)
                    .background(DS.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                errorMessage != nil
                                ? DS.Colors.error
                                : (isValid ? DS.Colors.neon : DS.Colors.border),
                                lineWidth: 2
                            )
                    )
                    .onChange(of: name) { _, _ in errorMessage = nil }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(DS.Colors.error)
                } else if !name.isEmpty && !isValid {
                    Text(trimmed.count < 3 ? "At least 3 characters" : "Max 24 characters")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)

            Spacer()

            DuoButton(
                fill: isValid ? DS.Colors.neon : DS.Colors.border,
                foreground: isValid ? DS.Colors.background : DS.Colors.textSecondary,
                height: 58
            ) {
                submit()
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    if isSubmitting {
                        ProgressView().tint(DS.Colors.background)
                    }
                    Text("Join the Leaderboard")
                }
            }
            .disabled(!isValid || isSubmitting)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xl)
        }
        .background(DS.Colors.background.ignoresSafeArea())
        .onAppear { focused = true }
        .interactiveDismissDisabled()
    }

    private func submit() {
        guard isValid, !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        let chosen = trimmed

        Task {
            defer { isSubmitting = false }
            do {
                try await FitScrollAPI.shared.identify()
                await FitScrollAPI.shared.enrollAttestationIfNeeded()
                try await FitScrollAPI.shared.setUsername(chosen)
                // Contextual permission moment: they just joined the
                // leaderboard, so challenge pushes are relevant now.
                await NotificationManager.shared.requestAuthorizationIfNeeded()
                onComplete(chosen)
            } catch FitScrollAPI.APIError.usernameTaken {
                errorMessage = "That name is taken — try another."
            } catch {
                // Offline-friendly: keep the name locally so the UI works;
                // it syncs to the backend on the next successful call.
                FitScrollAPI.shared.username = chosen
                onComplete(chosen)
            }
        }
    }
}
