import SwiftUI

// MARK: - Connect Wearable View
// Guides user through connecting supported wearables via Apple Health.

struct ConnectWearableView: View {

    @Environment(\.dismiss) private var dismiss

    var biometrics: BiometricStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    WearableHeaderCard()

                    DetectedSourcesCard(sources: biometrics.sourcesDetected)

                    AmazfitWalkthroughCard()

                    OtherWearablesCard()

                    HowItWorksCard()

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Connect Wearable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Header

struct WearableHeaderCard: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "2563EB").opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "applewatch.watchface")
                    .font(.system(size: 36))
                    .foregroundColor(Color(hex: "2563EB"))
            }
            Text("Wearable-agnostic")
                .font(.title3.bold())
            Text("Paya reads biometric data from any wearable that syncs to Apple Health — no app-specific integrations needed.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .payaCard(padding: 20)
    }
}

// MARK: - Detected Sources

struct DetectedSourcesCard: View {
    var sources: Set<BiometricSource>

    var sortedSources: [BiometricSource] {
        Array(sources).sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(Color(hex: "059669"))
                Text("Detected in Apple Health")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            if sortedSources.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    Text("No wearable data yet. Follow the walkthrough below to connect your device.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                VStack(spacing: 8) {
                    ForEach(sortedSources, id: \.self) { source in
                        HStack(spacing: 10) {
                            Image(systemName: source.icon)
                                .foregroundColor(Color(hex: "2563EB"))
                                .frame(width: 24)
                            Text(source.displayName)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundColor(Color(hex: "059669"))
                        }
                        .padding(10)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .payaCard(padding: 16)
    }
}

// MARK: - Amazfit Walkthrough

struct AmazfitWalkthroughCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "watch.analog")
                    .foregroundColor(Color(hex: "B45309"))
                Text("Amazfit / Zepp")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("3 steps")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 10) {
                WalkthroughStep(
                    number: 1,
                    title: "Open the Zepp app",
                    detail: "Make sure your watch is synced. If not installed, download 'Zepp' from the App Store."
                )
                WalkthroughStep(
                    number: 2,
                    title: "Go to Profile → Apps → Health",
                    detail: "Tap on Apple Health integration."
                )
                WalkthroughStep(
                    number: 3,
                    title: "Enable all data types",
                    detail: "Toggle every category ON — Paya works best with sleep, HR, HRV, and steps."
                )
            }

            Button {
                if let url = URL(string: "zepplife://") {
                    UIApplication.shared.open(url) { success in
                        if !success {
                            if let appstoreURL = URL(string: "https://apps.apple.com/app/id1495558352") {
                                UIApplication.shared.open(appstoreURL)
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.up.right.square.fill")
                    Text("Open Zepp app")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hex: "B45309"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .payaCard(padding: 16)
    }
}

struct WalkthroughStep: View {
    var number: Int
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(hex: "B45309").opacity(0.15))
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Color(hex: "B45309"))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
}

// MARK: - Other Wearables

struct OtherWearablesCard: View {

    private let wearables: [(BiometricSource, String)] = [
        (.fitbit, "Fitbit app → Settings → Apple Health"),
        (.whoop, "Set up automatically via WHOOP app"),
        (.oura, "Oura app → Settings → Integrations → Apple Health"),
        (.garmin, "Garmin Connect → Settings → Apple Health"),
        (.polar, "Polar Flow → Settings → Apple Health"),
        (.withings, "Withings app → Profile → Apple Health")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.walk")
                    .foregroundColor(Color(hex: "059669"))
                Text("Other wearables")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(wearables, id: \.0) { pair in
                    HStack(spacing: 10) {
                        Image(systemName: pair.0.icon)
                            .foregroundColor(Color(hex: "2563EB"))
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pair.0.displayName)
                                .font(.subheadline.weight(.semibold))
                            Text(pair.1)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .payaCard(padding: 16)
    }
}

// MARK: - How It Works

struct HowItWorksCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(Color(hex: "059669"))
                Text("How Paya uses your data")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                InfoBullet(
                    icon: "brain.head.profile",
                    text: "Paya learns your personal baseline over 14 days, then detects deviations that may signal an approaching flare."
                )
                InfoBullet(
                    icon: "iphone.and.arrow.forward",
                    text: "All processing happens on-device. Your biometrics never leave your iPhone."
                )
                InfoBullet(
                    icon: "waveform.path.ecg",
                    text: "The more you log, the smarter it gets. Flare-day tags help the model learn your unique pattern."
                )
            }
        }
        .payaCard(padding: 16)
    }
}

struct InfoBullet: View {
    var icon: String
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Color(hex: "2563EB"))
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
