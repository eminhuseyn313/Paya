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
                        Text("Last updated: November 15, 2026")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Link("Read the latest version online", destination: URL(string: "https://eminhuseyn313.github.io/Paya/privacy")!)
                            .font(.caption.weight(.semibold))

                        bodyText("""
                        Paya ("we", "our", "the app") is a personal fitness and health tracking application. \
                        Your privacy is fundamental to how we build Paya. This policy explains what data we \
                        collect, how we use it, and the controls you have.
                        """)

                        sectionHeader("Data we collect")
                        bodyText("""
                        Your data is stored on your device using Apple's SwiftData framework. If you create an \
                        account, a backup copy is also stored in our cloud database (Supabase) so you can restore \
                        it on a new device. You can use Paya without an account.

                        • Account — your email address or Sign in with Apple identifier.

                        • Health & fitness data — workouts, exercise logs, sets, reps, weights, body measurements, \
                        sleep data, heart rate, and steps (via Apple HealthKit with your permission).
                        • Nutrition data — meals, calories, macronutrients, and supplement schedules you enter.
                        • Profile information — name, age, height, weight, and fitness goals you provide during setup.
                        • Progress photos — stay on your device.
                        • Location data — used to fetch local weather, UV, air quality, pollen and pressure \
                        (Open-Meteo) and, if you opt in, background air-quality alerts. Coordinates are sent to \
                        those services; we do not store your location history.
                        """)

                        sectionHeader("AI features")
                        bodyText("""
                        This version of Paya does not send your data to any AI service. If AI features \
                        are added in a future version, we will update this policy and ask for your \
                        explicit consent before any data is sent.
                        """)

                        sectionHeader("Third-party services")
                        bodyText("""
                        Paya connects to the following external services:

                        • Open-Meteo (open-meteo.com) — weather and UV data. Your approximate location is sent \
                        to retrieve local conditions. Open-Meteo is open-source and does not track users.
                        • OpenFoodFacts (openfoodfacts.org) — barcode lookup for nutrition data. Only the \
                        barcode number is sent.
                        • USDA FoodData Central — food search text. OpenStreetMap — place lookups.
                        • Supabase — account authentication and cloud backup.
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
                        • Data is stored on your device; signed-in accounts also keep an encrypted cloud backup \
                        protected by per-account row-level security.
                        • Sign-in tokens and API keys are stored in the iOS Keychain.
                        • All network communication uses HTTPS (TLS).
                        • Deleting the app removes local data. Deleting your account (Settings) permanently \
                        removes your cloud data.
                        """)

                        sectionHeader("Data sharing")
                        bodyText("""
                        We do not sell or rent your personal data and use no advertising or analytics SDKs. Data goes only to the service providers needed for features you use (Supabase for your account backup; Open-Meteo, OpenFoodFacts and USDA for lookups).
                        """)

                        sectionHeader("Children's privacy")
                        bodyText("""
                        Paya is not directed at children under 16. We do not knowingly collect data from children.
                        """)

                        sectionHeader("Your rights")
                        bodyText("""
                        • View and edit your data within the app at any time.
                        • Delete entries, or delete your account in Settings (permanent, immediate).
                        • Request access, export or deletion by email; EEA/UK users also have portability, \
                        objection and complaint rights.
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
            .font(.pulse(size: 17, weight: .bold))
            .padding(.top, 8)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.pulse(size: 14))
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
                        Text("Last updated: November 15, 2026")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Link("Read the latest version online", destination: URL(string: "https://eminhuseyn313.github.io/Paya/terms")!)
                            .font(.caption.weight(.semibold))

                        bodyText("""
                        By using Paya ("the app"), you agree to these terms. If you do not agree, \
                        please do not use the app.
                        """)

                        sectionHeader("1. Description of service")
                        bodyText("""
                        Paya is a personal fitness and health tracking application for iOS. It provides \
                        workout logging, nutrition tracking, health data visualization, and \
                        personalized insights.
                        """)

                        sectionHeader("Paya Pro (one-time purchase)")
                        bodyText("""
                        Paya Pro is a one-time, non-consumable purchase through the Apple App Store. \
                        It is not a subscription and never renews. Payment is charged to your Apple ID. \
                        You can restore a previous purchase from Settings. Refunds are handled by Apple. \
                        Apple's Standard End User License Agreement also applies to your use of the app.
                        """)

                        sectionHeader("2. Not medical advice")
                        bodyText("""
                        Paya is a fitness tracking tool, not a medical device. Nothing in the app \
                        constitutes medical advice, diagnosis, or treatment. Always consult a qualified \
                        healthcare professional before starting any exercise program or making dietary \
                        changes.
                        """)

                        sectionHeader("3. In-app purchase")
                        bodyText("""
                        Paya offers a one-time "Paya Pro" purchase that unlocks premium features. \
                        This is a non-consumable purchase — you pay once and keep access forever, \
                        including across device transfers and family sharing. Purchases are processed \
                        by Apple and subject to Apple's refund policies.
                        """)

                        sectionHeader("4. AI features")
                        bodyText("""
                        This version of Paya does not send your data to any AI service. If AI features \
                        are added in a future version, we will update these terms and our Privacy \
                        Policy and ask for your explicit consent first.
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
                        reliance on in-app suggestions.
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
            .font(.pulse(size: 17, weight: .bold))
            .padding(.top, 8)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.pulse(size: 14))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
