import SwiftUI
import RevenueCat

/// Subscription paywall showing Yearly (highlighted), Monthly, and Lifetime
/// options from the current `default` offering. Supports 7-day free trial
/// via the subscription product's Introductory Offer.
struct PaywallView: View {
    @StateObject private var purchases = PurchasesService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPackage: Package?
    /// Drives the looping burger hop in the price-comparison card.
    @State private var burgerBounce = false

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
                        // Plans side by side — swipe horizontally.
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DS.Spacing.md) {
                                ForEach(packages, id: \.identifier) { pkg in
                                    PlanCard(
                                        package: pkg,
                                        isSelected: selectedPackage?.identifier == pkg.identifier,
                                        isBestValue: pkg.packageType == .annual
                                    ) {
                                        SoundManager.click()
                                        withAnimation(DS.Animation.quick) {
                                            selectedPackage = pkg
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.Spacing.sm)
                        }

                        burgerComparison
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
            AppsFlyerService.shared.logEvent("af_content_view", ["af_content_type": "paywall"])
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
                SoundManager.purchaseSuccess()
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

            Text(Strings.Paywall.title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(Strings.Paywall.subtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.lg)
        }
        .padding(.top, DS.Spacing.md)
    }

    private var valueProps: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // One colour per row (like Duolingo's feature lists) instead of a
            // uniform blue — icons pop and echo the exercise palette.
            ForEach([
                ("hand.raised.fill", Strings.Paywall.valueProp1, DS.Colors.error),
                ("lock.fill", Strings.Paywall.valueProp2, DS.Colors.primary),
                ("figure.strengthtraining.traditional", Strings.Paywall.valueProp3, DS.Colors.accent),
                ("chart.line.uptrend.xyaxis", Strings.Paywall.valueProp4, DS.Colors.neon),
            ], id: \.0) { icon, label, tint in
                HStack(spacing: DS.Spacing.md) {
                    DuoIconBadge(systemName: icon, color: tint, size: 34)

                    Text(label)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg + DS.Spacing.sm)
    }

    // MARK: - Burger math 🍔

    /// The "wait, it's THAT cheap?" moment: price anchored against a Big Mac
    /// menu. Copy adapts to the selected plan.
    private var burgerComparison: some View {
        let (headline, sub): (String, String) = {
            switch selectedPackage?.packageType {
            case .annual:
                return ("1 Big Mac menu ≈ 1 YEAR of FitScroll",
                        "Skip a single burger — get your focus back for a whole year.")
            case .lifetime:
                return ("2 Big Mac menus. Yours FOREVER.",
                        "One-time price of a fast-food lunch for two — lifetime of focus.")
            case .monthly:
                return ("A month costs less than a cheeseburger",
                        "Your screen time is worth more than fries.")
            default:
                return ("Cheaper than a Big Mac menu",
                        "Seriously — check the math.")
            }
        }()

        return HStack(spacing: DS.Spacing.md) {
            // Bouncing burger — the eye goes straight to the price anchor.
            Text("🍔")
                .font(.system(size: 44))
                .offset(y: burgerBounce ? -8 : 3)
                .rotationEffect(.degrees(burgerBounce ? -7 : 7))
                .scaleEffect(burgerBounce ? 1.08 : 0.96)
                .animation(
                    .easeInOut(duration: 0.55).repeatForever(autoreverses: true),
                    value: burgerBounce
                )
                .padding(10)
                .background(Circle().fill(Color.white.opacity(0.10)))
                .onAppear { burgerBounce = true }

            VStack(alignment: .leading, spacing: 4) {
                Text(headline)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(sub)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Corner.xl, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Corner.xl, style: .continuous)
                .stroke(Color.orange.opacity(0.5), lineWidth: 1.5)
        )
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
        DuoButton(
            fill: Color(red: 1.0, green: 0.55, blue: 0.10),
            foreground: .white,
            height: 62
        ) {
            guard let pkg = selectedPackage else { return }
            Task { await purchases.purchase(package: pkg) }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                if purchases.isLoading {
                    ProgressView().tint(.white)
                }
                Text(ctaTitle)
            }
        }
        .shadow(color: .orange.opacity(0.45), radius: 16, y: 6)
        .disabled(selectedPackage == nil || purchases.isLoading)
    }

    private var ctaTitle: String {
        guard let pkg = selectedPackage else { return Strings.Paywall.ctaFreeTrial }
        switch pkg.packageType {
        case .lifetime:
            return Strings.Paywall.ctaBuyLifetime
        case .annual, .monthly:
            // Always show the trial CTA for auto-renewable subs. StoreKit
            // sometimes returns `introductoryDiscount == nil` in sandbox
            // until Apple finishes reviewing the intro offer, but our ASC
            // config always attaches a 7-day free trial to both products.
            return Strings.Paywall.ctaFreeTrial
        default:
            return Strings.Paywall.ctaSubscribe
        }
    }

    private var secondaryActions: some View {
        VStack(spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.lg) {
                Button(Strings.Paywall.restorePurchases) {
                    Task { await purchases.restorePurchases() }
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            }

            HStack(spacing: DS.Spacing.md) {
                Link(
                    Strings.Paywall.termsOfUse,
                    destination: URL(string: "https://fit-scroll.app/terms")!
                )
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))

                Text("·").foregroundColor(.white.opacity(0.4))

                Link(
                    Strings.Paywall.privacyPolicy,
                    destination: URL(string: "https://fit-scroll.app/privacy")!
                )
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.top, DS.Spacing.sm)
    }

    private var legalFooter: some View {
        Text(Strings.Paywall.legalFooter)
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
        // Compact vertical card — plans sit side by side in a horizontal
        // scroll, so each card carries its full pitch top to bottom.
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 4)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.orange)
                    }
                }

                if isBestValue {
                    Text(Strings.Paywall.bestValue)
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.yellow)
                        .cornerRadius(4)
                }

                Spacer(minLength: 2)

                Text(package.storeProduct.localizedPriceString)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let perPeriod = pricePerPeriod {
                    Text(perPeriod)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }

                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DS.Spacing.md)
            .frame(width: 170, height: 178, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: DS.Corner.xl, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.16 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Corner.xl, style: .continuous)
                    .stroke(
                        isSelected ? Color.orange : Color.white.opacity(0.2),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private var title: String {
        switch package.packageType {
        case .annual:   return Strings.Paywall.planYearly
        case .monthly:  return Strings.Paywall.planMonthly
        case .lifetime: return Strings.Paywall.planLifetime
        default:        return package.storeProduct.localizedTitle
        }
    }

    private var subtitle: String {
        switch package.packageType {
        case .annual:
            return Strings.Paywall.planYearlySubtitle
        case .monthly:
            return Strings.Paywall.planMonthlySubtitle
        case .lifetime:
            return Strings.Paywall.planLifetimeSubtitle
        default:
            return ""
        }
    }

    private var pricePerPeriod: String? {
        switch package.packageType {
        case .annual:
            let product = package.storeProduct
            let monthly = (product.price as NSDecimalNumber).dividing(
                by: NSDecimalNumber(value: 12)
            )
            // Prefer RC's built-in priceFormatter — it's pre-configured with
            // the product's priceLocale so currency symbol + grouping match
            // the user's actual store region.
            if let formatter = product.priceFormatter,
               let localized = formatter.string(from: monthly) {
                return String(format: Strings.Paywall.pricePerMonthApproxFormat, localized)
            }
            // Fallback: manual NumberFormatter with currencyCode.
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            if let code = product.currencyCode {
                formatter.currencyCode = code
            }
            let localized = formatter.string(from: monthly)
                ?? "\(monthly.doubleValue)"
            return String(format: Strings.Paywall.pricePerMonthApproxFormat, localized)
        case .monthly:
            return Strings.Paywall.pricePerMonth
        case .lifetime:
            return Strings.Paywall.priceOneTime
        default:
            return nil
        }
    }
}
