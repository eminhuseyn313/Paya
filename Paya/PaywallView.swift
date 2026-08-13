import SwiftUI
import StoreKit

// MARK: - Paywall View
//
// Premium upgrade screen for Paya Pro — $14.99 one-time purchase.
// Designed to feel premium and honest, not manipulative.
// No dark patterns, no fake urgency, no countdown timers.
//
// Design references: Oura's clean upgrade flow, Whoop's feature
// comparison, Cal AI's benefit-first approach.

struct PaywallView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var purchaseManager = PurchaseManager.shared
    @State private var showRestoreAlert = false
    @State private var promoCode: String = ""
    @State private var promoError: Bool = false
    @State private var showPromoField: Bool = false

    private let features: [(icon: String, title: String, description: String, color: String)] = [
        ("brain.head.profile.fill", "AI coaching",
         "Personalized insights powered by Claude — nutrition advice, training recommendations, and weekly digests.",
         "8B5CF6"),
        ("chart.xyaxis.line", "Advanced analytics",
         "Correlations, trend analysis, exercise preference learning, and readiness scoring.",
         "2563EB"),
        ("infinity", "Unlimited history",
         "Access your full training, nutrition, and health history — no 30-day cap.",
         "059669"),
        ("checklist.checked", "Daily routines",
         "Context-aware reminders — sunscreen (UV-based), hydration, eye drops, and custom routines.",
         "F59E0B"),
        ("camera.fill", "Progress photos",
         "Track your physique changes with a private, on-device photo timeline.",
         "0891B2"),
        ("square.and.arrow.up", "Export data",
         "Export your logs as CSV for your coach, doctor, or personal records.",
         "B45309"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    // MARK: Hero
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "059669"), Color(hex: "0891B2")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)

                            Image(systemName: "star.fill")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 24)

                        Text("Paya Pro")
                            .font(.system(size: 28, weight: .bold))

                        Text("Unlock everything. Once, forever.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 28)

                    // MARK: Features
                    VStack(spacing: 0) {
                        ForEach(Array(features.enumerated()), id: \.offset) { idx, feature in
                            HStack(spacing: 14) {
                                Image(systemName: feature.icon)
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: feature.color))
                                    .frame(width: 40, height: 40)
                                    .background(Color(hex: feature.color).opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(feature.title)
                                        .font(.system(size: 15, weight: .semibold))
                                    Text(feature.description)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)

                            if idx < features.count - 1 {
                                Divider().padding(.leading, 70)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)

                    // MARK: Comparison
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "059669"))
                            Text("No subscription. No recurring charges.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "059669"))
                            Text("All data stays on your device — never sold or shared.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 20)

                    // MARK: Price + CTA
                    VStack(spacing: 12) {
                        if let product = purchaseManager.product {
                            Text(product.displayPrice)
                                .font(.system(size: 36, weight: .bold))
                            Text("one-time purchase")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .offset(y: -6)
                        } else {
                            Text("$14.99")
                                .font(.system(size: 36, weight: .bold))
                            Text("one-time purchase")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .offset(y: -6)
                        }

                        Button {
                            Task { await purchaseManager.purchase() }
                        } label: {
                            Group {
                                if purchaseManager.purchaseState == .purchasing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Upgrade to Pro")
                                        .font(.system(size: 17, weight: .bold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .foregroundColor(.white)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "059669"), Color(hex: "0891B2")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(purchaseManager.purchaseState == .purchasing)
                        .padding(.horizontal, 16)

                        // Error state
                        if case .failed(let message) = purchaseManager.purchaseState {
                            Text(message)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "DC2626"))
                                .multilineTextAlignment(.center)
                        }

                        // Promo code
                        if showPromoField {
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    TextField("Enter promo code", text: $promoCode)
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color(.tertiarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))

                                    Button {
                                        if purchaseManager.redeemPromoCode(promoCode) {
                                            promoError = false
                                        } else {
                                            promoError = true
                                            promoCode = ""
                                        }
                                    } label: {
                                        Text("Redeem")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(Color(hex: "8B5CF6"))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .disabled(promoCode.trimmingCharacters(in: .whitespaces).isEmpty)
                                }
                                .padding(.horizontal, 16)

                                if promoError {
                                    Text("Invalid promo code")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "DC2626"))
                                }
                            }
                            .padding(.top, 8)
                        }

                        // Restore + Promo + Legal
                        HStack(spacing: 16) {
                            Button("Restore purchase") {
                                Task { await purchaseManager.restore() }
                            }
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                            Text("·")
                                .foregroundColor(.secondary.opacity(0.5))

                            Button("Promo code") {
                                withAnimation { showPromoField.toggle() }
                            }
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                            Text("·")
                                .foregroundColor(.secondary.opacity(0.5))

                            Link("Privacy", destination: URL(string: "https://getpaya.app/privacy")!)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)

                            Text("·")
                                .foregroundColor(.secondary.opacity(0.5))

                            Link("Terms", destination: URL(string: "https://getpaya.app/terms")!)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
            }
            .alert("Purchase restored", isPresented: $showRestoreAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("Paya Pro has been restored on this device.")
            }
            .onChange(of: purchaseManager.purchaseState) { _, newState in
                if newState == .purchased || newState == .restored {
                    showRestoreAlert = true
                }
            }
        }
    }
}
