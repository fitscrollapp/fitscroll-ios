import SwiftUI
import SwiftData
import FamilyControls

struct AppSelectionView: View {
    @EnvironmentObject private var screenTimeService: ScreenTimeService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var limits: [UsageLimitRule]
    @State private var showPicker = false
    @State private var authError: String?
    @State private var dailyLimitMinutes: Int = 30

    private var currentLimit: UsageLimitRule? { limits.first }

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
                dailyLimitCard

                Spacer()

                PrimaryButton(title: Strings.Limits.save) {
                    saveAndDismiss()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.lg)
            }
            .onAppear {
                dailyLimitMinutes = currentLimit?.dailyLimitMinutes ?? 30
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

        // Try to request Screen Time authorization if not already granted.
        // We swallow errors and always attempt to open the picker afterward —
        // FamilyActivityPicker handles its own empty state when permission is
        // still missing.
        if AuthorizationCenter.shared.authorizationStatus != .approved {
            try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        }

        showPicker = true
    }

    private var dailyLimitCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "timer")
                    .foregroundColor(DS.Colors.accent)
                Text("Daily Limit")
                    .font(.headline)
                Spacer()
                Text("\(dailyLimitMinutes) min")
                    .font(.headline)
                    .foregroundColor(DS.Colors.accent)
                    .monospacedDigit()
            }

            Text("Apps will be locked after reaching this usage today.")
                .font(.caption)
                .foregroundColor(.secondary)

            Slider(
                value: Binding(
                    get: { Double(dailyLimitMinutes) },
                    set: { dailyLimitMinutes = Int($0) }
                ),
                in: 5...240,
                step: 5
            )
            .tint(DS.Colors.accent)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.cardBackground)
        .cornerRadius(DS.Corner.medium)
        .padding(.horizontal, DS.Spacing.lg)
    }

    private func saveAndDismiss() {
        // Persist the daily limit rule
        if let limit = currentLimit {
            limit.dailyLimitMinutes = dailyLimitMinutes
            limit.updatedAt = Date()
        } else {
            let rule = UsageLimitRule(dailyLimitMinutes: dailyLimitMinutes)
            modelContext.insert(rule)
        }
        try? modelContext.save()

        // Kick off Device Activity monitoring with the chosen threshold
        // and immediately apply restrictions to the selected apps.
        screenTimeService.scheduleDeviceActivityMonitoring(limitMinutes: dailyLimitMinutes)
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
