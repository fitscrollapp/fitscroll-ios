import SwiftUI
import SwiftData

struct LimitConfigView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var screenTimeService: ScreenTimeService
    @Query private var limits: [UsageLimitRule]
    @State private var dailyMinutes: Int = 30

    private var currentLimit: UsageLimitRule? {
        limits.first
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xl) {
                Text(Strings.Limits.title)
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(spacing: DS.Spacing.md) {
                    Text(Strings.Limits.dailyLimit)
                        .font(.headline)

                    Text("\(dailyMinutes)")
                        .font(.system(size: DS.FontSize.hero, weight: .bold, design: .rounded))
                        .foregroundColor(DS.Colors.primary)

                    Text(Strings.Limits.minutes)
                        .foregroundColor(.secondary)

                    Slider(
                        value: Binding(
                            get: { Double(dailyMinutes) },
                            set: { dailyMinutes = Int($0) }
                        ),
                        in: 5...240,
                        step: 5
                    )
                    .tint(DS.Colors.primary)
                    .padding(.horizontal, DS.Spacing.xl)
                }

                Spacer()

                PrimaryButton(title: Strings.Limits.save) {
                    saveLimit()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xl)
            }
            .padding(DS.Spacing.lg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                dailyMinutes = currentLimit?.dailyLimitMinutes ?? 30
            }
        }
    }

    private func saveLimit() {
        if let limit = currentLimit {
            limit.dailyLimitMinutes = dailyMinutes
            limit.updatedAt = Date()
        } else {
            let limit = UsageLimitRule(dailyLimitMinutes: dailyMinutes)
            modelContext.insert(limit)
        }

        try? modelContext.save()

        screenTimeService.scheduleDeviceActivityMonitoring(limitMinutes: dailyMinutes)

        dismiss()
    }
}
