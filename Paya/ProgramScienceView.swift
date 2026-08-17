import SwiftUI
import SwiftData

struct ProgramScienceView: View {

    let recommendation: TrainingScienceEngine.Recommendation
    let profile: PersonProfile

    @Environment(\.dismiss) private var dismiss

    private var goal: TrainingGoal { profile.goal }
    private var experience: ExperienceLevel { profile.experienceLevel }
    private var template: ProgramTemplate { recommendation.template }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    splitEvidenceCard
                    frequencyCard
                    volumeLandmarksCard
                    progressionCard
                    profileFitCard
                    nutritionScienceCard
                    sourcesCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("The Science")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile.fill")
                    .foregroundColor(Pulse.ai)
                Text("Evidence behind your plan")
                    .font(.subheadline.weight(.bold))
            }
            Text("Every decision below is grounded in peer-reviewed research. Tap any section to see why your program is structured the way it is.")
                .font(.caption)
                .foregroundColor(Pulse.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .payaCard(padding: 14)
    }

    // MARK: - Split Evidence

    private var splitEvidenceCard: some View {
        ScienceSection(
            icon: "rectangle.split.3x1.fill",
            title: "Training Split",
            accentHex: "2563EB"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    splitBadge
                    VStack(alignment: .leading, spacing: 2) {
                        Text(splitName)
                            .font(.subheadline.weight(.bold))
                        Text("\(recommendation.daysPerWeek)×/week")
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                    }
                }

                Text(splitExplanation)
                    .font(.caption)
                    .foregroundColor(Pulse.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                CitationRow(text: "Schoenfeld et al. (2016). \"Effects of Resistance Training Frequency on Measures of Muscle Hypertrophy.\" Sports Med. — 2×/week per muscle outperforms 1×/week for hypertrophy.")

                CitationRow(text: "Schoenfeld et al. (2019). \"Resistance Training Volume Enhances Muscle Hypertrophy.\" Med Sci Sports Exerc. — dose-response relationship between weekly sets and growth, up to a point.")
            }
        }
    }

    private var splitName: String {
        switch recommendation.daysPerWeek {
        case ..<4: return "Full Body"
        case 4:    return "Upper / Lower"
        default:   return "Push / Pull / Legs"
        }
    }

    private var splitBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Pulse.hydration.opacity(0.12))
                .frame(width: 40, height: 40)
            Text("\(recommendation.daysPerWeek)")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundColor(Pulse.hydration)
        }
    }

    private var splitExplanation: String {
        switch recommendation.daysPerWeek {
        case ..<3:
            return "With \(recommendation.daysPerWeek) training days, full-body sessions are the only way to achieve the 2×/week frequency per muscle group that the literature consistently shows is superior for hypertrophy. Splitting into body parts at this low frequency means each muscle gets trained only once a week — suboptimal by the meta-analytic data."
        case 3:
            return "Three full-body sessions spread across the week let each muscle group accumulate stimulus roughly twice per week. The Schoenfeld 2016 meta-analysis found significantly greater hypertrophy with 2×/week frequency vs. 1×. Full-body also distributes fatigue more evenly than concentrating all chest or leg work into one day."
        case 4:
            return "Four days enables an Upper/Lower split — each muscle group trained twice weekly at higher per-session volume than full-body allows. This captures the frequency sweet spot identified in the meta-analyses while giving enough exercise slots to address each muscle with adequate sets."
        default:
            return "At \(recommendation.daysPerWeek) days per week, a Push/Pull/Legs-style split maintains 2×/week frequency for every muscle group while allowing enough exercise variety and volume per session to drive continued adaptation. The additional days make space for direct arm, delt, and isolation work that lower frequencies must deprioritize."
        }
    }

    // MARK: - Frequency

    private var frequencyCard: some View {
        ScienceSection(
            icon: "calendar.badge.clock",
            title: "Frequency per Muscle",
            accentHex: "059669"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                let freq = muscleFrequency
                ForEach(freq.sorted(by: { $0.value > $1.value }), id: \.key) { muscle, times in
                    HStack {
                        Text(muscle)
                            .font(.caption.weight(.medium))
                        Spacer()
                        HStack(spacing: 3) {
                            ForEach(0..<times, id: \.self) { _ in
                                Circle()
                                    .fill(Pulse.positive)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        Text("\(times)×/wk")
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(Pulse.textTertiary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }

                CitationRow(text: "Meta-analytic consensus: training a muscle group ≥2×/week produces greater hypertrophy than 1×/week at matched volume (Schoenfeld, Ogborn & Krieger, 2016).")
            }
        }
    }

    private var muscleFrequency: [String: Int] {
        var freq: [String: Int] = [:]
        for day in template.days {
            var seen = Set<String>()
            for ex in day.exercises {
                let group = ex.muscleGroup
                if !group.isEmpty && !seen.contains(group) {
                    seen.insert(group)
                    freq[group, default: 0] += 1
                }
            }
        }
        return freq
    }

    // MARK: - Volume Landmarks

    private var volumeLandmarksCard: some View {
        ScienceSection(
            icon: "chart.bar.fill",
            title: "Volume Landmarks",
            accentHex: "D97706"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Renaissance Periodization's published volume landmarks (Israetel, Hoffmann & Smith) define three thresholds for each muscle group:")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    landmarkDefinition("MEV", "Minimum Effective Volume — the floor below which growth barely occurs", hex: "9CA3AF")
                    landmarkDefinition("MAV", "Maximum Adaptive Volume — the range producing the best rate of growth", hex: "059669")
                    landmarkDefinition("MRV", "Maximum Recoverable Volume — the ceiling past which recovery cost exceeds benefit", hex: "DC2626")
                }

                Text("Your plan's weekly sets per muscle:")
                    .font(.caption.weight(.semibold))
                    .padding(.top, 4)

                let volumes = plannedVolumes
                ForEach(volumes, id: \.muscle) { vol in
                    volumeBar(vol)
                }

                CitationRow(text: "Israetel, Hoffmann & Smith. \"Scientific Principles of Hypertrophy Training.\" RP. — Volume-landmark framework based on aggregated research and coaching data.")
            }
        }
    }

    private func landmarkDefinition(_ abbr: String, _ text: String, hex: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(abbr)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundColor(Color(hex: hex))
                .frame(width: 32, alignment: .leading)
            Text(text)
                .font(.caption2)
                .foregroundColor(Pulse.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private struct PlannedVolume: Identifiable {
        var id: String { muscle }
        let muscle: String
        let sets: Int
        let mev: Int
        let mavLow: Int
        let mavHigh: Int
        let mrv: Int
    }

    private var plannedVolumes: [PlannedVolume] {
        let landmarks: [String: (Int, Int, Int, Int)] = [
            "Chest": (8, 12, 20, 22),
            "Back": (10, 14, 22, 25),
            "Quads": (8, 12, 18, 20),
            "Hamstrings": (6, 10, 16, 20),
            "Shoulders": (8, 16, 22, 26),
            "Biceps": (8, 14, 20, 26),
            "Triceps": (6, 10, 14, 18),
            "Glutes": (4, 8, 12, 16),
            "Core": (0, 8, 16, 20),
            "Calves": (8, 12, 16, 20)
        ]

        var sets: [String: Int] = [:]
        for day in template.days {
            for ex in day.exercises {
                let group = ex.muscleGroup == "Side Delts" ? "Shoulders" : ex.muscleGroup
                if !group.isEmpty {
                    sets[group, default: 0] += ex.sets
                }
            }
        }

        return sets.compactMap { muscle, count -> PlannedVolume? in
            guard let lm = landmarks[muscle] else { return nil }
            return PlannedVolume(muscle: muscle, sets: count, mev: lm.0, mavLow: lm.1, mavHigh: lm.2, mrv: lm.3)
        }
        .sorted { $0.sets > $1.sets }
    }

    private func volumeBar(_ vol: PlannedVolume) -> some View {
        let scaleMax = Double(vol.mrv) * 1.15
        let fill = min(1.0, Double(vol.sets) / scaleMax)
        let zone: String
        let zoneHex: String
        if vol.sets < vol.mavLow {
            zone = "Below MAV"
            zoneHex = "9CA3AF"
        } else if vol.sets <= vol.mavHigh {
            zone = "In MAV"
            zoneHex = "059669"
        } else if vol.sets <= vol.mrv {
            zone = "Near MRV"
            zoneHex = "D97706"
        } else {
            zone = "Over MRV"
            zoneHex = "DC2626"
        }

        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(vol.muscle)
                    .font(.caption2.weight(.medium))
                Spacer()
                Text("\(vol.sets) sets")
                    .font(.caption2.monospacedDigit())
                Text("·")
                    .foregroundColor(Pulse.textTertiary)
                Text(zone)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Color(hex: zoneHex))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: zoneHex).opacity(0.15))
                        .frame(height: 5)
                    Capsule()
                        .fill(Color(hex: zoneHex))
                        .frame(width: geo.size.width * fill, height: 5)
                    let mavFrac = Double(vol.mavLow) / scaleMax
                    Rectangle()
                        .fill(Color.primary.opacity(0.2))
                        .frame(width: 1, height: 9)
                        .offset(x: geo.size.width * mavFrac)
                }
            }
            .frame(height: 5)
        }
    }

    // MARK: - Progression

    private var progressionCard: some View {
        ScienceSection(
            icon: "arrow.up.right.circle.fill",
            title: "Progression Model",
            accentHex: "8B5CF6"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                progressionStep("1", "Double Progression", "Add a rep each session until you hit the top of the rep range, then add weight and drop reps back to the bottom. This is the most well-supported progression model for intermediate-and-beyond lifters targeting hypertrophy.")

                progressionStep("2", "Mesocycle Structure", "5 weeks of progressive overload followed by a 1-week deload (~35% volume reduction). Deload timing follows the SRA (Stimulus–Recovery–Adaptation) principle — fatigue accumulates across weeks and must be dissipated before the next training block.")

                progressionStep("3", "RPE Guidance", rpeGuidance)

                CitationRow(text: "Helms et al. (2016). \"Application of the Repetitions in Reserve-Based Rating of Perceived Exertion Scale for Resistance Training.\" Strength & Conditioning Journal. — RPE/RIR scale for autoregulating intensity.")

                CitationRow(text: "Zourdos et al. (2016). \"Novel Resistance Training-Specific Rating of Perceived Exertion Scale.\" J Strength Cond Res. — Validated RPE scale for resistance training.")
            }
        }
    }

    private var rpeGuidance: String {
        switch experience {
        case .beginner:
            return "As a beginner, stay at RPE 6-7 (2-3 reps short of failure). The stimulus threshold for growth is lower when you're new — technique quality matters more than proximity to failure at this stage."
        case .intermediate:
            return "Train at RPE 7-8 on most sets (1-2 reps in reserve). Research shows most hypertrophy occurs in this range — going to true failure on every set adds disproportionate fatigue without proportionate growth."
        case .advanced:
            return "Push the last 1-2 sets to RPE 9-10 (near or at failure). Advanced lifters need higher relative effort to trigger adaptation. Research supports failure training selectively, not on every set — use it on isolation and machine movements where failure is safest."
        }
    }

    private func progressionStep(_ num: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(num)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Pulse.ai)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                Text(text)
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Profile Fit

    private var profileFitCard: some View {
        ScienceSection(
            icon: "person.crop.circle.badge.checkmark.fill",
            title: "Personalized to You",
            accentHex: "0891B2"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(recommendation.rationale, id: \.self) { line in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Pulse.recovery)
                            .padding(.top, 2)
                        Text(line)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Nutrition Science

    private var nutritionScienceCard: some View {
        let targets = GoalEngine.targets(
            goal: goal,
            bodyWeightKg: profile.currentWeightKg,
            age: profile.currentAge,
            heightCm: profile.heightCm,
            sexRaw: profile.sexRaw
        )

        return ScienceSection(
            icon: "fork.knife.circle.fill",
            title: "Nutrition Targets",
            accentHex: "059669"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                nutritionRow("Protein", "\(Int(targets.proteinG))g/day", nutritionProteinExplanation)
                nutritionRow("Training-day calories", "\(Int(targets.trainingDayCalories)) kcal", nutritionCalorieExplanation)
                nutritionRow("Rest-day calories", "\(Int(targets.restDayCalories)) kcal", "Rest days use a lower activity multiplier — you're not burning the session itself.")

                CitationRow(text: "Morton et al. (2018). \"A systematic review, meta-analysis and meta-regression of the effect of protein supplementation on resistance training-induced gains in muscle mass and strength.\" BJSM. — Gains plateau at ~1.6g/kg/day, upper CI 2.2g/kg.")

                CitationRow(text: "Mifflin et al. (1990). \"A new predictive equation for resting energy expenditure.\" Am J Clin Nutr. — BMR equation used here; validated as more accurate than Harris-Benedict.")
            }
        }
    }

    private var nutritionProteinExplanation: String {
        let perKg: Double
        switch goal {
        case .hypertrophy: perKg = 2.0
        case .strength: perKg = 1.8
        case .fatLoss: perKg = 2.2
        case .stayFit, .endurance: perKg = 1.6
        }
        return "Set at \(String(format: "%.1f", perKg))g/kg body weight. Morton et al. 2018 meta-analysis found resistance-training muscle gains plateau around 1.6g/kg, with an upper bound of 2.2g/kg for those in a deficit or training hardest."
    }

    private var nutritionCalorieExplanation: String {
        switch goal {
        case .hypertrophy:
            return "~10% above maintenance (Mifflin-St Jeor × 1.55 PAL). Slater & Phillips lean-gain guidance shows larger surpluses add disproportionate fat without more muscle."
        case .strength:
            return "~5% above maintenance. Strength gains are primarily neural — a modest surplus supports recovery without unnecessary fat gain."
        case .fatLoss:
            return "~15-22% below maintenance. Garthe et al. 2011 found slower deficit rates preserved more lean mass than aggressive cuts at the same total weight loss."
        case .stayFit:
            return "At maintenance. No surplus or deficit needed for the maintenance goal."
        case .endurance:
            return "~5% above maintenance. Endurance training increases energy expenditure — a small surplus covers the additional cardio demand."
        }
    }

    private func nutritionRow(_ label: String, _ value: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(value)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundColor(Pulse.positive)
            }
            Text(detail)
                .font(.caption2)
                .foregroundColor(Pulse.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Sources

    private var sourcesCard: some View {
        ScienceSection(
            icon: "books.vertical.fill",
            title: "Key Sources",
            accentHex: "6B7280"
        ) {
            VStack(alignment: .leading, spacing: 6) {
                sourceEntry("Schoenfeld BJ, Ogborn D, Krieger JW", "Effects of Resistance Training Frequency on Measures of Muscle Hypertrophy: A Systematic Review and Meta-Analysis", "Sports Med. 2016;46(11):1689-97")
                sourceEntry("Schoenfeld BJ et al.", "Resistance Training Volume Enhances Muscle Hypertrophy but Not Strength in Trained Men", "Med Sci Sports Exerc. 2019;51(1):94-103")
                sourceEntry("Morton RW et al.", "A systematic review of protein supplementation on resistance training-induced gains", "Br J Sports Med. 2018;52(6):376-384")
                sourceEntry("Israetel M, Hoffmann J, Smith CW", "Scientific Principles of Hypertrophy Training", "Renaissance Periodization")
                sourceEntry("Helms ER et al.", "RPE and velocity for resistance training monitoring and programming", "Strength Cond J. 2016;38(6):42-49")
                sourceEntry("Mifflin MD et al.", "A new predictive equation for resting energy expenditure in healthy individuals", "Am J Clin Nutr. 1990;51(2):241-7")
                sourceEntry("Garthe I et al.", "Effect of two different weight-loss rates on body composition and strength", "Int J Sport Nutr Exerc Metab. 2011;21(2):97-104")

                if profile.sexRaw.lowercased() == "female" {
                    sourceEntry("Hunter SK", "Sex differences in human fatigability", "Acta Physiol. 2014;210(4):768-89")
                    sourceEntry("Prodromos CC et al.", "Meta-analysis of ACL tear incidence by gender", "Arthroscopy. 2007;23(12):1320-25")
                }
            }
        }
    }

    private func sourceEntry(_ authors: String, _ title: String, _ journal: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(authors)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(Pulse.textPrimary)
                .italic()
            Text(journal)
                .font(.system(size: 9))
                .foregroundColor(Pulse.textTertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Science Section Container

private struct ScienceSection<Content: View>: View {
    let icon: String
    let title: String
    let accentHex: String
    @ViewBuilder let content: Content

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) { expanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: accentHex))
                        .frame(width: 28, height: 28)
                        .background(Color(hex: accentHex).opacity(0.12))
                        .clipShape(Circle())
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Pulse.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Pulse.textTertiary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
            }
            .padding(.bottom, expanded ? 10 : 0)

            if expanded {
                content
            }
        }
        .payaCard(padding: 14)
    }
}

// MARK: - Citation Row

private struct CitationRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 8))
                .foregroundColor(Pulse.ai.opacity(0.6))
                .padding(.top, 3)
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(Pulse.textTertiary)
                .italic()
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(Pulse.ai.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
