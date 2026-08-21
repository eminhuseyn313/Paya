import Foundation
import SwiftData

// MARK: - Health Nudge Engine
//
// Correlates the user's Health Journey profile with their real-time logged
// data (training, nutrition, hydration, bathroom, sleep, HRV, symptoms)
// and produces actionable nudges displayed on the dashboard.
//
// This is NOT AI-powered — it's a fast, local rules engine that runs on
// every dashboard refresh. No API calls, no latency, no cost.
//
// Each nudge is a concrete, actionable recommendation grounded in the
// user's own data + their health profile. Not generic tips — these only
// fire when the data says they should.
//
// Grounding:
//   • Hydration targets: NASEM Dietary Reference Intakes (2005)
//   • Protein timing: ISSN Position Stand on Protein (Jäger et al., 2017)
//   • Iron + thalassemia: TIF Guidelines for Clinical Management (2023)
//   • Caffeine cutoff: Sleep Foundation / Walker "Why We Sleep" (2017)
//   • Bristol scale norms: Lewis & Heaton, Scandinavian J Gastro (1997)
//   • Exercise + diabetes: ADA Standards of Care (2024)
//   • Sodium + hypertension: DASH diet, NIH/NHLBI

enum HealthNudgeEngine {

    // MARK: - Nudge Model

    struct Nudge: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
        let category: Category
        let priority: Priority
        let actionLabel: String?  // nil = informational only
        let action: Action        // what happens when tapped

        enum Action {
            case none                   // informational only
            case switchTab(Int)         // navigate to tab (0=home, 1=train, 2=nutrition, 3=health, 4=progress)
            case openSheet(SheetType)   // open a specific sheet on the dashboard
        }

        enum SheetType: String {
            case water, food, training, checkIn
        }

        enum Category: String {
            case hydration, nutrition, exercise, sleep, supplement, digestive, recovery, activity
        }

        enum Priority: Int, Comparable {
            case low = 0, medium = 1, high = 2, urgent = 3
            static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
        }
    }

    // MARK: - Generate Nudges

    @MainActor
    static func generate(profile: PersonProfile, context: ModelContext) -> [Nudge] {
        guard profile.healthJourneyCompleted else { return [] }

        var nudges: [Nudge] = []
        let conditions = Set(profile.chronicConditionsRaw)
        let genetics = Set(profile.geneticDisordersRaw)
        _ = Set(profile.allergiesRaw)
        let meds = Set(profile.medicationsRaw.map { $0.lowercased() })
        let supps = Set(profile.currentSupplementsRaw.map { $0.lowercased() })
        let mental = Set(profile.mentalHealthConditionsRaw)
        let sleepDisorders = Set(profile.sleepDisordersRaw)
        let cal = Calendar.current

        // ── Gather today's data ─────────────────────────────────────

        let todayWaterMl = WaterStore.todayTotal(context: context)
        let todayCaffeineMg = WaterStore.todayCaffeineMg(context: context)
        let bio = BiometricStore.shared
        let todaySummary = bio.history.first { cal.isDateInToday($0.date) }
        let yesterdaySummary = bio.history.first {
            cal.isDateInYesterday($0.date)
        }

        // Today's nutrition
        let pid = ActiveProfile.id
        let todayStart = cal.startOfDay(for: .now)
        let nutritionDescriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.date >= todayStart && $0.profileId == pid }
        )
        let todayNutrition = (try? context.fetch(nutritionDescriptor))?.first

        // Today's training
        let sessionDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.date >= todayStart && $0.profileId == pid }
        )
        let todaySessions = (try? context.fetch(sessionDescriptor)) ?? []
        let trainedToday = !todaySessions.isEmpty

        // Recent bathroom logs (last 3 days)
        let threeDaysAgo = cal.date(byAdding: .day, value: -3, to: .now) ?? .now
        let bathroomDescriptor = FetchDescriptor<BathroomLog>(
            predicate: #Predicate<BathroomLog> { $0.date >= threeDaysAgo && $0.profileId == pid }
        )
        let recentBathroom = (try? context.fetch(bathroomDescriptor)) ?? []

        // Recent symptoms
        let symptomLogs = SymptomStore.recent(daysBack: 7, context: context)

        // Check-ins (last 3 days)
        let checkInDescriptor = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate<DailyCheckIn> { $0.date >= threeDaysAgo && $0.profileId == pid }
        )
        let recentCheckIns = (try? context.fetch(checkInDescriptor)) ?? []

        let hour = cal.component(.hour, from: .now)

        // ── HYDRATION NUDGES ────────────────────────────────────────

        let weightKg = profile.currentWeightKg
        let targetMl = Int(weightKg * 35) // ~35ml/kg baseline (NASEM)

        if todayWaterMl < targetMl / 2 && hour >= 14 {
            nudges.append(Nudge(
                icon: "drop.fill",
                title: "You're behind on water",
                detail: "Only \(todayWaterMl)ml so far — aim for \(targetMl)ml today (\(targetMl - todayWaterMl)ml to go).",
                category: .hydration, priority: .high,
                actionLabel: "Log water", action: .openSheet(.water)
            ))
        }

        if conditions.contains("kidney_disease") && todayWaterMl > 2500 {
            nudges.append(Nudge(
                icon: "exclamationmark.triangle.fill",
                title: "Watch fluid intake",
                detail: "With kidney disease, excess fluid can strain your kidneys. Check with your nephrologist about your daily limit.",
                category: .hydration, priority: .urgent,
                actionLabel: nil, action: .none
            ))
        }

        // Caffeine cutoff for sleep disorders / anxiety
        if todayCaffeineMg > 0 && hour >= 14 &&
           (sleepDisorders.contains("insomnia") || mental.contains("anxiety") || mental.contains("panic_disorder")) {
            nudges.append(Nudge(
                icon: "cup.and.saucer.fill",
                title: "Caffeine cutoff time",
                detail: "You've had \(Int(todayCaffeineMg))mg caffeine — with \(sleepDisorders.contains("insomnia") ? "insomnia" : "anxiety"), avoid caffeine after 2 PM for better sleep.",
                category: .sleep, priority: .medium,
                actionLabel: nil, action: .none
            ))
        }

        // ── NUTRITION NUDGES ────────────────────────────────────────

        if let nutrition = todayNutrition {
            let protein = nutrition.totalProtein
            let target = nutrition.proteinTarget

            // Low protein warning (afternoon)
            if protein < target * 0.4 && hour >= 15 {
                nudges.append(Nudge(
                    icon: "fork.knife",
                    title: "Protein is low today",
                    detail: "Only \(Int(protein))g of \(Int(target))g so far. Try chicken, eggs, Greek yogurt, or a protein shake to catch up.",
                    category: .nutrition, priority: .high,
                    actionLabel: "Log food", action: .openSheet(.food)
                ))
            }

            // Post-workout protein reminder
            if trainedToday && protein < 30 {
                let lastSession = todaySessions.sorted { $0.date > $1.date }.first
                if let session = lastSession,
                   Date().timeIntervalSince(session.date) < 7200, // within 2h of training
                   Date().timeIntervalSince(session.date) > 900 {  // at least 15min after
                    nudges.append(Nudge(
                        icon: "figure.strengthtraining.traditional",
                        title: "Post-workout protein window",
                        detail: "You trained recently — aim for 25-40g protein within 2 hours for optimal recovery (ISSN, Jäger 2017).",
                        category: .nutrition, priority: .medium,
                        actionLabel: "Log food", action: .openSheet(.food)
                    ))
                }
            }

            // Sodium warning for hypertension
            if conditions.contains("hypertension") {
                let todaySodium = nutrition.meals.reduce(0.0) { $0 + $1.sodiumMg }
                if todaySodium > 1500 {
                    nudges.append(Nudge(
                        icon: "heart.fill",
                        title: "Sodium is high today",
                        detail: "\(Int(todaySodium))mg sodium so far. With hypertension, aim under 1,500mg/day (DASH guidelines).",
                        category: .nutrition, priority: .high,
                        actionLabel: nil, action: .none
                    ))
                }
            }

            // Calorie deficit too aggressive
            let calorieTarget = nutrition.calorieTarget
            if nutrition.totalCalories < calorieTarget * 0.5 && hour >= 18 {
                if mental.contains("eating_disorder") {
                    // Sensitive — don't emphasize numbers
                    nudges.append(Nudge(
                        icon: "heart.fill",
                        title: "Remember to nourish yourself",
                        detail: "Your body needs fuel to recover and feel good. Try having a balanced meal this evening.",
                        category: .nutrition, priority: .medium,
                        actionLabel: nil, action: .none
                    ))
                } else {
                    nudges.append(Nudge(
                        icon: "fork.knife",
                        title: "Eating very light today",
                        detail: "Only \(Int(nutrition.totalCalories)) of \(Int(calorieTarget)) kcal by evening. Severe deficits impair recovery and performance.",
                        category: .nutrition, priority: .medium,
                        actionLabel: "Log food", action: .openSheet(.food)
                    ))
                }
            }
        } else if hour >= 12 {
            // No nutrition logged by noon
            nudges.append(Nudge(
                icon: "fork.knife",
                title: "No food logged today",
                detail: "Logging meals helps Paya give you better nutrition insights. Even rough estimates help.",
                category: .nutrition, priority: .low,
                actionLabel: "Log food", action: .openSheet(.food)
            ))
        }

        // ── EXERCISE NUDGES ─────────────────────────────────────────

        // Diabetes pre-exercise reminder
        if (conditions.contains("diabetes_t1") || conditions.contains("diabetes_t2")) && !trainedToday && hour < 18 {
            nudges.append(Nudge(
                icon: "drop.triangle.fill",
                title: "Check glucose before training",
                detail: "If you plan to train today, check blood sugar first. Avoid intense exercise if >250mg/dL with ketones or <100mg/dL without a snack (ADA 2024).",
                category: .exercise, priority: .medium,
                actionLabel: nil, action: .none
            ))
        }

        // Soreness-based rest suggestion
        let recentSoreness = recentCheckIns.sorted { $0.date > $1.date }.first?.soreness ?? 0
        if recentSoreness >= 4 && !trainedToday {
            nudges.append(Nudge(
                icon: "figure.cooldown",
                title: "High soreness — consider active recovery",
                detail: "You reported \(recentSoreness)/5 soreness. A 20-min walk, stretching, or foam rolling can help more than complete rest.",
                category: .recovery, priority: .medium,
                actionLabel: nil, action: .none
            ))
        }

        // Low energy + depression → celebrate movement
        let recentEnergy = recentCheckIns.sorted { $0.date > $1.date }.first?.energy ?? 2
        if recentEnergy == 1 && mental.contains("depression") {
            if trainedToday {
                nudges.append(Nudge(
                    icon: "star.fill",
                    title: "You showed up — that matters",
                    detail: "Training when energy is low takes real effort. Even a short session helps regulate mood through endorphins and BDNF release.",
                    category: .recovery, priority: .medium,
                    actionLabel: nil, action: .none
                ))
            } else if hour < 18 {
                nudges.append(Nudge(
                    icon: "figure.walk",
                    title: "Even 10 minutes helps",
                    detail: "A short walk or gentle movement can improve mood. You don't need a full workout — anything counts today.",
                    category: .activity, priority: .low,
                    actionLabel: nil, action: .none
                ))
            }
        }

        // ADHD exercise reminder
        if mental.contains("adhd") && !trainedToday && hour >= 10 && hour <= 16 {
            nudges.append(Nudge(
                icon: "brain.head.profile",
                title: "Exercise boosts focus",
                detail: "Physical activity raises dopamine and norepinephrine — the same pathways ADHD meds target. Even 20 minutes can sharpen focus for 2-3 hours.",
                category: .exercise, priority: .low,
                actionLabel: "Start workout", action: .switchTab(1)
            ))
        }

        // ── SLEEP NUDGES ────────────────────────────────────────────

        if let sleep = todaySummary?.sleepHours ?? yesterdaySummary?.sleepHours {
            if sleep < 6 {
                nudges.append(Nudge(
                    icon: "moon.zzz.fill",
                    title: "Short sleep last night",
                    detail: "\(String(format: "%.1f", sleep))h logged. If training today, reduce intensity — recovery is compromised.",
                    category: .sleep, priority: .high,
                    actionLabel: nil, action: .none
                ))
            }

            if sleepDisorders.contains("sleep_apnea") && sleep < 7 {
                nudges.append(Nudge(
                    icon: "lungs.fill",
                    title: "Sleep quality matters more with apnea",
                    detail: "Short sleep + apnea means less restorative rest. Consider weight management and sleep position — side sleeping can reduce events.",
                    category: .sleep, priority: .medium,
                    actionLabel: nil, action: .none
                ))
            }
        }

        // ── HRV NUDGES ─────────────────────────────────────────────

        if let todayHRV = todaySummary?.hrv,
           let yesterdayHRV = yesterdaySummary?.hrv {
            let drop = (yesterdayHRV - todayHRV) / yesterdayHRV
            if drop > 0.2 { // >20% HRV drop
                nudges.append(Nudge(
                    icon: "heart.text.clipboard",
                    title: "HRV dropped \(Int(drop * 100))% from yesterday",
                    detail: "HRV \(Int(todayHRV))ms vs \(Int(yesterdayHRV))ms yesterday. This can signal stress, poor sleep, or overtraining. Consider lighter training today.",
                    category: .recovery, priority: .high,
                    actionLabel: nil, action: .none
                ))
            }
        }

        // ── DIGESTIVE NUDGES ────────────────────────────────────────

        let recentPoop = recentBathroom.filter { $0.type == "poop" }
        let recentPee = recentBathroom.filter { $0.type == "pee" }

        // No bowel movement in 2+ days
        let lastPoopDate = recentPoop.sorted { $0.date > $1.date }.first?.date
        if let lastPoop = lastPoopDate, Date().timeIntervalSince(lastPoop) > 48 * 3600 {
            let daysSince = Int(Date().timeIntervalSince(lastPoop) / 86400)
            nudges.append(Nudge(
                icon: "stomach",
                title: "No bowel movement in \(daysSince) days",
                detail: "Try increasing fiber (25-30g/day), water, and movement. If persistent, consider magnesium or consult your doctor.",
                category: .digestive, priority: .medium,
                actionLabel: nil, action: .none
            ))
        }

        // Loose stools pattern
        let looseStools = recentPoop.filter { ($0.bristolScale ?? 4) >= 6 }
        if looseStools.count >= 3 {
            var detail = "\(looseStools.count) loose stools in the last 3 days."
            if conditions.contains("crohns") || conditions.contains("ibs") {
                detail += " With your condition, consider switching to low-FODMAP foods for a few days."
            } else {
                detail += " Track what you ate before each — food triggers are often the cause."
            }
            nudges.append(Nudge(
                icon: "exclamationmark.triangle.fill",
                title: "Loose stool pattern detected",
                detail: detail,
                category: .digestive, priority: .high,
                actionLabel: nil, action: .none
            ))
        }

        // Frequent urination
        let todayPee = recentPee.filter { cal.isDateInToday($0.date) }.count
        if todayPee >= 10 {
            var detail = "\(todayPee) times today is above average. "
            if conditions.contains("diabetes_t1") || conditions.contains("diabetes_t2") {
                detail += "With diabetes, frequent urination can signal high blood sugar — check your levels."
            } else {
                detail += "This could be from high caffeine, lots of water, or a UTI if accompanied by pain."
            }
            nudges.append(Nudge(
                icon: "drop.halffull",
                title: "Frequent urination today",
                detail: detail,
                category: .digestive, priority: .medium,
                actionLabel: nil, action: .none
            ))
        }

        // ── SUPPLEMENT NUDGES ───────────────────────────────────────

        // Iron + thalassemia — critical
        if genetics.contains("beta_thalassemia") || genetics.contains("hemochromatosis") {
            if supps.contains(where: { $0.contains("iron") }) {
                nudges.append(Nudge(
                    icon: "exclamationmark.octagon.fill",
                    title: "Stop iron supplements",
                    detail: "Iron supplementation is dangerous with \(genetics.contains("beta_thalassemia") ? "beta thalassemia (iron overload risk)" : "hemochromatosis"). Discuss with your hematologist immediately.",
                    category: .supplement, priority: .urgent,
                    actionLabel: nil, action: .none
                ))
            }
        }

        // Vitamin K + warfarin
        if meds.contains(where: { $0.contains("warfarin") || $0.contains("coumadin") }) {
            if supps.contains(where: { $0.contains("vitamin k") }) {
                nudges.append(Nudge(
                    icon: "pills.fill",
                    title: "Vitamin K interacts with Warfarin",
                    detail: "Vitamin K directly opposes warfarin's blood-thinning effect. Keep intake consistent and inform your doctor.",
                    category: .supplement, priority: .urgent,
                    actionLabel: nil, action: .none
                ))
            }
        }

        // B12 reminder if on metformin
        if meds.contains(where: { $0.contains("metformin") }) &&
           !supps.contains(where: { $0.contains("b12") || $0.contains("b-12") }) {
            nudges.append(Nudge(
                icon: "pills.fill",
                title: "Consider B12 with Metformin",
                detail: "Metformin can reduce B12 absorption over time. Ask your doctor about checking B12 levels and supplementing.",
                category: .supplement, priority: .low,
                actionLabel: nil, action: .none
            ))
        }

        // ── ACTIVITY NUDGES ─────────────────────────────────────────

        if let steps = todaySummary?.steps, steps < 3000 && hour >= 16 {
            nudges.append(Nudge(
                icon: "figure.walk",
                title: "Only \(steps.formatted()) steps today",
                detail: "A 15-20 minute walk after dinner improves digestion, blood sugar regulation, and sleep quality.",
                category: .activity, priority: .low,
                actionLabel: nil, action: .none
            ))
        }

        // Screen time warning
        if profile.dailyScreenTimeHours > 10 && hour >= 20 {
            nudges.append(Nudge(
                icon: "iphone",
                title: "Wind down from screens",
                detail: "Your \(Int(profile.dailyScreenTimeHours))h daily screen time is high. Blue light after 9 PM can suppress melatonin by 50% — try Night Shift or put the phone down.",
                category: .sleep, priority: .low,
                actionLabel: nil, action: .none
            ))
        }

        // ── SYMPTOM-BASED NUDGES ────────────────────────────────────

        let recentFlares = symptomLogs.filter { $0.severity >= 2 }
        if recentFlares.count >= 3 {
            nudges.append(Nudge(
                icon: "waveform.path.ecg",
                title: "Symptom pattern detected",
                detail: "\(recentFlares.count) moderate-severe symptoms in the last 7 days. Consider reviewing your diet and sleep — Paya's AI can generate a personalized plan.",
                category: .recovery, priority: .high,
                actionLabel: "Get AI plan", action: .switchTab(3)
            ))
        }

        // ── CONDITION-SPECIFIC DAILY NUDGES ─────────────────────────

        // GERD + late eating
        if conditions.contains("gerd") && hour >= 20 {
            nudges.append(Nudge(
                icon: "flame.fill",
                title: "Avoid eating close to bedtime",
                detail: "With GERD, stop eating 3 hours before bed and avoid lying flat. Elevate the head of your bed if reflux is frequent.",
                category: .digestive, priority: .low,
                actionLabel: nil, action: .none
            ))
        }

        // Celiac + gluten reminder
        if conditions.contains("celiac") && todayNutrition == nil && hour >= 12 {
            nudges.append(Nudge(
                icon: "leaf.fill",
                title: "Log meals to catch gluten",
                detail: "Tracking meals helps identify accidental gluten exposure. Even small amounts cause intestinal damage with celiac disease.",
                category: .nutrition, priority: .medium,
                actionLabel: "Log food", action: .openSheet(.food)
            ))
        }

        // Sort by priority (urgent first), then limit to top 5
        return nudges
            .sorted { $0.priority > $1.priority }
            .prefix(5)
            .map { $0 }
    }
}

// MARK: - Set extension for medication matching

private extension Set where Element == String {
    func contains(where predicate: (String) -> Bool) -> Bool {
        first(where: predicate) != nil
    }
}
