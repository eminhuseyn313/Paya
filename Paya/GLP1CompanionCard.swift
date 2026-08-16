import SwiftUI
import SwiftData

// MARK: - GLP-1 Companion Mode
//
// Companion tracker for users on GLP-1 receptor agonists (Ozempic,
// Wegovy, Mounjaro, Zepbound). Adjusts protein targets upward,
// tracks injection schedule, and logs GLP-1-specific side effects.
//
// Why this belongs in a fitness app:
// - Cal AI acquired $40M+ specifically to add GLP-1 support
// - 15M+ Americans on GLP-1 meds in 2025 (KFF estimate)
// - Muscle loss is the #1 concern — GLP-1 users lose ~40% lean mass
//   without resistance training (Wilding et al. 2021, NEJM STEP 1)
// - Protein target rises to 1.2-1.6 g/kg/day on GLP-1 vs 0.8-1.2
//   (Heymsfield et al. 2024, Obesity)
//
// Privacy: zero cloud. Injection dates stored locally in UserDefaults.

struct GLP1CompanionCard: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var isEnabled: Bool = UserDefaults.standard.bool(forKey: "glp1_enabled")
    @State private var medication: GLP1Medication = GLP1Medication(rawValue: UserDefaults.standard.string(forKey: "glp1_medication") ?? "") ?? .ozempic
    @State private var lastInjectionDate: Date? = {
        let ts = UserDefaults.standard.double(forKey: "glp1_last_injection")
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }()
    @State private var injectionDay: Int = UserDefaults.standard.integer(forKey: "glp1_injection_day") // weekday 1-7
    @State private var showSetup = false
    @State private var sideEffects: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "glp1_side_effects_today") ?? [])

    var body: some View {
        if isEnabled {
            activeCard
        } else {
            setupPrompt
        }
    }

    // MARK: - Active Card

    private var activeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "syringe.fill")
                    .foregroundColor(Pulse.recovery)
                    .font(.system(size: 12))
                Text("GLP-1 Companion")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(medication.displayName)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Pulse.recovery)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Pulse.recovery.opacity(0.1))
                    .clipShape(Capsule())
            }

            // Injection tracker
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if let last = lastInjectionDate {
                        let daysSince = Calendar.current.dateComponents([.day], from: last, to: .now).day ?? 0
                        let daysUntilNext = max(0, 7 - daysSince)

                        HStack(spacing: 4) {
                            Image(systemName: daysSince <= 7 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(daysSince <= 7 ? Pulse.positive : Pulse.critical)
                                .font(.system(size: 12))
                            Text(daysSince <= 1 ? "Injected today" : "\(daysSince) days since injection")
                                .font(.caption.weight(.semibold))
                        }

                        if daysUntilNext > 0 {
                            Text("Next dose in \(daysUntilNext) day\(daysUntilNext == 1 ? "" : "s")")
                                .font(.system(size: 10))
                                .foregroundColor(Pulse.textTertiary)
                        } else {
                            Text("Injection due today")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Pulse.critical)
                        }
                    } else {
                        Text("No injection logged yet")
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                    }
                }
                Spacer()

                Button {
                    lastInjectionDate = .now
                    UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: "glp1_last_injection")
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "syringe.fill")
                            .font(.system(size: 14))
                        Text("Log dose")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Pulse.recovery)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Adjusted protein target
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Pulse.positive)
                    Text("Adjusted protein target")
                        .font(.caption.weight(.semibold))
                }

                let bodyWeightKg = appState.profile.currentWeightKg
                let standardTarget = Int(bodyWeightKg * 1.0)
                let glp1Target = Int(bodyWeightKg * 1.4)  // 1.2-1.6 g/kg (Heymsfield 2024)

                Text("\(glp1Target)g/day (was \(standardTarget)g)")
                    .font(.system(size: 11))

                Text("GLP-1 users need 1.2-1.6 g/kg protein to preserve lean mass during weight loss (Heymsfield et al. 2024)")
                    .font(.system(size: 9))
                    .foregroundColor(Pulse.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Side effect logging
            VStack(alignment: .leading, spacing: 6) {
                Text("TODAY'S SIDE EFFECTS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Pulse.textTertiary)

                FlowLayout(spacing: 6) {
                    ForEach(GLP1SideEffect.allCases) { effect in
                        let isOn = sideEffects.contains(effect.rawValue)
                        Button {
                            if isOn {
                                sideEffects.remove(effect.rawValue)
                            } else {
                                sideEffects.insert(effect.rawValue)
                            }
                            UserDefaults.standard.set(Array(sideEffects), forKey: "glp1_side_effects_today")
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(spacing: 3) {
                                Text(effect.emoji)
                                    .font(.system(size: 10))
                                Text(effect.label)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(isOn ? Pulse.critical.opacity(0.15) : Pulse.surfaceElevatedFallback)
                            .foregroundStyle(isOn ? Pulse.critical : .primary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PulsePress())
                    }
                }
            }

            // Muscle preservation alert
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Pulse.nutrition)
                    .padding(.top, 1)
                Text("Without resistance training, ~40% of GLP-1 weight loss is lean mass (Wilding 2021 STEP 1). Keep training to preserve muscle.")
                    .font(.system(size: 9))
                    .foregroundColor(Pulse.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Disable
            Button {
                withAnimation {
                    isEnabled = false
                    UserDefaults.standard.set(false, forKey: "glp1_enabled")
                }
            } label: {
                Text("Turn off GLP-1 mode")
                    .font(.system(size: 10))
                    .foregroundColor(Pulse.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .payaCard(padding: 14)
    }

    // MARK: - Setup Prompt

    private var setupPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "syringe.fill")
                    .foregroundColor(Pulse.recovery)
                    .font(.system(size: 12))
                Text("GLP-1 Companion")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            Text("On Ozempic, Wegovy, Mounjaro, or Zepbound? Enable GLP-1 mode to track injections, adjust protein targets for lean mass preservation, and log side effects.")
                .font(.system(size: 10))
                .foregroundColor(Pulse.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(GLP1Medication.allCases) { med in
                    Button {
                        medication = med
                        isEnabled = true
                        UserDefaults.standard.set(true, forKey: "glp1_enabled")
                        UserDefaults.standard.set(med.rawValue, forKey: "glp1_medication")
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Text(med.displayName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Pulse.recovery)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Pulse.recovery.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PulsePress())
                }
            }
        }
        .payaCard(padding: 14)
    }
}

// MARK: - Data Types

enum GLP1Medication: String, CaseIterable, Identifiable {
    case ozempic, wegovy, mounjaro, zepbound

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ozempic: return "Ozempic"
        case .wegovy: return "Wegovy"
        case .mounjaro: return "Mounjaro"
        case .zepbound: return "Zepbound"
        }
    }
}

enum GLP1SideEffect: String, CaseIterable, Identifiable {
    case nausea, fatigue, constipation, headache, dizziness, appetite_loss, bloating

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nausea: return "Nausea"
        case .fatigue: return "Fatigue"
        case .constipation: return "Constipation"
        case .headache: return "Headache"
        case .dizziness: return "Dizziness"
        case .appetite_loss: return "No appetite"
        case .bloating: return "Bloating"
        }
    }

    var emoji: String {
        switch self {
        case .nausea: return "🤢"
        case .fatigue: return "😴"
        case .constipation: return "😣"
        case .headache: return "🤕"
        case .dizziness: return "💫"
        case .appetite_loss: return "🚫"
        case .bloating: return "🫃"
        }
    }
}
