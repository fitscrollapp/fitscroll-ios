import SwiftUI
import RevenueCat

/// Lapsed-subscriber welcome screen. Shown instead of the regular paywall
/// when the user previously held the premium entitlement, is no longer
/// subscribed, and the App Store reports an eligible win-back offer
/// (iOS 18+). Offers a single one-tap discounted return; "see all plans"
/// falls back to the standard paywall.
struct WinBackView: View {
    @StateObject private var purchases = PurchasesService.shared

    let package: Package
    let offer: WinBackOffer
    /// Invoked when the user opts out of the offer to browse regular plans.
    var onSeeAllPlans: () -> Void

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    header
                    offerCard
                    ctaButton
                        .padding(.horizontal, DS.Spacing.lg)

                    Button(Strings.WinBack.seeAllPlans) {
                        onSeeAllPlans()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.7))

                    if let error = purchases.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.lg)
                    }
                }
                .padding(.vertical, DS.Spacing.xl)
            }
        }
        .onAppear {
            AppsFlyerService.shared.logEvent(
                "af_content_view", ["af_content_type": "winback"])
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.07, blue: 0.22),
                Color(red: 0.08, green: 0.15, blue: 0.40),
                Color(red: 0.02, green: 0.05, blue: 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var header: some View {
        VStack(spacing: DS.Spacing.md) {
            Text("💪")
                .font(.system(size: 64))
                .padding(.top, DS.Spacing.lg)

            Text(Strings.WinBack.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(Strings.WinBack.subtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
        }
    }

    private var offerCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(Strings.WinBack.badge)
                .font(.system(size: 11, weight: .black))
                .foregroundColor(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.yellow)
                .cornerRadius(5)

            Text(discountHeadline)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(.white)

            Text(String(
                format: Strings.WinBack.thenPriceFormat,
                package.storeProduct.localizedPriceString))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.orange)

            Text(Strings.WinBack.cancelAnytime)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Corner.xl, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Corner.xl, style: .continuous)
                .stroke(Color.orange.opacity(0.6), lineWidth: 1.5)
        )
        .padding(.horizontal, DS.Spacing.lg)
    }

    /// e.g. "$0.99 for your first month" / "$8.99 for your first year".
    private var discountHeadline: String {
        let price = offer.discount.localizedPriceString
        let format = offer.discount.subscriptionPeriod.unit == .year
            ? Strings.WinBack.firstYearFormat
            : Strings.WinBack.firstMonthFormat
        return String(format: format, price)
    }

    private var ctaButton: some View {
        DuoButton(
            fill: Color(red: 1.0, green: 0.55, blue: 0.10),
            foreground: .white,
            height: 62
        ) {
            guard #available(iOS 18.0, *) else { return }
            Task { await purchases.purchase(package: package, winBackOffer: offer) }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                if purchases.isLoading {
                    ProgressView().tint(.white)
                }
                Text(Strings.WinBack.ctaClaim)
            }
        }
        .shadow(color: .orange.opacity(0.45), radius: 16, y: 6)
        .disabled(purchases.isLoading)
    }
}
