import SwiftUI
import SwiftData

// MARK: - Weekly Body Map
//
// The per-session Muscle Map (BodyHeatmapCard) shows one workout's effort.
// This is the same body silhouette driven by a different, complementary
// signal: VolumeLandmarkEngine's weekly hard-sets-per-muscle against
// published MEV/MAV/MRV landmarks — so instead of "how hard did I push
// today," this answers "what's been neglected or overdone across the whole
// week," the two questions a real training log should answer together.
// Also overlays the most recent Mobility Check-In and today's logged joint
// pain as small warning dots — genuinely correlating three systems that
// existed separately (volume tracking, mobility screening, symptom
// logging) onto one picture instead of three disconnected screens.

struct WeeklyBodyMapCard: View {
    var sessions: [TrainingSession]

    @Environment(\.modelContext) private var modelContext
    @State private var latestMobility: MobilityCheckIn? = nil
    @State private var todaysPain: Int? = nil

    private var volumes: [VolumeLandmarkEngine.MuscleVolume] {
        VolumeLandmarkEngine.weeklyVolume(sessions: sessions)
    }

    private var regionColors: [BodyRegion: Color] {
        var result: [BodyRegion: Color] = [:]
        for mv in volumes {
            for region in MuscleActivationEngine.regions(for: mv.muscleGroup) {
                result[region] = Color(hex: mv.zone.colorHex)
            }
        }
        return result
    }

    /// Regions to flag with a warning dot — a mobility score of 1 (tight)
    /// on shoulders/hips, or logged joint pain today. Deliberately narrow:
    /// this is a nudge to look closer, not a diagnosis.
    private var flaggedRegions: Set<BodyRegion> {
        var flagged: Set<BodyRegion> = []
        if let mobility = latestMobility {
            if mobility.shoulderScore == 1 { flagged.formUnion([.frontDelts, .rearDelts]) }
            if mobility.hipScore == 1 { flagged.formUnion([.glutes, .hamstrings]) }
        }
        if let pain = todaysPain, pain >= 6 {
            flagged.formUnion([.frontDelts, .rearDelts])
        }
        return flagged
    }

    var body: some View {
        if !volumes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundColor(Pulse.hydration)
                    Text("Weekly Body Map")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Pulse.textPrimary)
                    CardInfoButton(
                        title: "Weekly Body Map",
                        explanation: "Each region colored by hard sets this week against published volume landmarks (MEV/MAV/MRV — Israetel/RP framework): gray = under minimum, green = growing zone, orange = high, red = excessive. Small warning dots mark regions flagged by your latest mobility check-in or today's joint pain log — a reason to look closer, not a diagnosis."
                    )
                    Spacer()
                }

                HStack(spacing: 24) {
                    Spacer()
                    VStack(spacing: 4) {
                        ZStack {
                            BodyFigureView(isFront: true, regionColors: regionColors)
                                .frame(maxWidth: 140)
                            warningOverlay(isFront: true)
                        }
                        Text("Front").font(.caption2).foregroundColor(Pulse.textTertiary)
                    }
                    VStack(spacing: 4) {
                        ZStack {
                            BodyFigureView(isFront: false, regionColors: regionColors)
                                .frame(maxWidth: 140)
                            warningOverlay(isFront: false)
                        }
                        Text("Back").font(.caption2).foregroundColor(Pulse.textTertiary)
                    }
                    Spacer()
                }

                HStack(spacing: 8) {
                    legendDot("9CA3AF", "Under")
                    legendDot("059669", "Growing")
                    legendDot("D97706", "High")
                    legendDot("DC2626", "Excessive")
                }

                if !flaggedRegions.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(Pulse.warning)
                        Text("Flagged by your mobility check-in or today's joint pain log — worth an easier day for that area.")
                            .font(.caption2)
                            .foregroundColor(Pulse.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .payaCard(padding: 14)
            .onAppear { load() }
        }
    }

    @ViewBuilder
    private func warningOverlay(isFront: Bool) -> some View {
        let positions: [(BodyRegion, CGPoint)] = isFront
            ? [(.frontDelts, CGPoint(x: 48, y: 56)), (.frontDelts, CGPoint(x: 112, y: 56))]
            : [(.rearDelts, CGPoint(x: 48, y: 56)), (.rearDelts, CGPoint(x: 112, y: 56)),
               (.glutes, CGPoint(x: 80, y: 148)), (.hamstrings, CGPoint(x: 62, y: 190)), (.hamstrings, CGPoint(x: 98, y: 190))]

        GeometryReader { geo in
            let sx = geo.size.width / 160
            let sy = geo.size.height / 340
            ForEach(Array(positions.enumerated()), id: \.offset) { _, pair in
                if flaggedRegions.contains(pair.0) {
                    Circle()
                        .fill(Pulse.warning)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(.white, lineWidth: 1))
                        .position(x: pair.1.x * sx, y: pair.1.y * sy)
                }
            }
        }
    }

    private func legendDot(_ hex: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(Color(hex: hex)).frame(width: 6, height: 6)
            Text(label).font(.system(size: 9)).foregroundColor(Pulse.textTertiary)
        }
    }

    private func load() {
        latestMobility = MobilityStore.recent(daysBack: 3, context: modelContext).last
        let pid = ActiveProfile.id
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let predicate = #Predicate<HealthLog> { $0.date >= startOfDay && $0.profileId == pid }
        let descriptor = FetchDescriptor<HealthLog>(predicate: predicate)
        let logs = (try? modelContext.fetch(descriptor)) ?? []
        todaysPain = logs.first?.jointPainLevel
    }
}
