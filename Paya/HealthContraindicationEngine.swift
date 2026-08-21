import Foundation
import SwiftData

// MARK: - Health Contraindication Engine
//
// Static rules engine that generates personalized warnings and recommendations
// based on the user's HealthJourney profile. Every rule is grounded in named
// clinical guidelines — see inline citations.
//
// This is NOT a diagnostic tool. It surfaces "things worth knowing" that the
// user can discuss with their healthcare provider. The output feeds:
//   • Nutrition warnings (avoid/increase specific foods)
//   • Supplement interaction alerts
//   • Exercise contraindications & alternatives
//   • Sleep/recovery guidance
//   • Mental-health-sensitive language adjustments
//
// The engine runs locally (no API call) for instant results. The AI coaching
// layer (LifestylePlanEngine, AIService) wraps these rules into its prompts
// so Claude/Gemini responses respect them automatically.

enum HealthContraindicationEngine {

    // MARK: - Output Types

    struct ContraindicationReport {
        let nutritionWarnings: [Warning]
        let supplementWarnings: [Warning]
        let exerciseWarnings: [Warning]
        let sleepGuidance: [Warning]
        let mentalHealthNotes: [Warning]
        let digestiveNotes: [Warning]

        var isEmpty: Bool {
            nutritionWarnings.isEmpty && supplementWarnings.isEmpty &&
            exerciseWarnings.isEmpty && sleepGuidance.isEmpty &&
            mentalHealthNotes.isEmpty && digestiveNotes.isEmpty
        }

        var allWarnings: [Warning] {
            nutritionWarnings + supplementWarnings + exerciseWarnings +
            sleepGuidance + mentalHealthNotes + digestiveNotes
        }

        /// Total count across all categories
        var totalCount: Int { allWarnings.count }
    }

    struct Warning: Identifiable {
        let id = UUID()
        let severity: Severity
        let category: Category
        let title: String
        let detail: String
        let source: String  // Clinical guideline / research citation

        enum Severity: String, Comparable {
            case info
            case caution
            case warning
            case critical

            static func < (lhs: Self, rhs: Self) -> Bool {
                let order: [Self] = [.info, .caution, .warning, .critical]
                return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
            }
        }

        enum Category: String {
            case nutrition
            case supplement
            case exercise
            case sleep
            case mentalHealth
            case digestive
        }
    }

    // MARK: - Generate Report

    static func generate(for profile: PersonProfile) -> ContraindicationReport {
        var nutrition: [Warning] = []
        var supplements: [Warning] = []
        var exercise: [Warning] = []
        var sleep: [Warning] = []
        var mentalHealth: [Warning] = []
        var digestive: [Warning] = []

        let conditions = Set(profile.chronicConditionsRaw)
        let genetics = Set(profile.geneticDisordersRaw)
        let allergies = Set(profile.allergiesRaw)
        let meds = Set(profile.medicationsRaw.map { $0.lowercased() })
        _ = Set(profile.currentSupplementsRaw.map { $0.lowercased() })
        let mentalRaw = Set(profile.mentalHealthConditionsRaw)
        let sleepDisorders = Set(profile.sleepDisordersRaw)
        _ = Set(profile.digestiveIssuesRaw)
        let surgeries = Set(profile.pastSurgeriesRaw)

        // ── Chronic condition rules ──────────────────────────────────

        if conditions.contains("celiac") {
            nutrition.append(Warning(
                severity: .critical, category: .nutrition,
                title: "Strict gluten-free diet required",
                detail: "All wheat, barley, rye, and cross-contaminated oats must be avoided. Check supplement labels for gluten-containing fillers.",
                source: "ACG Clinical Guideline: Diagnosis and Management of Celiac Disease (2023)"
            ))
        }

        if conditions.contains("diabetes_t1") || conditions.contains("diabetes_t2") {
            nutrition.append(Warning(
                severity: .warning, category: .nutrition,
                title: "Monitor carbohydrate intake carefully",
                detail: "Track net carbs per meal. Pair carbs with protein/fat to blunt glucose spikes. Post-workout nutrition timing matters for blood sugar management.",
                source: "ADA Standards of Care in Diabetes (2024)"
            ))
            exercise.append(Warning(
                severity: .caution, category: .exercise,
                title: "Check blood glucose before exercise",
                detail: "Avoid intense exercise if glucose is above 250 mg/dL with ketones present, or below 100 mg/dL without a snack. Keep fast-acting carbs accessible.",
                source: "ADA Standards of Care in Diabetes — Exercise Section (2024)"
            ))
        }

        if conditions.contains("hypertension") {
            exercise.append(Warning(
                severity: .warning, category: .exercise,
                title: "Avoid heavy Valsalva maneuvers",
                detail: "Limit max-effort isometric holds and breath-holding under heavy load. Favor controlled breathing, moderate intensity, and higher rep ranges.",
                source: "AHA/ACC Guideline for Hypertension Management (2017, updated 2023)"
            ))
            nutrition.append(Warning(
                severity: .caution, category: .nutrition,
                title: "Limit sodium intake",
                detail: "Target under 2,300 mg/day (ideally 1,500 mg). Watch processed foods, restaurant meals, and pre-workout supplements for hidden sodium.",
                source: "DASH diet — NIH/NHLBI guidelines"
            ))
        }

        if conditions.contains("heart_failure") || conditions.contains("afib") {
            exercise.append(Warning(
                severity: .critical, category: .exercise,
                title: "Cardiac-safe training zones only",
                detail: "Keep heart rate within physician-prescribed zones. Avoid sprints, heavy compound lifts, and cold-water immersion without medical clearance.",
                source: "AHA Scientific Statement on Exercise in Heart Failure (2022)"
            ))
            supplements.append(Warning(
                severity: .warning, category: .supplement,
                title: "Avoid stimulant-based supplements",
                detail: "No caffeine-heavy pre-workouts, ephedrine, or high-dose taurine. These can trigger arrhythmias in susceptible individuals.",
                source: "AHA/ACC Atrial Fibrillation Guideline (2023)"
            ))
        }

        if conditions.contains("myocarditis") {
            exercise.append(Warning(
                severity: .critical, category: .exercise,
                title: "Gradual return-to-exercise only",
                detail: "No intense exercise for at least 3–6 months post-diagnosis. Return must be guided by cardiology clearance, starting with walking.",
                source: "ACC/AHA Myocarditis Expert Consensus (2022)"
            ))
        }

        if conditions.contains("crohns") || conditions.contains("ibs") {
            nutrition.append(Warning(
                severity: .caution, category: .nutrition,
                title: "Low-FODMAP periods may help flares",
                detail: "During active symptoms, reducing high-FODMAP foods (onions, garlic, beans, wheat, certain fruits) can ease bloating and pain.",
                source: "Monash University Low-FODMAP Diet Evidence (2023)"
            ))
            digestive.append(Warning(
                severity: .info, category: .digestive,
                title: "Track food–symptom correlations",
                detail: "Log meals alongside GI symptoms. Paya will surface patterns after 2+ weeks of data.",
                source: "ACG Clinical Guideline: IBS Management (2021)"
            ))
        }

        if conditions.contains("gerd") {
            nutrition.append(Warning(
                severity: .caution, category: .nutrition,
                title: "Avoid reflux trigger foods",
                detail: "Limit acidic, spicy, and fatty foods. Don't eat within 3 hours of lying down. Elevate head of bed if nighttime reflux affects sleep.",
                source: "ACG Clinical Guideline: GERD (2022)"
            ))
            exercise.append(Warning(
                severity: .info, category: .exercise,
                title: "Avoid supine exercises post-meal",
                detail: "Wait 2+ hours after eating before exercises that increase abdominal pressure (crunches, leg press, inverted positions).",
                source: "ACG GERD Management Recommendations"
            ))
        }

        if conditions.contains("kidney_disease") {
            nutrition.append(Warning(
                severity: .critical, category: .nutrition,
                title: "Protein and potassium limits",
                detail: "High-protein diets may accelerate kidney decline. Work with a renal dietitian for your stage-specific protein, potassium, and phosphorus targets.",
                source: "KDIGO CKD Guideline (2024)"
            ))
            supplements.append(Warning(
                severity: .warning, category: .supplement,
                title: "Avoid high-dose creatine",
                detail: "Creatine supplementation is not recommended with impaired kidney function. Creatinine levels will be artificially elevated, confusing lab results.",
                source: "KDIGO CKD Nutrition Guidance (2024)"
            ))
        }

        if conditions.contains("lupus") {
            exercise.append(Warning(
                severity: .caution, category: .exercise,
                title: "Pace activity to avoid flare triggers",
                detail: "Moderate, consistent exercise is beneficial — but overexertion and heat exposure can trigger flares. Monitor fatigue closely.",
                source: "ACR/EULAR SLE Management Guidelines (2023)"
            ))
            nutrition.append(Warning(
                severity: .info, category: .nutrition,
                title: "Anti-inflammatory diet recommended",
                detail: "Emphasize omega-3s, colorful vegetables, and whole grains. Minimize processed foods, added sugars, and saturated fats.",
                source: "Lupus Foundation of America Nutrition Guide"
            ))
        }

        if conditions.contains("fibromyalgia") {
            exercise.append(Warning(
                severity: .caution, category: .exercise,
                title: "Low-impact, gradual progression",
                detail: "Start with walking, swimming, or yoga. Increase volume slowly — too-fast progression worsens pain and fatigue for 48+ hours.",
                source: "EULAR Revised Recommendations for Fibromyalgia (2017)"
            ))
            sleep.append(Warning(
                severity: .info, category: .sleep,
                title: "Sleep quality is treatment-level important",
                detail: "Non-restorative sleep amplifies pain. Prioritize sleep hygiene: fixed schedule, cool room, no screens 1 hour before bed.",
                source: "ACR Fibromyalgia Diagnostic Criteria & Management (2016)"
            ))
        }

        if conditions.contains("endometriosis") {
            nutrition.append(Warning(
                severity: .caution, category: .nutrition,
                title: "Anti-inflammatory nutrition focus",
                detail: "Omega-3 fatty acids, turmeric, ginger, and leafy greens may help manage inflammation. Reduce red meat, trans fats, and alcohol.",
                source: "Hum Reprod Update meta-analysis on diet and endometriosis (2023)"
            ))
        }

        if conditions.contains("hypothyroidism") || conditions.contains("hashimotos") {
            supplements.append(Warning(
                severity: .caution, category: .supplement,
                title: "Separate thyroid meds from calcium/iron",
                detail: "Take levothyroxine on an empty stomach 30–60 min before food. Calcium, iron, and soy can block absorption.",
                source: "ATA Guidelines for Hypothyroidism (2014, reaffirmed 2023)"
            ))
            nutrition.append(Warning(
                severity: .info, category: .nutrition,
                title: "Ensure adequate selenium and iodine",
                detail: "Brazil nuts (1–2/day) cover selenium. Iodized salt and seaweed provide iodine. Both support thyroid hormone synthesis.",
                source: "ATA Thyroid Nutrition Recommendations"
            ))
        }

        if conditions.contains("asthma") {
            exercise.append(Warning(
                severity: .caution, category: .exercise,
                title: "Warm up thoroughly before cardio",
                detail: "Exercise-induced bronchoconstriction is common. A 10–15 min progressive warm-up reduces risk. Keep rescue inhaler accessible.",
                source: "GINA Global Strategy for Asthma Management (2023)"
            ))
        }

        if conditions.contains("epilepsy") {
            exercise.append(Warning(
                severity: .warning, category: .exercise,
                title: "Avoid unsupervised water/height activities",
                detail: "Swimming should always be supervised. Climbing and activities at height carry seizure-fall risk. Strength training on machines (not free weights) may be safer.",
                source: "Epilepsy Foundation Exercise Safety Guidelines"
            ))
            sleep.append(Warning(
                severity: .warning, category: .sleep,
                title: "Sleep deprivation is a seizure trigger",
                detail: "Maintain a strict sleep schedule. Avoid all-nighters. Sleep debt significantly lowers the seizure threshold.",
                source: "ILAE Position Paper on Sleep and Epilepsy (2022)"
            ))
        }

        if conditions.contains("pcos") {
            nutrition.append(Warning(
                severity: .caution, category: .nutrition,
                title: "Balance insulin with low-GI carbs",
                detail: "Choose whole grains, legumes, and non-starchy vegetables. Insulin resistance drives many PCOS symptoms; stable blood sugar helps.",
                source: "International PCOS Network Evidence-Based Guideline (2023)"
            ))
            exercise.append(Warning(
                severity: .info, category: .exercise,
                title: "Resistance training is especially beneficial",
                detail: "Strength training improves insulin sensitivity and androgen profiles in PCOS. Aim for 3+ sessions/week alongside moderate cardio.",
                source: "PCOS Guideline — Exercise Recommendations (2023)"
            ))
        }

        if conditions.contains("beta_thalassemia") {
            nutrition.append(Warning(
                severity: .warning, category: .nutrition,
                title: "Avoid excess iron supplementation",
                detail: "Thalassemia patients often have iron overload from transfusions. Do NOT take iron supplements unless specifically prescribed. Limit high-iron foods if ferritin is elevated.",
                source: "TIF Guidelines for Clinical Management of Thalassaemia (2023)"
            ))
            supplements.append(Warning(
                severity: .critical, category: .supplement,
                title: "Iron supplements contraindicated",
                detail: "Standard multivitamins often contain iron — check labels carefully. Iron overload damages the heart, liver, and endocrine organs.",
                source: "TIF Guidelines for Clinical Management of Thalassaemia (2023)"
            ))
        }

        if conditions.contains("sickle_cell") {
            exercise.append(Warning(
                severity: .warning, category: .exercise,
                title: "Avoid dehydration and extreme exertion",
                detail: "Stay well-hydrated during exercise. Avoid high altitude, extreme heat, and maximal sprints that can trigger sickling crises.",
                source: "ASH Sickle Cell Disease Guidelines (2020)"
            ))
        }

        if conditions.contains("ms") {
            exercise.append(Warning(
                severity: .caution, category: .exercise,
                title: "Watch for heat sensitivity (Uhthoff's)",
                detail: "Elevated core temperature can temporarily worsen MS symptoms. Exercise in cool environments, use cooling vests, and hydrate well.",
                source: "National MS Society Exercise Guidelines (2023)"
            ))
        }

        if conditions.contains("liver_disease") {
            supplements.append(Warning(
                severity: .warning, category: .supplement,
                title: "Avoid hepatotoxic supplements",
                detail: "Skip kava, comfrey, high-dose vitamin A, and unregulated herbal blends. The liver metabolizes everything — less is safer.",
                source: "AASLD Practice Guidance on Drug-Induced Liver Injury (2023)"
            ))
        }

        // ── Genetic disorder rules ───────────────────────────────────

        if genetics.contains("hemochromatosis") {
            nutrition.append(Warning(
                severity: .warning, category: .nutrition,
                title: "Limit dietary iron intake",
                detail: "Reduce red meat, organ meats, and iron-fortified cereals. Avoid vitamin C supplements with meals (enhances iron absorption). Tea/coffee with meals can reduce absorption.",
                source: "AASLD Practice Guideline: Hemochromatosis (2019)"
            ))
        }

        if genetics.contains("factor_v_leiden") || genetics.contains("clotting_disorder") {
            exercise.append(Warning(
                severity: .caution, category: .exercise,
                title: "Stay mobile during rest days",
                detail: "Avoid prolonged sitting or immobility. Light walking on rest days supports circulation. Compression garments may help during long sedentary periods.",
                source: "ASH VTE Prevention Guidelines (2021)"
            ))
        }

        if genetics.contains("g6pd_deficiency") {
            supplements.append(Warning(
                severity: .warning, category: .supplement,
                title: "Avoid high-dose vitamin C supplements",
                detail: "Doses above 1g can trigger hemolytic crisis in G6PD deficiency. Also avoid fava beans and certain medications — check with your doctor.",
                source: "WHO G6PD Deficiency Technical Guidelines"
            ))
        }

        // ── Allergy rules ────────────────────────────────────────────

        if allergies.contains("lactose") {
            nutrition.append(Warning(
                severity: .info, category: .nutrition,
                title: "Use lactose-free protein sources",
                detail: "Plant-based protein powders (pea, rice, hemp) or whey isolate (very low lactose) are alternatives. Check supplement labels for milk derivatives.",
                source: "General nutrition guidance"
            ))
        }

        if allergies.contains("gluten") && !conditions.contains("celiac") {
            nutrition.append(Warning(
                severity: .caution, category: .nutrition,
                title: "Non-celiac gluten sensitivity noted",
                detail: "Avoid gluten-containing grains if symptomatic. Unlike celiac, trace amounts may be tolerated — individual threshold varies.",
                source: "Gastroenterology journal: NCGS consensus (2015)"
            ))
        }

        if allergies.contains("shellfish") || allergies.contains("fish") {
            supplements.append(Warning(
                severity: .caution, category: .supplement,
                title: "Fish oil / omega-3 alternative needed",
                detail: "Algal oil DHA/EPA is a safe alternative to fish oil for omega-3 supplementation with seafood allergies.",
                source: "ACAAI Allergy Management Guidelines"
            ))
        }

        if allergies.contains("soy") {
            nutrition.append(Warning(
                severity: .info, category: .nutrition,
                title: "Soy-free protein alternatives",
                detail: "Many protein bars and shakes contain soy lecithin or soy protein isolate. Check labels. Rice, pea, and hemp proteins are soy-free.",
                source: "General nutrition guidance"
            ))
        }

        if allergies.contains("eggs") {
            nutrition.append(Warning(
                severity: .info, category: .nutrition,
                title: "Egg-free nutrition planning",
                detail: "Replace eggs with other complete proteins: Greek yogurt, cottage cheese, poultry, fish, or plant combos (rice + beans). Check protein bar ingredients.",
                source: "General nutrition guidance"
            ))
        }

        // ── Medication interaction rules ─────────────────────────────

        let onWarfarin = meds.contains("warfarin") || meds.contains("coumadin")
        if onWarfarin {
            nutrition.append(Warning(
                severity: .critical, category: .nutrition,
                title: "Keep vitamin K intake consistent",
                detail: "Don't suddenly increase or decrease leafy greens (spinach, kale, broccoli). Consistency matters more than avoidance — drastic changes destabilize INR.",
                source: "AHA Warfarin-Diet Interaction Guidance"
            ))
            supplements.append(Warning(
                severity: .critical, category: .supplement,
                title: "Many supplements interact with warfarin",
                detail: "Fish oil, vitamin E, garlic, ginkgo, and turmeric can increase bleeding risk. Always check with your prescriber before adding any supplement.",
                source: "Clinical Pharmacology warfarin interaction database"
            ))
        }

        let onMetformin = meds.contains("metformin") || meds.contains("glucophage")
        if onMetformin {
            supplements.append(Warning(
                severity: .caution, category: .supplement,
                title: "Monitor B12 levels",
                detail: "Long-term metformin use can deplete vitamin B12. Consider periodic testing and supplementation if levels drop.",
                source: "ADA Standards of Care — Metformin & B12 (2024)"
            ))
        }

        let onStatins = meds.contains { $0.contains("statin") || $0.hasSuffix("vastatin") }
        if onStatins {
            supplements.append(Warning(
                severity: .info, category: .supplement,
                title: "CoQ10 may help statin-related muscle pain",
                detail: "Some evidence suggests 100–200 mg/day CoQ10 reduces statin myopathy. Discuss with your prescriber.",
                source: "JACC Review: CoQ10 and Statin Myopathy (2018)"
            ))
        }

        let onSSRI = meds.contains { $0.contains("fluoxetine") || $0.contains("sertraline") || $0.contains("escitalopram") || $0.contains("paroxetine") || $0.contains("citalopram") || $0.contains("ssri") }
        if onSSRI {
            supplements.append(Warning(
                severity: .warning, category: .supplement,
                title: "Avoid St. John's Wort with SSRIs",
                detail: "Combining SSRIs with St. John's Wort can cause serotonin syndrome — a potentially dangerous condition. Also avoid 5-HTP and high-dose tryptophan.",
                source: "FDA Drug Safety Communication — Serotonin Syndrome"
            ))
        }

        let onBetaBlocker = meds.contains { $0.contains("atenolol") || $0.contains("metoprolol") || $0.contains("propranolol") || $0.contains("bisoprolol") || $0.contains("beta blocker") || $0.contains("beta-blocker") }
        if onBetaBlocker {
            exercise.append(Warning(
                severity: .warning, category: .exercise,
                title: "HR-based intensity unreliable on beta-blockers",
                detail: "Beta-blockers suppress heart rate. Use RPE (rate of perceived exertion) instead of heart rate zones to gauge exercise intensity.",
                source: "ACSM Guidelines for Exercise Testing — Beta-blocker Considerations"
            ))
        }

        // ── Mental health rules ──────────────────────────────────────

        if mentalRaw.contains("eating_disorder") {
            mentalHealth.append(Warning(
                severity: .critical, category: .mentalHealth,
                title: "Calorie tracking may be triggering",
                detail: "Paya can hide calorie numbers and focus on nutrient quality instead. If calorie counting causes distress, consider enabling 'gentle mode' in Settings.",
                source: "APA Eating Disorders Treatment Guidelines (2023)"
            ))
            nutrition.append(Warning(
                severity: .warning, category: .nutrition,
                title: "Focus on nourishment, not restriction",
                detail: "Your nutrition view will emphasize food groups and micronutrient balance rather than deficits. No 'good/bad' food labels.",
                source: "NEDA Recovery-Sensitive Fitness Guidance"
            ))
        }

        if mentalRaw.contains("anxiety") {
            mentalHealth.append(Warning(
                severity: .info, category: .mentalHealth,
                title: "Exercise as anxiety management",
                detail: "Regular moderate exercise reduces anxiety symptoms. Paya will celebrate consistency and gentle progress — never shame missed days.",
                source: "Lancet Psychiatry meta-analysis: Exercise and Mental Health (2018)"
            ))
            sleep.append(Warning(
                severity: .info, category: .sleep,
                title: "Caffeine cutoff matters more with anxiety",
                detail: "Consider cutting caffeine by 12 PM (earlier if sensitive). Caffeine's half-life is 5–6 hours and amplifies anxious arousal.",
                source: "Sleep Foundation — Caffeine and Anxiety"
            ))
        }

        if mentalRaw.contains("depression") {
            mentalHealth.append(Warning(
                severity: .info, category: .mentalHealth,
                title: "Movement is medicine — any amount counts",
                detail: "Even 15 minutes of walking significantly improves mood. Paya recognizes all movement, not just gym sessions.",
                source: "JAMA Psychiatry: Dose-response of exercise on depression (2022)"
            ))
        }

        if mentalRaw.contains("adhd") {
            mentalHealth.append(Warning(
                severity: .info, category: .mentalHealth,
                title: "Exercise improves ADHD focus",
                detail: "20+ minutes of cardio boosts dopamine and norepinephrine — the same neurotransmitters ADHD meds target. Morning exercise can improve focus all day.",
                source: "Harvard Health: ADHD and Exercise (Ratey, 2019)"
            ))
        }

        if mentalRaw.contains("bipolar") {
            sleep.append(Warning(
                severity: .warning, category: .sleep,
                title: "Sleep regularity is critical for mood stability",
                detail: "Irregular sleep is a strong trigger for manic and depressive episodes. Maintain the same sleep/wake time ±30 minutes, even on weekends.",
                source: "ISBD Treatment Guidelines for Bipolar Disorder (2018)"
            ))
        }

        if mentalRaw.contains("ptsd") {
            mentalHealth.append(Warning(
                severity: .info, category: .mentalHealth,
                title: "Body-aware exercise may help",
                detail: "Yoga, tai chi, and mindful strength training can rebuild body connection. Paya supports unstructured 'just move' sessions alongside programmed training.",
                source: "VA/DoD Clinical Practice Guideline for PTSD (2023)"
            ))
        }

        // ── Sleep disorder rules ─────────────────────────────────────

        if sleepDisorders.contains("sleep_apnea") {
            sleep.append(Warning(
                severity: .warning, category: .sleep,
                title: "Weight management helps sleep apnea",
                detail: "Even 5–10% weight loss can significantly reduce apnea severity. Track weight trends in Paya alongside sleep quality.",
                source: "AASM Clinical Practice Guideline: OSA Treatment (2021)"
            ))
        }

        if sleepDisorders.contains("insomnia") {
            sleep.append(Warning(
                severity: .caution, category: .sleep,
                title: "Exercise timing affects insomnia",
                detail: "Finish vigorous exercise 3+ hours before bed. Morning or early afternoon exercise is best for sleep-onset insomnia.",
                source: "Sleep Medicine Reviews: Exercise and Insomnia meta-analysis (2021)"
            ))
        }

        if sleepDisorders.contains("restless_legs") {
            supplements.append(Warning(
                severity: .info, category: .supplement,
                title: "Check iron and magnesium levels",
                detail: "Low ferritin (<75 ng/mL) and magnesium deficiency are common in RLS. Supplementing may help — get levels tested first.",
                source: "IRLSSG Revised Treatment Guidelines (2022)"
            ))
        }

        // ── Lifestyle rules ──────────────────────────────────────────

        if profile.occupationTypeRaw == "shiftWork" {
            sleep.append(Warning(
                severity: .caution, category: .sleep,
                title: "Shift-work circadian support",
                detail: "Use bright light exposure at the start of your shift and melatonin 30 min before your intended sleep. Keep your sleep environment dark with blackout curtains.",
                source: "AASM Clinical Practice Guideline: Shift Work Disorder (2015)"
            ))
        }

        if profile.smokingStatusRaw == "current" {
            exercise.append(Warning(
                severity: .info, category: .exercise,
                title: "Exercise supports smoking cessation",
                detail: "Regular exercise reduces nicotine cravings and withdrawal symptoms. Even 5 minutes of brisk walking can curb an acute craving.",
                source: "Cochrane Review: Exercise for Smoking Cessation (2019)"
            ))
        }

        if profile.alcoholFrequencyRaw == "heavy" {
            nutrition.append(Warning(
                severity: .warning, category: .nutrition,
                title: "Alcohol impairs recovery and muscle synthesis",
                detail: "Heavy alcohol consumption reduces muscle protein synthesis by up to 37%, impairs sleep quality, and depletes B vitamins, zinc, and magnesium.",
                source: "PLOS ONE: Alcohol and Muscle Protein Synthesis (Parr et al., 2014)"
            ))
        }

        // ── Surgery / mobility rules ─────────────────────────────────

        if surgeries.contains("knee_surgery") || surgeries.contains("acl_reconstruction") {
            exercise.append(Warning(
                severity: .caution, category: .exercise,
                title: "Knee-safe exercise modifications",
                detail: "Avoid deep squats beyond 90° and high-impact plyometrics unless cleared by your physio. Focus on quad and hamstring strengthening.",
                source: "AAOS ACL Reconstruction Rehabilitation Protocol"
            ))
        }

        if surgeries.contains("spinal_surgery") || surgeries.contains("back_surgery") {
            exercise.append(Warning(
                severity: .warning, category: .exercise,
                title: "Spinal-safe loading only",
                detail: "Avoid heavy axial loading (back squats, deadlifts) until cleared. Core stability exercises (McGill big 3: curl-up, side plank, bird-dog) are the foundation.",
                source: "McGill (2015) — Low Back Disorders: Evidence-Based Prevention and Rehabilitation"
            ))
        }

        if surgeries.contains("shoulder_surgery") || surgeries.contains("rotator_cuff") {
            exercise.append(Warning(
                severity: .caution, category: .exercise,
                title: "Shoulder ROM precautions",
                detail: "Avoid overhead pressing and behind-the-neck movements until full range of motion is restored. Band exercises for external rotation are rehab-first.",
                source: "AAOS Rotator Cuff Repair Rehabilitation Protocol"
            ))
        }

        // Sort each category by severity (most critical first)
        return ContraindicationReport(
            nutritionWarnings: nutrition.sorted { $0.severity > $1.severity },
            supplementWarnings: supplements.sorted { $0.severity > $1.severity },
            exerciseWarnings: exercise.sorted { $0.severity > $1.severity },
            sleepGuidance: sleep.sorted { $0.severity > $1.severity },
            mentalHealthNotes: mentalHealth.sorted { $0.severity > $1.severity },
            digestiveNotes: digestive.sorted { $0.severity > $1.severity }
        )
    }

    // MARK: - AI Prompt Enrichment

    /// Builds a prompt-injection block that any AI service (Claude, Gemini)
    /// can prepend to make its responses condition-aware.
    static func promptContext(for profile: PersonProfile) -> String {
        let report = generate(for: profile)
        guard !report.isEmpty else { return "" }

        var lines: [String] = []
        lines.append("HEALTH PROFILE CONSTRAINTS (user-reported, not diagnosed by this app):")
        lines.append("")

        if !profile.chronicConditionsRaw.isEmpty {
            lines.append("Chronic conditions: \(profile.chronicConditionsRaw.joined(separator: ", "))")
        }
        if !profile.geneticDisordersRaw.isEmpty {
            lines.append("Genetic factors: \(profile.geneticDisordersRaw.joined(separator: ", "))")
        }
        if !profile.allergiesRaw.isEmpty {
            lines.append("Allergies/intolerances: \(profile.allergiesRaw.joined(separator: ", "))")
        }
        if !profile.medicationsRaw.isEmpty {
            lines.append("Current medications: \(profile.medicationsRaw.joined(separator: ", "))")
        }
        if !profile.mentalHealthConditionsRaw.isEmpty {
            lines.append("Mental health: \(profile.mentalHealthConditionsRaw.joined(separator: ", "))")
        }
        if !profile.sleepDisordersRaw.isEmpty {
            lines.append("Sleep disorders: \(profile.sleepDisordersRaw.joined(separator: ", "))")
        }

        lines.append("")
        lines.append("KEY CONTRAINDICATIONS:")

        for w in report.allWarnings where w.severity >= .caution {
            lines.append("• [\(w.severity.rawValue.uppercased())] \(w.title): \(w.detail)")
        }

        lines.append("")
        lines.append("Respect ALL of the above constraints in your recommendations. Never suggest foods, supplements, or exercises that conflict with these conditions. When in doubt, recommend the safer option and advise consulting a healthcare provider.")

        return lines.joined(separator: "\n")
    }
}

// MARK: - Set helper for medication matching

private extension Set where Element == String {
    func contains(where predicate: (String) -> Bool) -> Bool {
        first(where: predicate) != nil
    }
}
