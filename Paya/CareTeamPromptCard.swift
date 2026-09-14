import SwiftUI
import SwiftData

// MARK: - Care Team Prompt
//
// DoctorReportEngine/DoctorReportView already exist and produce a real,
// well-built PDF — but were entirely manual, buried in Settings, so using
// them required already remembering they exist AND thinking to check
// Settings specifically after a rough stretch, which is exactly when
// someone is least likely to go digging through app settings. This
// surfaces the same report proactively when the data itself suggests it's
// worth having ready for an appointment.

enum CareTeamPromptDetector {
    /// 3+ flare days in the trailing 14 — a threshold with no clinical
    /// citation behind it (there's no published "how many flare days
    /// justifies a doctor visit" rule); picked as a conservative,
    /// noticeable-but-not-hair-trigger bar, adjustable here if real usage
    /// suggests it fires too often or too rarely.
    static func roughStretchDetected(context: ModelContext) -> Bool {
        let pid = ActiveProfile.id
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        let descriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> { $0.profileId == pid && $0.date >= cutoff }
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        return logs.filter(\.isFlareDay).count >= 3
    }

    private static let lastPromptKey = "care_team_prompt_last_shown"
    private static let suppressWinddowDays = 14

    static func shouldShowPrompt(context: ModelContext) -> Bool {
        guard roughStretchDetected(context: context) else { return false }
        if let last = UserDefaults.standard.object(forKey: lastPromptKey) as? Date {
            let daysSince = Calendar.current.dateComponents([.day], from: last, to: .now).day ?? 0
            guard daysSince >= suppressWinddowDays else { return false }
        }
        return true
    }

    static func markShown() {
        UserDefaults.standard.set(Date(), forKey: lastPromptKey)
    }
}

struct CareTeamPromptCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showReport = false
    @State private var dismissed = false

    var body: some View {
        if !dismissed && CareTeamPromptDetector.shouldShowPrompt(context: modelContext) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Pulse.warning.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Pulse.warning)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("A rough couple of weeks")
                        .font(.system(size: 13, weight: .bold))
                    Text("Several flare days recently — want a doctor-ready summary of what's been happening, in case it's worth bringing to an appointment?")
                        .font(.system(size: 11.5))
                        .foregroundColor(Pulse.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        showReport = true
                        CareTeamPromptDetector.markShown()
                    } label: {
                        Text("Generate report")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Pulse.warning)
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
                Button {
                    dismissed = true
                    CareTeamPromptDetector.markShown()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Pulse.textTertiary)
                }
            }
            .payaCard(padding: 14)
            .sheet(isPresented: $showReport) {
                DoctorReportView()
            }
        }
    }
}
