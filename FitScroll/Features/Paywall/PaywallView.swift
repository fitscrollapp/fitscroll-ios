import SwiftUI
import RevenueCat

/// Subscription paywall showing Yearly (highlighted), Monthly, and Lifetime
/// options from the current `default` offering. Supports 7-day free trial
/// via the subscription product's Introductory Offer.
struct PaywallView: View {
    @StateObject private var purchases = PurchasesService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPackage: Package?

    /// If true, the paywall has a close button — used when presented as a
    /// sheet. When gating the whole app (onboarding flow), pass `false`.
    var dismissable: Bool = true

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    if dismissable {
                        HStack {
                            Spacer()
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.sm)
                    } else {
                        Color.clear.frame(height: DS.Spacing.xl)
                    }

                    header

                    valueProps

                    if let packages = availablePackages, !packages.isEmpty {
                        VStack(spacing: DS.Spacing.md) {
                            ForEach(packages, id: \.identifier) { pkg in
                                PlanCard(
                                    package: pkg,
                                    isSelected: selectedPackage?.identifier == pkg.identifier,
                                    isBestValue: pkg.packageType == .annual
                                ) {
                                    selectedPackage = pkg
                                }
                            }
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                    } else {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.xxl)
                    }

                    ctaButton
                        .padding(.horizontal, DS.Spacing.lg)

                    secondaryActions

                    if let error = purchases.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.lg)
                    }

                    legalFooter
                }
                .padding(.bottom, DS.Spacing.xl)
            }
        }
        .onAppear {
            Task {
                if purchases.offerings == nil {
                    await purchases.fetchOfferings()
                }
                // Default to the annual package if available.
                if selectedPackage == nil, let pkgs = availablePackages {
                    selectedPackage = pkgs.first { $0.packageType == .annual } ?? pkgs.first
                }
            }
        }
        .onChange(of: purchases.isSubscribed) { _, subscribed in
            if subscribed {
                dismiss()
            }
        }
    }

    // MARK: - Sections

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
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .shadow(color: .orange.opacity(0.5), radius: 18)

            Text("Unlock FitScroll Premium")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Move to earn screen time. Start with 7 days free.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.lg)
        }
        .padding(.top, DS.Spacing.md)
    }

    private var valueProps: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach([
                ("hand.raised.fill", "Stop doomscrolling stealing your day"),
                ("lock.fill", "Lock any app automatically"),
                ("figure.strengthtraining.traditional", "Exercise to earn more screen time"),
                ("chart.line.uptrend.xyaxis", "Track progress with analytics"),
            ], id: \.0) { icon, label in
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text(label)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg + DS.Spacing.sm)
    }

    private var availablePackages: [Package]? {
        guard let offering = purchases.offerings?.current else { return nil }
        // Show annual first (best value), monthly, then lifetime.
        let order: [PackageType] = [.annual, .monthly, .lifetime]
        return order.compactMap { type in
            offering.availablePackages.first(where: { $0.packageType == type })
        }
    }

    private var ctaButton: some View {
        Button {
            guard let pkg = selectedPackage else { return }
            Task { await purchases.purchase(package: pkg) }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                if purchases.isLoading {
                    ProgressView().tint(.white)
                }
                Text(ctaTitle)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.55, blue: 0.10),
                             Color(red: 0.95, green: 0.30, blue: 0.25)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(DS.Corner.large)
            .shadow(color: .orange.opacity(0.5), radius: 16, y: 6)
        }
        .disabled(selectedPackage == nil || purchases.isLoading)
    }

    private var ctaTitle: String {
        guard let pkg = selectedPackage else { return "Start Free Trial" }
        if pkg.packageType == .lifetime {
            return "Buy Lifetime"
        }
        if pkg.storeProduct.introductoryDiscount != nil {
            return "Start 7-Day Free Trial"
        }
        return "Subscribe"
    }

    private var secondaryActions: some View {
        HStack(spacing: DS.Spacing.lg) {
            Button("Restore Purchases") {
                Task { await purchases.restorePurchases() }
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.7))

            Text("·")
                .foregroundColor(.white.opacity(0.4))

            Button("Terms & Privacy") {
                // Optional: open terms URL
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(.top, DS.Spacing.sm)
    }

    private var legalFooter: some View {
        Text("Subscriptions auto-renew. Cancel anytime in App Store settings. Free trial converts to paid subscription unless cancelled 24 hours before trial ends.")
            .font(.caption2)
            .foregroundColor(.white.opacity(0.4))
            .multilineTextAlignment(.center)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.sm)
    }
}

// MARK: - Plan card

private struct PlanCard: View {
    let package: Package
    let isSelected: Bool
    let isBestValue: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.white)

                        if isBestValue {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.yellow)
                                .cornerRadius(4)
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(package.storeProduct.localizedPriceString)
                        .font(.headline)
                        .foregroundColor(.white)
                    if let perPeriod = pricePerPeriod {
                        Text(perPeriod)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Corner.medium)
                    .fill(Color.white.opacity(isSelected ? 0.16 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Corner.medium)
                    .stroke(
                        isSelected ? Color.orange : Color.white.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var title: String {
        switch package.packageType {
        case .annual:   return "Yearly"
        case .monthly:  return "Monthly"
        case .lifetime: return "Lifetime"
        default:        return package.storeProduct.localizedTitle
        }
    }

    private var subtitle: String {
        switch package.packageType {
        case .annual:
            return package.storeProduct.introductoryDiscount != nil
                ? "7 days free, then billed yearly"
                : "Billed yearly"
        case .monthly:
            return package.storeProduct.introductoryDiscount != nil
                ? "7 days free, then billed monthly"
                : "Billed monthly"
        case .lifetime:
            return "One-time purchase, yours forever"
        default:
            return ""
        }
    }

    private var pricePerPeriod: String? {
        switch package.packageType {
        case .annual:
            // ~ $X/month equivalent
            let price = package.storeProduct.price
            let monthly = (price as NSDecimalNumber).doubleValue / 12.0
            return String(format: "≈ $%.2f/mo", monthly)
        case .monthly:
            return "per month"
        case .lifetime:
            return "one-time"
        default:
            return nil
        }
    }
}
