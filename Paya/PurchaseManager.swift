import StoreKit
import SwiftUI
import CryptoKit

// MARK: - Paya Pro Purchase Manager
//
// Manages the single non-consumable "Paya Pro — Lifetime" IAP.
// Uses StoreKit 2 (async/await, StoreKit.Transaction.currentEntitlements).
//
// Freemium gating strategy:
//   FREE tier  → core workout tracking, basic nutrition logging,
//                HealthKit sync, body weight tracking, 30-day history
//   PRO tier   → AI coaching (Claude/Gemini), advanced analytics
//                (correlations, trends, preference learning),
//                unlimited history, daily routines, weekly digest,
//                progress photos, export data
//
// The $14.99 one-time model is a deliberate differentiator vs
// subscription-heavy competitors (Whoop $30/mo, Oura $6/mo).

@MainActor
@Observable
final class PurchaseManager {

    static let shared = PurchaseManager()

    // Product ID must match App Store Connect + Products.storekit
    static let proProductID = "com.paya.pro.lifetime"

    // MARK: State

    var isPro: Bool = false
    var product: Product? = nil
    var purchaseState: PurchaseState = .idle

    enum PurchaseState: Equatable {
        case idle
        case loading
        case purchasing
        case purchased
        case failed(String)
        case restored
    }

    // MARK: - Init

    private var updateTask: Task<Void, Never>? = nil

    init() {
        // Check saved state immediately for instant UI
        isPro = UserDefaults.standard.bool(forKey: "paya_is_pro")
    }

    /// Call once at app launch (e.g. in App.init or .task)
    func configure() async {
        // Load product
        await loadProduct()

        // Verify entitlements (the source of truth, overrides UserDefaults)
        await refreshEntitlements()

        // Listen for transaction updates (family sharing, refunds, etc.)
        updateTask = Task(priority: .background) { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await self.handleVerified(transaction)
                }
            }
        }
    }

    // MARK: - Load Product

    func loadProduct() async {
        purchaseState = .loading
        do {
            let products = try await Product.products(for: [Self.proProductID])
            product = products.first
            purchaseState = .idle
        } catch {
            purchaseState = .failed("Couldn't load products")
        }
    }

    // MARK: - Purchase

    func purchase() async {
        guard let product else {
            purchaseState = .failed("Product not available")
            return
        }

        purchaseState = .purchasing

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await handleVerified(transaction)
                    purchaseState = .purchased
                } else {
                    purchaseState = .failed("Purchase couldn't be verified")
                }

            case .userCancelled:
                purchaseState = .idle

            case .pending:
                // Ask to Buy (parental controls) or other pending state
                purchaseState = .idle

            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Restore

    func restore() async {
        purchaseState = .loading
        try? await AppStore.sync()
        await refreshEntitlements()
        purchaseState = isPro ? .restored : .idle
    }

    // MARK: - Entitlements

    private func refreshEntitlements() async {
        var foundPro = false

        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == Self.proProductID
                    && transaction.revocationDate == nil {
                    foundPro = true
                }
            }
        }

        isPro = foundPro
        UserDefaults.standard.set(foundPro, forKey: "paya_is_pro")
    }

    private func handleVerified(_ transaction: StoreKit.Transaction) async {
        if transaction.productID == Self.proProductID
            && transaction.revocationDate == nil {
            isPro = true
            UserDefaults.standard.set(true, forKey: "paya_is_pro")
        } else if transaction.productID == Self.proProductID
            && transaction.revocationDate != nil {
            // Refunded
            isPro = false
            UserDefaults.standard.set(false, forKey: "paya_is_pro")
        }

        await transaction.finish()
    }

    // MARK: - Promo Codes

    /// SHA-256 hashes of valid promo codes. Never store plaintext codes in the
    /// binary — anyone can run `strings` on the IPA. To add a new code:
    ///   1. Decide the code (e.g. "PAYA-LAUNCH-2026")
    ///   2. Normalize: uppercase, trim whitespace
    ///   3. Run: echo -n "PAYA-LAUNCH-2026" | shasum -a 256
    ///   4. Add the hash below
    private static let validPromoHashes: Set<String> = [
        // PAYA-REVIEW-2026
        "d123339e7d32c4fff8d645029e609b778bff3c9e49ad07a548b6e900370da7b9",
        // PAYA-BETA-VIP
        "78b25b5cab397eac742811d15affcd91b580dc5cab1462a9b021aa500c6aa272",
        // PAYA-PRESS-ACCESS
        "3bd9068c77015540946c229e90988395e00bdd58bb0f912d2b9ba2da22d692e5",
        // PAYA-EMIN-DEV
        "20ad2161a9d783549f22c033f1c89dcee594b27dbb4aedaad4afc9e3d298b433",
    ]

    private static func sha256(_ input: String) -> String {
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    /// Returns true if the code was valid and Pro was activated.
    @discardableResult
    func redeemPromoCode(_ code: String) -> Bool {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let hash = Self.sha256(normalized)
        if Self.validPromoHashes.contains(hash) {
            isPro = true
            UserDefaults.standard.set(true, forKey: "paya_is_pro")
            UserDefaults.standard.set(hash, forKey: "paya_promo_code_used")
            purchaseState = .purchased
            return true
        }
        return false
    }

    var wasPromoRedeemed: Bool {
        UserDefaults.standard.string(forKey: "paya_promo_code_used") != nil
    }

    // MARK: - Feature Gating

    /// Check if a specific premium feature is available.
    /// Use this throughout the app to gate pro features.
    static var isProUser: Bool {
        PurchaseManager.shared.isPro
    }
}

// MARK: - Pro Feature Gate Modifier

/// Usage: `.requiresPro()` on any card that should blur + show upgrade prompt for free users
struct ProGateModifier: ViewModifier {
    @State private var showPaywall = false
    let isPro: Bool

    func body(content: Content) -> some View {
        if isPro {
            content
        } else {
            content
                .blur(radius: 3)
                .allowsHitTesting(false)
                .overlay {
                    VStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "8B5CF6"))
                        Text("Pro feature")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "8B5CF6"))
                        Button {
                            showPaywall = true
                        } label: {
                            Text("Unlock")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 5)
                                .background(Color(hex: "8B5CF6"))
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .sheet(isPresented: $showPaywall) {
                    PaywallView()
                }
        }
    }
}

extension View {
    func requiresPro() -> some View {
        modifier(ProGateModifier(isPro: PurchaseManager.shared.isPro))
    }
}

// MARK: - Pro-Gated Wrapper

/// Replaces the content entirely with a compact upgrade prompt when not Pro.
/// Use for features that shouldn't even preview (export, doctor report).
struct ProGate<Content: View>: View {
    let featureName: String
    @ViewBuilder let content: () -> Content
    @State private var showPaywall = false

    var body: some View {
        if PurchaseManager.isProUser {
            content()
        } else {
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "8B5CF6"))
                    Text(featureName)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("PRO")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "8B5CF6"))
                        .clipShape(Capsule())
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}
