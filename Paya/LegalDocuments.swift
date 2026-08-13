import SwiftUI

// MARK: - Legal Documents
//
// Privacy Policy and Terms of Service for Paya.
// These are embedded in the app AND should be hosted at:
//   https://getpaya.app/privacy
//   https://getpaya.app/terms
//
// For App Store review, the in-app versions are the fallback.
// Apple requires these URLs in the App Store Connect listing.
//
// You MUST host these at the URLs above before submission.
// Easiest: a free GitHub Pages site or a simple Carrd page.

// MARK: - Privacy Policy

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        sectionHeader("Privacy policy")
                        Text("Last updated: August 9, 2026")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        bodyText("""
                        Paya ("we", "our", "the app") is a personal fitness and health tracking application. \
                        Your privacy is fundamental to how we build Paya. This policy explains what data we \
                        collect, how we use it, and the controls you have.
                        """)

                        sectionHeader("Data we collect")
                        bodyText("""
                        All data listed below is stored locally on your device using Apple's SwiftData framework. \
                        We do not operate servers that store your personal data.

                        • Health & fitness data — workouts, exercise logs, sets, reps, weights, body measurements, \
                        sleep data, heart rate, and steps (via Apple HealthKit with your permission).
                        • Nutrition data — meals, calories, macronutrients, and supplement schedules you enter.
                        • Profile information — name, age, height, weight, and fitness goals you provide during setup.
                        • Progress photos — photos you take within the app, stored only on your device.
                        • Location data — used solely to fetch local weather and UV index from Open-Meteo \
                        (a free, open-source weather API). Your coordinates are sent to Open-Meteo to retrieve \
                        weather data; we do not store or transmit your location elsewhere.
                        """)

                        sectionHeader("AI features")
                        bodyText("""
                        Paya offers optional AI-powered coaching and nutrition analysis. These features may use \
                        on-device Apple Intelligence (data never leaves your device) or cloud-based AI services \
                        (Anthropic Claude or Google Gemini) that require your own API key.

                        Cloud-based AI requires your explicit consent:
                        • You must enable "Allow External AI" in Settings before any data is sent to external AI services.
                        • When enabled, fitness and nutrition context is sent to the AI provider you configured.
                        • We do not store, log, or have access to your API keys — they are saved in your \
                        device's secure Keychain.
                        • The AI provider's own privacy policy governs how they handle your data. We encourage \
                        you to review Anthropic's (anthropic.com/privacy) or Google's (ai.google/privacy) \
                        privacy policies.
                        • You can revoke consent at any time by disabling "Allow External AI" in Settings.
                        • You can use Paya fully without cloud AI — on-device Apple Intelligence and all \
                        non-AI features work without this consent.
                        """)

                        sectionHeader("Third-party services")
                        bodyText("""
                        Paya connects to the following external services:

                        • Open-Meteo (open-meteo.com) — weather and UV data. Your approximate location is sent \
                        to retrieve local conditions. Open-Meteo is open-source and does not track users.
                        • OpenFoodFacts (openfoodfacts.org) — barcode lookup for nutrition data. Only the \
                        barcode number is sent.
                        • Anthropic / Google Gemini — AI features, only when you provide your own API key.
                        • GitHub raw content — exercise demonstration images.

                        We do not use any analytics SDKs, advertising networks, crash reporting services, \
                        or tracking pixels.
                        """)
                    }

                    Group {
                        sectionHeader("Apple HealthKit")
                        bodyText("""
                        Paya reads and writes health data through Apple HealthKit with your explicit permission. \
                        We read: steps, heart rate, sleep analysis, body weight, active energy, and workout data. \
                        We write: body weight entries and completed workouts. HealthKit data is never shared with \
                        third parties, used for advertising, or transmitted off your device (except when you \
                        explicitly use AI features on that data).
                        """)

                        sectionHeader("Data storage and security")
                        bodyText("""
                        • All personal data is stored locally on your device.
                        • API keys are stored in the iOS Keychain (hardware-encrypted).
                        • All network communication uses HTTPS (TLS 1.2+).
                        • We do not have a backend server — there is nothing to breach.
                        • Deleting the app removes all Paya data from your device.
                        """)

                        sectionHeader("Data sharing")
                        bodyText("""
                        We do not sell, rent, or share your personal data with anyone. Period.
                        """)

                        sectionHeader("Children's privacy")
                        bodyText("""
                        Paya is not directed at children under 13. We do not knowingly collect data from children.
                        """)

                        sectionHeader("Your rights")
                        bodyText("""
                        Since all data is stored on your device, you have full control:
                        • View all your data within the app at any time.
                        • Delete any or all data by removing entries or uninstalling the app.
                        • Revoke HealthKit permissions in Settings → Privacy → Health.
                        • Remove API keys from Settings within the app.
                        """)

                        sectionHeader("Changes to this policy")
                        bodyText("""
                        We may update this policy as the app evolves. Changes will be noted in the app's \
                        update release notes.
                        """)

                        sectionHeader("Contact")
                        bodyText("""
                        For privacy questions: eminhuseyn313@gmail.com
                        """)
                    }
                }
                .padding()
            }
            .navigationTitle("Privacy policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .bold))
            .padding(.top, 8)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Terms of Service

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        sectionHeader("Terms of service")
                        Text("Last updated: August 9, 2026")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        bodyText("""
                        By using Paya ("the app"), you agree to these terms. If you do not agree, \
                        please do not use the app.
                        """)

                        sectionHeader("1. Description of service")
                        bodyText("""
                        Paya is a personal fitness and health tracking application for iOS. It provides \
                        workout logging, nutrition tracking, health data visualization, and optional \
                        AI-powered coaching features.
                        """)

                        sectionHeader("2. Not medical advice")
                        bodyText("""
                        Paya is a fitness tracking tool, not a medical device. Nothing in the app \
                        constitutes medical advice, diagnosis, or treatment. Always consult a qualified \
                        healthcare professional before starting any exercise program or making dietary \
                        changes. The AI coaching feature provides general fitness suggestions only.
                        """)

                        sectionHeader("3. In-app purchase")
                        bodyText("""
                        Paya offers a one-time "Paya Pro" purchase that unlocks premium features. \
                        This is a non-consumable purchase — you pay once and keep access forever, \
                        including across device transfers and family sharing. Purchases are processed \
                        by Apple and subject to Apple's refund policies.
                        """)

                        sectionHeader("4. AI features and API keys")
                        bodyText("""
                        Certain features require you to provide your own API key from Anthropic or \
                        Google. You are responsible for:
                        • Obtaining and paying for your own API key.
                        • Complying with the API provider's terms of service.
                        • Any costs incurred from API usage through the app.
                        We do not provide API keys or subsidize API costs.
                        """)
                    }

                    Group {
                        sectionHeader("5. User data")
                        bodyText("""
                        You own all data you enter into Paya. We do not claim any rights to your \
                        personal data, workout logs, photos, or any other content you create.
                        """)

                        sectionHeader("6. Acceptable use")
                        bodyText("""
                        You agree not to reverse engineer, decompile, or disassemble the app, or \
                        use it in any way that violates applicable laws.
                        """)

                        sectionHeader("7. Disclaimer of warranties")
                        bodyText("""
                        Paya is provided "as is" without warranties of any kind. We do not guarantee \
                        that the app will be error-free, uninterrupted, or that fitness results will \
                        be achieved. Exercise data, calorie estimates, and AI suggestions are \
                        approximations and should not be relied upon as precise measurements.
                        """)

                        sectionHeader("8. Limitation of liability")
                        bodyText("""
                        To the maximum extent permitted by law, we shall not be liable for any \
                        indirect, incidental, or consequential damages arising from your use of the \
                        app, including but not limited to injury from exercise, dietary changes, or \
                        reliance on AI-generated advice.
                        """)

                        sectionHeader("9. Changes to terms")
                        bodyText("""
                        We may update these terms as the app evolves. Continued use after changes \
                        constitutes acceptance.
                        """)

                        sectionHeader("10. Contact")
                        bodyText("""
                        Questions about these terms: eminhuseyn313@gmail.com
                        """)
                    }
                }
                .padding()
            }
            .navigationTitle("Terms of service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .bold))
            .padding(.top, 8)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
