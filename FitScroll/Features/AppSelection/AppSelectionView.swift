import SwiftUI
import SwiftData
import FamilyControls

struct AppSelectionView: View {
    @EnvironmentObject private var screenTimeService: ScreenTimeService
    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false
    @State private var authError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.lg) {
                Text(Strings.AppSelection.subtitle)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                if let authError {
                    Text(authError)
                        .font(.caption)
                        .foregroundColor(DS.Colors.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                selectionSummary
                lockExplainerCard

                Spacer()

                PrimaryButton(title: Strings.Limits.save) {
                    saveAndDismiss()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.lg)
            }
            .navigationTitle(Strings.AppSelection.title)
            .navigationBarTitleDisplayMode(.inline)
            .familyActivityPicker(
                isPresented: $showPicker,
                selection: $screenTimeService.selectedApps
            )
        }
    }

    private func openPicker() async {
        authError = nil

        if AuthorizationCenter.shared.authorizationStatus != .approved {
            try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        }

        showPicker = true
    }

    /// Static explainer card. Replaces the old "Daily Limit" slider — the
    /// usage-based lock flow is not implemented and was confusing: apps were
    /// locked immediately on save regardless of the slider value.
    private var lockExplainerCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "lock.fill")
                    .foregroundColor(DS.Colors.accent)
                Text("Locked right away")
                    .font(.headline)
                Spacer()
            }

            Text("The apps you pick are locked as soon as you hit Save. Unlock them temporarily by finishing a workout — every rep earns minutes of screen time.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.cardBackground)
        .cornerRadius(DS.Corner.medium)
        .padding(.horizontal, DS.Spacing.lg)
    }

    private func saveAndDismiss() {
        Task {
            await screenTimeService.applyRestrictions()
        }
        dismiss()
    }

    private var selectionSummary: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            let appCount = screenTimeService.selectedApps.applicationTokens.count
            let catCount = screenTimeService.selectedApps.categoryTokens.count

            HStack {
                Button {
                    Task { await openPicker() }
                } label: {
                    StatCard(
                        title: Strings.AppSelection.apps,
                        value: "\(appCount)",
                        icon: "app.fill",
                        color: DS.Colors.primary
                    )
                }
                .buttonStyle(.plain)

                Button {
                    Task { await openPicker() }
                } label: {
                    StatCard(
                        title: Strings.AppSelection.categories,
                        value: "\(catCount)",
                        icon: "square.grid.2x2.fill",
                        color: DS.Colors.secondary
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
    }
}
