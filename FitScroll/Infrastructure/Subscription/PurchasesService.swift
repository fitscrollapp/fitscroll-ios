import Foundation
import CryptoKit
import RevenueCat
import Combine

/// Central wrapper around the RevenueCat SDK.
///
/// - Observes the `premium` entitlement so the rest of the app can read
///   `isSubscribed` / `isTrialing` as published state.
/// - Fetches the current `Offerings` for the paywall.
/// - Exposes `purchase(package:)` and `restorePurchases()` with loading +
///   error state that the UI can bind directly.
@MainActor
final class PurchasesService: ObservableObject {
    static let shared = PurchasesService()

    /// Entitlement lookup key configured in RevenueCat dashboard. All paid
    /// products (monthly / yearly / lifetime) grant this entitlement.
    static let premiumEntitlement = "premium"

    /// Public Apple API key from RevenueCat → Project Settings → API Keys.
    /// Safe to ship in-bundle because public keys only grant read access.
    private static let apiKey = "appl_GqfPEKHhqzKNSjBWVCkIHiRdVEB"

    @Published private(set) var isSubscribed: Bool = false
    @Published private(set) var isTrialing: Bool = false
    @Published private(set) var offerings: Offerings?
    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var lastError: String?
    @Published private(set) var isLoading: Bool = false
    /// Intro-offer (free trial) eligibility per product identifier, fetched
    /// alongside offerings. The paywall CTA must not promise a trial unless
    /// the store will actually grant one.
    @Published private(set) var introEligibility: [String: IntroEligibility] = [:]
    /// First eligible App Store win-back offer for a lapsed subscriber,
    /// paired with the package it belongs to. iOS 18+ only; nil otherwise.
    @Published private(set) var winBack: (package: Package, offer: WinBackOffer)?

    private init() {}

    /// Configure RevenueCat SDK. Call once at app launch, after Firebase.
    func configure() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Self.apiKey)

        Task {
            await refreshCustomerInfo()
            await fetchOfferings()
        }
    }

    /// Bridge the AppsFlyer install id into RevenueCat so subscription
    /// events (trial, purchase, renewal) are forwarded to AppsFlyer → TikTok
    /// against the same user. Call after AppsFlyer is configured.
    func setAppsflyerID(_ id: String?) {
        Purchases.shared.attribution.setAppsflyerID(id)
    }

    /// Refreshes the current customer info from RevenueCat servers.
    func refreshCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            applyCustomerInfo(info)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Downloads the current offerings (products available to purchase) and
    /// the trial eligibility for each contained product.
    func fetchOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            self.offerings = offerings

            let ids = (offerings.current?.availablePackages ?? [])
                .map { $0.storeProduct.productIdentifier }
            if !ids.isEmpty {
                introEligibility = await Purchases.shared
                    .checkTrialOrIntroDiscountEligibility(productIdentifiers: ids)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// True when the store will grant the package's introductory offer
    /// (e.g. 7-day free trial) to this user. `.unknown` counts as not
    /// eligible so the CTA never over-promises.
    func isEligibleForTrial(_ package: Package) -> Bool {
        guard package.storeProduct.introductoryDiscount != nil else { return false }
        let status = introEligibility[package.storeProduct.productIdentifier]?.status
        return status == .eligible
    }

    /// A user who held the premium entitlement before but no longer does —
    /// the win-back audience.
    var isLapsedSubscriber: Bool {
        guard let ent = customerInfo?.entitlements.all[Self.premiumEntitlement] else { return false }
        return !ent.isActive
    }

    /// Looks up App Store win-back offers for lapsed subscribers. Annual is
    /// checked first (higher value), then monthly. No-op below iOS 18.
    func refreshWinBackOffers() async {
        guard #available(iOS 18.0, *), isLapsedSubscriber, !isSubscribed else {
            winBack = nil
            return
        }
        let packages = (offerings?.current?.availablePackages ?? [])
            .filter { $0.packageType == .annual || $0.packageType == .monthly }
            .sorted { $0.packageType == .annual && $1.packageType != .annual }
        for package in packages {
            if let offer = try? await Purchases.shared
                .eligibleWinBackOffers(forPackage: package).first {
                winBack = (package, offer)
                return
            }
        }
        winBack = nil
    }

    /// Purchases the given package applying an App Store win-back offer.
    @available(iOS 18.0, *)
    func purchase(package: Package, winBackOffer: WinBackOffer) async {
        isLoading = true
        defer { isLoading = false }
        lastError = nil

        do {
            let params = PurchaseParams.Builder(package: package)
                .with(winBackOffer: winBackOffer)
                .build()
            let result = try await Purchases.shared.purchase(params)
            if result.userCancelled { return }
            applyCustomerInfo(result.customerInfo)
            winBack = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Attaches the backend identity as subscriber attributes so RevenueCat
    /// webhooks can be joined against `users.device_id` (which stores
    /// `"device:" + base64raw(sha256(X-Device-Id))`).
    func setBackendIdentity(deviceID: String, username: String?) {
        let hash = SHA256.hash(data: Data(deviceID.utf8))
        let key = "device:" + Data(hash).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        var attrs = ["backend_device_key": key]
        if let username { attrs["backend_username"] = username }
        Purchases.shared.attribution.setAttributes(attrs)
    }

    /// Executes a purchase for the given package. No-op if user cancels.
    func purchase(package: Package) async {
        isLoading = true
        defer { isLoading = false }
        lastError = nil

        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return }
            applyCustomerInfo(result.customerInfo)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Restores previous purchases (required for App Store review).
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        lastError = nil

        do {
            let info = try await Purchases.shared.restorePurchases()
            applyCustomerInfo(info)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func applyCustomerInfo(_ info: CustomerInfo) {
        customerInfo = info
        let entitlement = info.entitlements[Self.premiumEntitlement]
        isSubscribed = entitlement?.isActive ?? false
        isTrialing = entitlement?.periodType == .trial
    }
}
