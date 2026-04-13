import Foundation
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

    /// Refreshes the current customer info from RevenueCat servers.
    func refreshCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            applyCustomerInfo(info)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Downloads the current offerings (products available to purchase).
    func fetchOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            self.offerings = offerings
        } catch {
            lastError = error.localizedDescription
        }
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
