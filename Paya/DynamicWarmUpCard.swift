import SwiftUI
import SwiftData

// MARK: - Dynamic Warm-Up Generator
// Auto-generates a targeted warm-up based on today's planned exercises.
// Instead of a generic "5 min on the treadmill", this card shows
// specific activation and mobility drills for the exact muscles about
// to be trained.
//
// Grounded in:
// - Fradkin et al. (2010) meta-analysis: warm-ups reduce injury risk
//   in 3 of 5 activities studied, with targeted protocols outperforming
//   generic ones.
// - McCrary et al. (2015): dynamic warm-ups improve acute power output
//   3-5% vs static stretching.
// - Behm & Chaouachi (2011): dynamic stretching + activation drills
//   are superior to static stretching pre-resistance training.
//
// The warm-up is derived from the muscle groups in today's session
// exercises, using a lookup table of evidence-based drills per group.

// MARK: - Warm-Up Drill Data

struct WarmUpDrill: Identifiable {
    let id = UUID()
    let name: String
    let sets: String       // e.g. "2×10"
    let muscleTarget: String
    let icon: String
    let type: DrillType

    enum DrillType: String {
        case activation = "Activation"
        case mobility = "Mobility"
        case dynamic = "Dynamic"
    }
}

private let drillDatabase: [String: [WarmUpDrill]] = [
    "chest": [
        WarmUpDrill(name: "Band pull-aparts", sets: "2×15", muscleTarget: "Chest/Shoulders", icon: "figure.flexibility", type: .activation),
        WarmUpDrill(name: "Arm circles", sets: "2×10 each", muscleTarget: "Shoulder girdle", icon: "arrow.triangle.2.circlepath", type: .dynamic),
        WarmUpDrill(name: "Light push-ups", sets: "1×10", muscleTarget: "Chest activation", icon: "figure.strengthtraining.traditional", type: .activation),
    ],
    "back": [
        WarmUpDrill(name: "Cat-cow stretch", sets: "2×8", muscleTarget: "Spine mobility", icon: "figure.flexibility", type: .mobility),
        WarmUpDrill(name: "Band face pulls", sets: "2×12", muscleTarget: "Rear delts/upper back", icon: "figure.strengthtraining.functional", type: .activation),
        WarmUpDrill(name: "Scapular retractions", sets: "2×10", muscleTarget: "Scapula stability", icon: "arrow.left.arrow.right", type: .activation),
    ],
    "shoulders": [
        WarmUpDrill(name: "Shoulder dislocates", sets: "2×10", muscleTarget: "Shoulder ROM", icon: "arrow.triangle.2.circlepath", type: .mobility),
        WarmUpDrill(name: "Band external rotations", sets: "2×12", muscleTarget: "Rotator cuff", icon: "figure.strengthtraining.functional", type: .activation),
        WarmUpDrill(name: "Overhead reach & hold", sets: "2×15s", muscleTarget: "Overhead mobility", icon: "figure.flexibility", type: .mobility),
    ],
    "legs": [
        WarmUpDrill(name: "Bodyweight squats", sets: "2×10", muscleTarget: "Quad/glute activation", icon: "figure.strengthtraining.traditional", type: .activation),
        WarmUpDrill(name: "Hip circles", sets: "2×8 each", muscleTarget: "Hip mobility", icon: "arrow.triangle.2.circlepath", type: .mobility),
        WarmUpDrill(name: "Walking lunges", sets: "1×8 each", muscleTarget: "Hip flexor stretch", icon: "figure.walk", type: .dynamic),
        WarmUpDrill(name: "Ankle circles", sets: "2×10 each", muscleTarget: "Ankle mobility", icon: "arrow.triangle.2.circlepath", type: .mobility),
    ],
    "quads": [
        WarmUpDrill(name: "Bodyweight squats", sets: "2×10", muscleTarget: "Quad activation", icon: "figure.strengthtraining.traditional", type: .activation),
        WarmUpDrill(name: "Leg swings (front)", sets: "2×10 each", muscleTarget: "Hip flexion", icon: "figure.flexibility", type: .dynamic),
    ],
    "hamstrings": [
        WarmUpDrill(name: "Good mornings (BW)", sets: "2×10", muscleTarget: "Hamstring activation", icon: "figure.strengthtraining.traditional", type: .activation),
        WarmUpDrill(name: "Leg swings (side)", sets: "2×10 each", muscleTarget: "Adductor stretch", icon: "figure.flexibility", type: .dynamic),
    ],
    "glutes": [
        WarmUpDrill(name: "Glute bridges", sets: "2×12", muscleTarget: "Glute activation", icon: "figure.strengthtraining.traditional", type: .activation),
        WarmUpDrill(name: "Clamshells", sets: "2×10 each", muscleTarget: "Glute med activation", icon: "figure.flexibility", type: .activation),
    ],
    "biceps": [
        WarmUpDrill(name: "Band curls", sets: "1×15", muscleTarget: "Bicep activation", icon: "figure.strengthtraining.functional", type: .activation),
        WarmUpDrill(name: "Wrist circles", sets: "2×10", muscleTarget: "Wrist/forearm", icon: "arrow.triangle.2.circlepath", type: .mobility),
    ],
    "triceps": [
        WarmUpDrill(name: "Band pushdowns", sets: "1×15", muscleTarget: "Tricep activation", icon: "figure.strengthtraining.functional", type: .activation),
        WarmUpDrill(name: "Elbow circles", sets: "2×10", muscleTarget: "Elbow mobility", icon: "arrow.triangle.2.circlepath", type: .mobility),
    ],
    "core": [
        WarmUpDrill(name: "Dead bugs", sets: "2×8", muscleTarget: "Core activation", icon: "figure.flexibility", type: .activation),
        WarmUpDrill(name: "Bird dogs", sets: "2×8 each", muscleTarget: "Spine stability", icon: "figure.flexibility", type: .activation),
    ],
]

// Fallback for any muscle group not in the database
private let generalDrills = [
    WarmUpDrill(name: "Jumping jacks", sets: "2×20", muscleTarget: "General warm-up", icon: "figure.jumprope", type: .dynamic),
    WarmUpDrill(name: "Arm circles", sets: "2×10 each", muscleTarget: "Upper body mobility", icon: "arrow.triangle.2.circlepath", type: .dynamic),
    WarmUpDrill(name: "Bodyweight squats", sets: "2×10", muscleTarget: "Lower body activation", icon: "figure.strengthtraining.traditional", type: .activation),
]

// MARK: - Card View

struct DynamicWarmUpCard: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var drills: [WarmUpDrill] = []
    @State private var muscleGroups: [String] = []
    @State private var estimatedMinutes = 5
    @State private var hasSession = false

    var body: some View {
        Group {
            if hasSession && !drills.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "figure.flexibility")
                            .foregroundColor(Color(hex: "059669"))
                        Text("Warm-up for today")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                            Text("~\(estimatedMinutes) min")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "059669"))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color(hex: "059669").opacity(0.1))
                        .clipShape(Capsule())
                    }

                    // Target muscles
                    if !muscleGroups.isEmpty {
                        HStack(spacing: 4) {
                            Text("Targeting:")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            ForEach(muscleGroups, id: \.self) { group in
                                Text(group.capitalized)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(Color(hex: "059669"))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: "059669").opacity(0.08))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    // Drill list
                    VStack(spacing: 6) {
                        ForEach(drills) { drill in
                            drillRow(drill)
                        }
                    }

                    Text("Fradkin et al. (2010): targeted warm-ups reduce injury risk. Dynamic drills > static stretching pre-resistance training (Behm & Chaouachi 2011).")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { generateWarmUp() }
    }

    private func drillRow(_ drill: WarmUpDrill) -> some View {
        HStack(spacing: 8) {
            Image(systemName: drill.icon)
                .font(.system(size: 11))
                .foregroundColor(drillTypeColor(drill.type))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(drill.name)
                        .font(.system(size: 11, weight: .bold))
                    Text(drill.type.rawValue)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(drillTypeColor(drill.type))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(drillTypeColor(drill.type).opacity(0.1))
                        .clipShape(Capsule())
                }
                Text(drill.muscleTarget)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(drill.sets)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(6)
        .background(Color(.tertiarySystemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func drillTypeColor(_ type: WarmUpDrill.DrillType) -> Color {
        switch type {
        case .activation: return Color(hex: "2563EB")
        case .mobility:   return Color(hex: "F59E0B")
        case .dynamic:    return Color(hex: "059669")
        }
    }

    // MARK: - Generate

    private func generateWarmUp() {
        guard appState.isTrainingDay else { return }

        // Get today's exercises from the training day config
        let calendar = Calendar.current
        let pid = ActiveProfile.id


        // Try custom sessions first
        let dayConfDesc = FetchDescriptor<TrainingDayConfig>(
            predicate: #Predicate<TrainingDayConfig> { $0.profileId == pid }
        )
        let dayConfigs = (try? modelContext.fetch(dayConfDesc)) ?? []

        let weekday = calendar.component(.weekday, from: Date())
        var groups = Set<String>()

        // Check custom sessions (exercises live on CustomSession, not standalone)
        let customSessionDesc = FetchDescriptor<CustomSession>(
            predicate: #Predicate<CustomSession> { $0.profileId == pid }
        )
        let customSessions = (try? modelContext.fetch(customSessionDesc)) ?? []

        // Try to get muscle groups from today's training day
        if let todayConfig = dayConfigs.first(where: { $0.weekday == weekday }) {
            // Get exercises from the matching custom session
            let matchingSession = customSessions.first { $0.sessionTypeRaw == todayConfig.code }
            let dayExercises = matchingSession?.exercises ?? []
            for ex in dayExercises {
                let group = ex.muscleGroup.lowercased()
                if !group.isEmpty { groups.insert(group) }
            }
        }

        // Fallback: get from ProgramData
        if groups.isEmpty {
            if let sessionType = ProgramData.sessionType(for: Date()) {
                let exercises = ProgramData.exercises(for: sessionType)
                for ex in exercises {
                    let group = ex.muscleGroup.lowercased()
                    if !group.isEmpty { groups.insert(group) }
                }
            }
        }

        // If still empty, use generic full-body warm-up
        if groups.isEmpty {
            groups = ["chest", "back", "legs"]
        }

        hasSession = true
        muscleGroups = Array(groups).sorted()

        // Collect drills for each muscle group, deduplicated
        var selectedDrills: [WarmUpDrill] = []
        var seenNames = Set<String>()

        for group in muscleGroups {
            let groupDrills = drillDatabase[group] ?? drillDatabase["core"] ?? []
            for drill in groupDrills {
                if !seenNames.contains(drill.name) {
                    seenNames.insert(drill.name)
                    selectedDrills.append(drill)
                }
            }
        }

        // Add one general drill if we have fewer than 3
        if selectedDrills.count < 3 {
            for drill in generalDrills {
                if !seenNames.contains(drill.name) {
                    seenNames.insert(drill.name)
                    selectedDrills.append(drill)
                }
                if selectedDrills.count >= 4 { break }
            }
        }

        // Cap at 8 drills max (keep it practical)
        drills = Array(selectedDrills.prefix(8))
        estimatedMinutes = max(4, drills.count) // ~1 min per drill
    }
}
