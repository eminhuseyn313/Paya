import SwiftUI
import SwiftData

// MARK: - Health Journey
//
// A guided 12-screen flow that deeply profiles the user's health to power
// HealthContraindicationEngine and enrich every AI recommendation.
//
// Designed as a standalone flow accessible from:
//   • Post-onboarding prompt ("Complete your health profile")
//   • Settings → Health Journey
//   • Home banner when journey is incomplete
//
// The flow writes directly to PersonProfile — no intermediate model.
// Each screen is self-contained; the user can leave and resume.

struct HealthJourneyView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let profile: PersonProfile
    var onComplete: (() -> Void)? = nil

    private static let totalSteps = 12

    @State private var step: Int = 0
    @State private var showContraindicationPreview = false

    // ── Step 1: Basic info (pre-filled from onboarding) ──
    @State private var bloodType: String = ""

    // ── Step 2: Chronic conditions ──
    @State private var selectedConditions: Set<String> = []

    // ── Step 3: Genetic disorders ──
    @State private var selectedGenetics: Set<String> = []

    // ── Step 4: Allergies ──
    @State private var selectedAllergies: Set<String> = []
    @State private var customAllergy: String = ""

    // ── Step 5: Medications ──
    @State private var medications: [String] = []
    @State private var newMedication: String = ""

    // ── Step 6: Supplements ──
    @State private var supplements: [String] = []
    @State private var newSupplement: String = ""

    // ── Step 7: Lifestyle ──
    @State private var occupation: String = "sedentary"
    @State private var smokingStatus: String = "never"
    @State private var alcoholFrequency: String = "none"
    @State private var screenTime: Double = 6

    // ── Step 8: Sleep ──
    @State private var sleepDisorders: Set<String> = []

    // ── Step 9: Mental health ──
    @State private var mentalConditions: Set<String> = []

    // ── Step 10: Digestive & Urinary ──
    @State private var digestiveIssues: Set<String> = []
    @State private var dailyUrinations: Int = 6
    @State private var dailyBowels: Int = 1

    // ── Step 11: Exercise history ──
    @State private var pastSurgeries: Set<String> = []
    @State private var mobilityLimits: Set<String> = []

    // ── Step 12: Goals ──
    @State private var healthGoals: Set<String> = []

    // MARK: - Colors

    private let accentGradient = LinearGradient(
        colors: [Color(hex: "8B7BF7"), Color(hex: "4A9BFF")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    private let accent = Color(hex: "8B7BF7")

    // MARK: - Init from existing profile

    init(profile: PersonProfile, onComplete: (() -> Void)? = nil) {
        self.profile = profile
        self.onComplete = onComplete

        // Pre-fill from existing profile data
        _bloodType = State(initialValue: profile.bloodTypeRaw)
        _selectedConditions = State(initialValue: Set(profile.chronicConditionsRaw))
        _selectedGenetics = State(initialValue: Set(profile.geneticDisordersRaw))
        _selectedAllergies = State(initialValue: Set(profile.allergiesRaw))
        _medications = State(initialValue: profile.medicationsRaw)
        // Split stored supplements into preset-selected vs custom free-text
        let presetIds = Set(Self.supplementOptions.map(\.id))
        let stored = profile.currentSupplementsRaw
        _selectedSupplements = State(initialValue: Set(stored.filter { presetIds.contains($0) }))
        _supplements = State(initialValue: stored.filter { !presetIds.contains($0) })
        _occupation = State(initialValue: profile.occupationTypeRaw)
        _smokingStatus = State(initialValue: profile.smokingStatusRaw)
        _alcoholFrequency = State(initialValue: profile.alcoholFrequencyRaw)
        _screenTime = State(initialValue: profile.dailyScreenTimeHours)
        _sleepDisorders = State(initialValue: Set(profile.sleepDisordersRaw))
        _mentalConditions = State(initialValue: Set(profile.mentalHealthConditionsRaw))
        _digestiveIssues = State(initialValue: Set(profile.digestiveIssuesRaw))
        _dailyUrinations = State(initialValue: profile.averageDailyUrinations)
        _dailyBowels = State(initialValue: profile.averageDailyBowelMovements)
        _pastSurgeries = State(initialValue: Set(profile.pastSurgeriesRaw))
        _mobilityLimits = State(initialValue: Set(profile.mobilityLimitationsRaw))
        _healthGoals = State(initialValue: Set(profile.healthGoalsRaw))
    }

    var body: some View {
        ZStack {
            // Background
            Pulse.canvasFallback.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress header
                progressHeader

                // Step content — each step is a full ScrollView.
                // Step changes are NOT wrapped in withAnimation to avoid
                // SwiftUI keeping the old view alive during the animation,
                // which blocks touch delivery on the new content.
                // The progress bar capsules animate independently via their
                // own .animation(.spring(response:0.3), value: step) modifier.
                stepContent
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showContraindicationPreview) {
            ContraindicationPreviewSheet(profile: profile)
        }
    }

    // MARK: - Step Content Router

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:  basicInfoStep
        case 1:  chronicConditionsStep
        case 2:  geneticDisordersStep
        case 3:  allergiesStep
        case 4:  medicationsStep
        case 5:  supplementsStep
        case 6:  lifestyleStep
        case 7:  sleepStep
        case 8:  mentalHealthStep
        case 9:  digestiveStep
        case 10: exerciseHistoryStep
        case 11: goalsAndSummaryStep
        default: EmptyView()
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    if step > 0 {
                        step -= 1
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: step > 0 ? "chevron.left" : "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundColor(Pulse.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Pulse.surfaceFallback)
                        .clipShape(Circle())
                }

                // Segmented progress bar
                HStack(spacing: 3) {
                    ForEach(0..<Self.totalSteps, id: \.self) { i in
                        Capsule()
                            .fill(i <= step ? accent : Color.white.opacity(0.1))
                            .frame(height: 3)
                            .animation(.spring(response: 0.3), value: step)
                    }
                }

                Text("\(step + 1)/\(Self.totalSteps)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Pulse.textTertiary)
                    .frame(width: 36)
            }
            .padding(.horizontal, 20)

            // Step title
            Text(stepTitle)
                .font(.caption2.weight(.bold))
                .foregroundColor(accent)
                .textCase(.uppercase)
                .tracking(1.2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var stepTitle: String {
        switch step {
        case 0: return "Basic Info"
        case 1: return "Chronic Conditions"
        case 2: return "Genetic Factors"
        case 3: return "Allergies & Intolerances"
        case 4: return "Medications"
        case 5: return "Supplements"
        case 6: return "Lifestyle"
        case 7: return "Sleep"
        case 8: return "Mental Health"
        case 9: return "Digestive & Urinary"
        case 10: return "Exercise History"
        case 11: return "Goals & Summary"
        default: return ""
        }
    }

    // MARK: ─── Step 1: Basic Info ───

    private var basicInfoStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                journeyHero(
                    icon: "heart.text.clipboard.fill",
                    color: Pulse.vitals,
                    title: "Your Health Journey",
                    subtitle: "Answer what you're comfortable with — every answer makes Paya smarter about what's safe and effective for you."
                )

                // Blood type picker
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Blood type (optional)")

                    let bloodTypes = ["", "A+", "A−", "B+", "B−", "AB+", "AB−", "O+", "O−"]
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 8)], spacing: 8) {
                        ForEach(bloodTypes, id: \.self) { bt in
                            Button {
                                withAnimation(.spring(response: 0.2)) { bloodType = bt }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text(bt.isEmpty ? "Skip" : bt)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(bloodType == bt ? .white : Pulse.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(bloodType == bt ? accent : Pulse.surfaceFallback)
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Info card
                infoCard(
                    icon: "shield.checkered",
                    text: "Your data stays on-device. Nothing is shared with insurance, employers, or third parties. Ever."
                )

                continueButton { step = 1 }

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: ─── Step 2: Chronic Conditions ───

    private static let chronicConditionOptions: [(id: String, name: String, icon: String)] = [
        ("rheumatoid_arthritis", "Rheumatoid arthritis", "figure.walk"),
        ("psoriatic_arthritis", "Psoriatic arthritis", "figure.walk"),
        ("ankylosing_spondylitis", "Ankylosing spondylitis", "figure.walk"),
        ("lupus", "Lupus (SLE)", "sun.max.fill"),
        ("fibromyalgia", "Fibromyalgia", "waveform.path.ecg"),
        ("pcos", "Polycystic ovary syndrome", "circle.hexagongrid.fill"),
        ("diabetes_t1", "Type 1 diabetes", "drop.fill"),
        ("diabetes_t2", "Type 2 diabetes", "drop.fill"),
        ("hypertension", "Hypertension", "heart.fill"),
        ("heart_failure", "Heart failure", "heart.slash.fill"),
        ("afib", "Atrial fibrillation", "waveform.path.ecg"),
        ("myocarditis", "Myocarditis", "heart.fill"),
        ("asthma", "Asthma", "lungs.fill"),
        ("crohns", "Crohn's disease", "stomach"),
        ("celiac", "Celiac disease", "leaf.fill"),
        ("ibs", "Irritable bowel syndrome", "stomach"),
        ("gerd", "GERD / acid reflux", "flame.fill"),
        ("hypothyroidism", "Hypothyroidism", "bolt.fill"),
        ("hashimotos", "Hashimoto's thyroiditis", "bolt.fill"),
        ("endometriosis", "Endometriosis", "staroflife.fill"),
        ("ms", "Multiple sclerosis", "brain.head.profile"),
        ("epilepsy", "Epilepsy", "bolt.trianglebadge.exclamationmark"),
        ("beta_thalassemia", "Beta thalassemia", "drop.fill"),
        ("sickle_cell", "Sickle cell disease", "drop.fill"),
        ("kidney_disease", "Chronic kidney disease", "cross.vial.fill"),
        ("liver_disease", "Liver disease", "cross.vial.fill"),
    ]

    private var chronicConditionsStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                journeyHero(
                    icon: "stethoscope",
                    color: Pulse.vitals,
                    title: "Any chronic conditions?",
                    subtitle: "Select all that apply. This shapes exercise safety limits, nutrition guidance, and supplement warnings."
                )

                multiSelectGrid(
                    items: Self.chronicConditionOptions,
                    selected: $selectedConditions,
                    color: Pulse.vitals
                )
                .padding(.horizontal, 20)

                skipOrContinue { step = 2 }

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: ─── Step 3: Genetic Disorders ───

    private static let geneticOptions: [(id: String, name: String, icon: String)] = [
        ("hemochromatosis", "Hemochromatosis", "drop.fill"),
        ("factor_v_leiden", "Factor V Leiden", "drop.fill"),
        ("clotting_disorder", "Other clotting disorder", "bandage.fill"),
        ("g6pd_deficiency", "G6PD deficiency", "testtube.2"),
        ("familial_hypercholesterolemia", "Familial high cholesterol", "heart.fill"),
        ("marfan_syndrome", "Marfan syndrome", "figure.stand"),
        ("ehlers_danlos", "Ehlers-Danlos syndrome", "figure.flexibility"),
        ("cystic_fibrosis", "Cystic fibrosis", "lungs.fill"),
        ("wilsons_disease", "Wilson's disease", "cross.vial.fill"),
        ("huntingtons", "Huntington's disease", "brain.head.profile"),
    ]

    private var geneticDisordersStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                journeyHero(
                    icon: "dna",
                    color: Color(hex: "4AE68A"),
                    title: "Genetic factors",
                    subtitle: "Known genetic conditions or strong family history. Helps catch supplement and dietary interactions."
                )

                multiSelectGrid(
                    items: Self.geneticOptions,
                    selected: $selectedGenetics,
                    color: Color(hex: "4AE68A")
                )
                .padding(.horizontal, 20)

                skipOrContinue { step = 3 }

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: ─── Step 4: Allergies ───

    private static let allergyOptions: [(id: String, name: String, icon: String)] = [
        ("lactose", "Lactose intolerance", "cup.and.saucer.fill"),
        ("gluten", "Gluten sensitivity", "leaf.fill"),
        ("nuts", "Tree nut allergy", "leaf.fill"),
        ("peanuts", "Peanut allergy", "leaf.fill"),
        ("shellfish", "Shellfish allergy", "fish.fill"),
        ("fish", "Fish allergy", "fish.fill"),
        ("soy", "Soy allergy", "leaf.fill"),
        ("eggs", "Egg allergy", "oval.fill"),
        ("dairy", "Dairy allergy", "cup.and.saucer.fill"),
        ("sulfites", "Sulfite sensitivity", "flask.fill"),
        ("histamine", "Histamine intolerance", "allergens.fill"),
        ("allergic_rhinitis", "Allergic rhinitis", "nose.fill"),
    ]

    private var allergiesStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                journeyHero(
                    icon: "exclamationmark.triangle.fill",
                    color: Pulse.warning,
                    title: "Allergies & intolerances",
                    subtitle: "We'll filter nutrition suggestions and flag supplements that contain these."
                )

                multiSelectGrid(
                    items: Self.allergyOptions,
                    selected: $selectedAllergies,
                    color: Pulse.warning
                )
                .padding(.horizontal, 20)

                // Custom allergy entry
                HStack(spacing: 8) {
                    TextField("Other allergy...", text: $customAllergy)
                        .font(.subheadline)
                        .padding(12)
                        .background(Pulse.surfaceFallback)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    if !customAllergy.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button {
                            let trimmed = customAllergy.trimmingCharacters(in: .whitespaces).lowercased()
                            selectedAllergies.insert(trimmed)
                            customAllergy = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(Pulse.warning)
                        }
                    }
                }
                .padding(.horizontal, 20)

                skipOrContinue { step = 4 }

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: ─── Step 5: Medications ───

    private var medicationsStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                journeyHero(
                    icon: "pills.fill",
                    color: Color(hex: "FF6B3D"),
                    title: "Current medications",
                    subtitle: "List your prescriptions so we can check for supplement interactions and exercise precautions."
                )

                freeTextListEditor(
                    items: $medications,
                    newItem: $newMedication,
                    placeholder: "e.g. Metformin, Levothyroxine...",
                    color: Color(hex: "FF6B3D")
                )
                .padding(.horizontal, 20)

                infoCard(
                    icon: "lock.shield.fill",
                    text: "Medication names stay on-device only. They're used to match known interaction rules — never sent to external APIs."
                )

                skipOrContinue { step = 5 }

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: ─── Step 6: Supplements ───

    // Popular supplements — the top selections people commonly take.
    // UserDefaults tracks custom additions so the most-added ones can be
    // promoted into the preset list in future versions.
    private static let supplementOptions: [(id: String, name: String, icon: String)] = [
        ("vitamin_d", "Vitamin D", "sun.max.fill"),
        ("fish_oil", "Fish oil / Omega-3", "drop.fill"),
        ("creatine", "Creatine", "bolt.fill"),
        ("magnesium", "Magnesium", "moon.fill"),
        ("zinc", "Zinc", "shield.fill"),
        ("vitamin_c", "Vitamin C", "leaf.fill"),
        ("iron", "Iron", "flame.fill"),
        ("b12", "Vitamin B12", "bolt.circle.fill"),
        ("multivitamin", "Multivitamin", "pills.fill"),
        ("protein_powder", "Protein powder", "cup.and.saucer.fill"),
        ("probiotics", "Probiotics", "stomach"),
        ("collagen", "Collagen", "figure.walk"),
        ("vitamin_b_complex", "B-Complex", "bolt.fill"),
        ("calcium", "Calcium", "bone"),
        ("coq10", "CoQ10", "heart.fill"),
        ("ashwagandha", "Ashwagandha", "leaf.fill"),
        ("melatonin", "Melatonin", "moon.stars.fill"),
        ("turmeric", "Turmeric / Curcumin", "leaf.fill"),
    ]

    @State private var selectedSupplements: Set<String> = []

    private var supplementsStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                journeyHero(
                    icon: "cross.vial.fill",
                    color: Color(hex: "FFB547"),
                    title: "Current supplements",
                    subtitle: "What are you already taking? We'll check for duplications, interactions, and whether they make sense for your profile."
                )

                // Preset grid
                multiSelectGrid(
                    items: Self.supplementOptions,
                    selected: $selectedSupplements,
                    color: Color(hex: "FFB547")
                )
                .padding(.horizontal, 20)

                // Custom supplement entry
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("Other supplements")
                    freeTextListEditor(
                        items: $supplements,
                        newItem: $newSupplement,
                        placeholder: "e.g. Spirulina, L-Theanine...",
                        color: Color(hex: "FFB547")
                    )
                }
                .padding(.horizontal, 20)

                skipOrContinue { step = 6 }

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: ─── Step 7: Lifestyle ───

    private var lifestyleStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                journeyHero(
                    icon: "figure.walk.motion",
                    color: Pulse.energy,
                    title: "Your lifestyle",
                    subtitle: "Daily habits shape recovery, sleep quality, and how your body responds to training."
                )

                // Occupation type
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Daily activity level")
                    singleSelectList(
                        options: [
                            ("sedentary", "Mostly sitting", "chair.fill"),
                            ("active", "On my feet / manual work", "figure.walk"),
                            ("veryActive", "Physically demanding job", "figure.strengthtraining.traditional"),
                            ("shiftWork", "Shift / night work", "moon.fill"),
                        ],
                        selected: $occupation,
                        color: Pulse.energy
                    )
                }
                .padding(.horizontal, 20)

                // Smoking
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Smoking status")
                    singleSelectList(
                        options: [
                            ("never", "Never smoked", "checkmark.circle.fill"),
                            ("former", "Former smoker", "clock.fill"),
                            ("current", "Current smoker", "smoke.fill"),
                        ],
                        selected: $smokingStatus,
                        color: Pulse.energy
                    )
                }
                .padding(.horizontal, 20)

                // Alcohol
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Alcohol consumption")
                    singleSelectList(
                        options: [
                            ("none", "None", "checkmark.circle.fill"),
                            ("occasional", "Occasional (1–3/week)", "drop.fill"),
                            ("moderate", "Moderate (4–7/week)", "drop.fill"),
                            ("heavy", "Heavy (8+/week)", "exclamationmark.triangle.fill"),
                        ],
                        selected: $alcoholFrequency,
                        color: Pulse.energy
                    )
                }
                .padding(.horizontal, 20)

                // Screen time
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        sectionLabel("Daily screen time")
                        Spacer()
                        Text("\(Int(screenTime))h")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(Pulse.textPrimary)
                    }
                    Slider(value: $screenTime, in: 1...16, step: 1)
                        .tint(Pulse.energy)
                    Button {
                        if let url = URL(string: "App-prefs:SCREEN_TIME") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "iphone.badge.play")
                                .font(.caption2)
                            Text("Open Screen Time Settings to check your average")
                                .font(.caption2)
                        }
                        .foregroundColor(accent)
                    }
                    .buttonStyle(.plain)
                }
                .pulseSurface(radius: 14, padding: 14)
                .padding(.horizontal, 20)

                continueButton { step = 7 }

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: ─── Step 8: Sleep ───

    private static let sleepDisorderOptions: [(id: String, name: String, icon: String)] = [
        ("insomnia", "Insomnia", "moon.zzz.fill"),
        ("sleep_apnea", "Sleep apnea", "lungs.fill"),
        ("restless_legs", "Restless leg syndrome", "figure.walk"),
        ("narcolepsy", "Narcolepsy", "bed.double.fill"),
        ("delayed_phase", "Delayed sleep phase", "clock.fill"),
        ("shift_disorder", "Shift-work sleep disorder", "moon.fill"),
    ]

    private var sleepStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                journeyHero(
                    icon: "moon.stars.fill",
                    color: Pulse.recovery,
                    title: "Sleep patterns",
                    subtitle: "Sleep disorders change recovery timelines and caffeine guidance. Select any that apply."
                )

                multiSelectGrid(
                    items: Self.sleepDisorderOptions,
                    selected: $sleepDisorders,
                    color: Pulse.recovery
                )
                .padding(.horizontal, 20)

                skipOrContinue { step = 8 }

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: ─── Step 9: Mental Health ───

    private static let mentalHealthOptions: [(id: String, name: String, icon: String)] = [
        ("anxiety", "Anxiety", "waveform.path.ecg"),
        ("depression", "Depression", "cloud.rain.fill"),
        ("adhd", "ADHD", "bolt.fill"),
        ("bipolar", "Bipolar disorder", "arrow.up.arrow.down"),
        ("ptsd", "PTSD", "shield.fill"),
        ("eating_disorder", "Eating disorder (current or past)", "fork.knife"),
        ("ocd", "OCD", "repeat"),
        ("insomnia_anxiety", "Sleep anxiety", "moon.zzz.fill"),
    ]

    private var mentalHealthStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                journeyHero(
                    icon: "brain.head.profile.fill",
                    color: Pulse.ai,
                    title: "Mental health",
                    subtitle: "This shapes how Paya talks to you — the language it uses, what it celebrates, and what it never says."
                )

                multiSelectGrid(
                    items: Self.mentalHealthOptions,
                    selected: $mentalConditions,
                    color: Pulse.ai
                )
                .padding(.horizontal, 20)

                infoCard(
                    icon: "heart.fill",
                    text: "Paya is not a therapist. If you're in crisis, please reach out to a mental health professional or call 988 (Suicide & Crisis Lifeline)."
                )

                skipOrContinue { step = 9 }

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: ─── Step 10: Digestive & Urinary ───

    private static let digestiveOptions: [(id: String, name: String, icon: String)] = [
        ("bloating", "Frequent bloating", "stomach"),
        ("constipation", "Chronic constipation", "arrow.down.circle"),
        ("diarrhea", "Chronic diarrhea", "arrow.down.circle.fill"),
        ("acid_reflux", "Acid reflux", "flame.fill"),
        ("food_sensitivity", "Unidentified food sensitivities", "questionmark.circle.fill"),
        ("uti_prone", "Recurring UTIs", "drop.fill"),
    ]

    private var digestiveStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                journeyHero(
                    icon: "stomach",
                    color: Color(hex: "059669"),
                    title: "Digestive & urinary",
                    subtitle: "Baseline info helps Paya spot changes and correlate with diet, hydration, and supplements."
                )

                multiSelectGrid(
                    items: Self.digestiveOptions,
                    selected: $digestiveIssues,
                    color: Color(hex: "059669")
                )
                .padding(.horizontal, 20)

                // Baseline numbers
                VStack(spacing: 12) {
                    HStack {
                        Text("Avg. daily urinations")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Pulse.textPrimary)
                        Spacer()
                        Stepper("\(dailyUrinations)", value: $dailyUrinations, in: 1...20)
                            .labelsHidden()
                        Text("\(dailyUrinations)×")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(Pulse.textPrimary)
                            .frame(width: 36)
                    }

                    Divider().opacity(0.2)

                    HStack {
                        Text("Avg. daily bowel movements")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Pulse.textPrimary)
                        Spacer()
                        Stepper("\(dailyBowels)", value: $dailyBowels, in: 0...10)
                            .labelsHidden()
                        Text("\(dailyBowels)×")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(Pulse.textPrimary)
                            .frame(width: 36)
                    }
                }
                .pulseSurface(radius: 14, padding: 14)
                .padding(.horizontal, 20)

                skipOrContinue { step = 10 }

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: ─── Step 11: Exercise History ───

    private static let surgeryOptions: [(id: String, name: String, icon: String)] = [
        ("knee_surgery", "Knee surgery / ACL", "figure.walk"),
        ("acl_reconstruction", "ACL reconstruction", "figure.run"),
        ("shoulder_surgery", "Shoulder / rotator cuff", "figure.strengthtraining.traditional"),
        ("spinal_surgery", "Spinal / back surgery", "figure.stand"),
        ("hip_replacement", "Hip replacement", "figure.walk"),
        ("hernia_repair", "Hernia repair", "cross.circle.fill"),
        ("cardiac_surgery", "Cardiac surgery", "heart.fill"),
    ]

    private static let mobilityOptions: [(id: String, name: String, icon: String)] = [
        ("limited_overhead", "Limited overhead reach", "arrow.up"),
        ("limited_squat_depth", "Can't squat deep", "arrow.down"),
        ("chronic_back_pain", "Chronic back pain", "figure.stand"),
        ("limited_grip", "Weak / limited grip", "hand.raised.fill"),
        ("balance_issues", "Balance problems", "figure.walk"),
        ("joint_hypermobility", "Joint hypermobility", "figure.flexibility"),
    ]

    private var exerciseHistoryStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                journeyHero(
                    icon: "figure.strengthtraining.traditional",
                    color: Pulse.energy,
                    title: "Past surgeries & mobility",
                    subtitle: "We'll adapt exercise selections and flag movements that need modification."
                )

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Past surgeries")
                    multiSelectGrid(
                        items: Self.surgeryOptions,
                        selected: $pastSurgeries,
                        color: Pulse.energy
                    )
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Mobility limitations")
                    multiSelectGrid(
                        items: Self.mobilityOptions,
                        selected: $mobilityLimits,
                        color: Pulse.energy
                    )
                }
                .padding(.horizontal, 20)

                skipOrContinue {
                    saveAllToProfile()  // Persist before step 11 so previewReport reads fresh data
                    step = 11
                }
                    .padding(.top, 8)

                Spacer(minLength: 80)
            }
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: ─── Step 12: Goals & Summary ───

    private static let goalOptions: [(id: String, name: String, icon: String)] = [
        ("lose_weight", "Lose weight", "scalemass.fill"),
        ("build_muscle", "Build muscle", "figure.strengthtraining.traditional"),
        ("improve_endurance", "Improve endurance", "figure.run"),
        ("manage_pain", "Manage chronic pain", "heart.fill"),
        ("more_energy", "Have more energy", "bolt.fill"),
        ("better_sleep", "Sleep better", "moon.stars.fill"),
        ("mental_clarity", "Mental clarity & focus", "brain.head.profile"),
        ("reduce_stress", "Reduce stress", "leaf.fill"),
        ("gut_health", "Improve gut health", "stomach"),
        ("longevity", "Longevity & healthy aging", "clock.fill"),
    ]

    private var goalsAndSummaryStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                journeyHero(
                    icon: "flag.checkered",
                    color: Pulse.positive,
                    title: "What matters most to you?",
                    subtitle: "Select your top priorities. These focus Paya's recommendations on what you care about."
                )

                multiSelectGrid(
                    items: Self.goalOptions,
                    selected: $healthGoals,
                    color: Pulse.positive
                )
                .padding(.horizontal, 20)

                // Summary preview card
                let report = previewReport
                if !report.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(Pulse.ai)
                            Text("What Paya found")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(Pulse.textPrimary)
                            Spacer()
                            Text("\(report.totalCount) insights")
                                .font(.caption.weight(.bold))
                                .foregroundColor(Pulse.ai)
                        }

                        summaryRow(count: report.nutritionWarnings.count, label: "Nutrition", icon: "fork.knife", color: Pulse.nutrition)
                        summaryRow(count: report.supplementWarnings.count, label: "Supplement", icon: "pills.fill", color: Color(hex: "FFB547"))
                        summaryRow(count: report.exerciseWarnings.count, label: "Exercise", icon: "figure.run", color: Pulse.energy)
                        summaryRow(count: report.sleepGuidance.count, label: "Sleep", icon: "moon.fill", color: Pulse.recovery)
                        summaryRow(count: report.mentalHealthNotes.count, label: "Mental health", icon: "brain.head.profile", color: Pulse.ai)
                        summaryRow(count: report.digestiveNotes.count, label: "Digestive", icon: "stomach", color: Color(hex: "059669"))

                        Button {
                            saveAllToProfile()
                            showContraindicationPreview = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                Text("See full report")
                            }
                            .font(.caption.weight(.bold))
                            .foregroundColor(Pulse.ai)
                        }
                        .padding(.top, 4)
                    }
                    .pulseSurfaceGlow(color: Pulse.ai, radius: 16, padding: 16)
                    .padding(.horizontal, 20)
                }

                // Health Disclaimer
                infoCard(
                    icon: "heart.text.clipboard",
                    text: "Paya is not a medical device. These insights are based on published guidelines, not a diagnosis. Always consult your healthcare provider."
                )

                // Complete button
                Button {
                    completeJourney()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete Health Journey")
                    }
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 60)
            }
        }
    }

    @ViewBuilder
    private func summaryRow(count: Int, label: String, icon: String, color: Color) -> some View {
        if count > 0 {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                    .frame(width: 20)
                Text("\(count) \(label.lowercased()) \(count == 1 ? "insight" : "insights")")
                    .font(.caption)
                    .foregroundColor(Pulse.textSecondary)
                Spacer()
            }
        }
    }

    private var previewReport: HealthContraindicationEngine.ContraindicationReport {
        // Save current @State values into the profile so the engine can read them.
        // NOTE: we do NOT call profile setters here — that would trigger @Observable
        // re-renders and create an infinite loop. Instead, saveAllToProfile() is called
        // once when the user enters step 11 (see exerciseHistoryStep's continue action).
        HealthContraindicationEngine.generate(for: profile)
    }

    // MARK: - Merged helpers

    /// Combines preset-selected supplements + custom free-text entries
    private var mergedSupplements: [String] {
        Array(selectedSupplements) + supplements
    }

    // MARK: - Save & Complete

    /// Track custom user-added allergies and supplements so the most popular
    /// ones can be promoted to the preset list in future versions.
    private func trackCustomAdditions() {
        let presetAllergyIds = Set(Self.allergyOptions.map(\.id))
        let customAllergies = selectedAllergies.filter { !presetAllergyIds.contains($0) }
        if !customAllergies.isEmpty {
            var existing = UserDefaults.standard.dictionary(forKey: "paya_custom_allergy_counts") as? [String: Int] ?? [:]
            for allergy in customAllergies {
                existing[allergy, default: 0] += 1
            }
            UserDefaults.standard.set(existing, forKey: "paya_custom_allergy_counts")
        }

        if !supplements.isEmpty {
            var existing = UserDefaults.standard.dictionary(forKey: "paya_custom_supplement_counts") as? [String: Int] ?? [:]
            for supp in supplements {
                existing[supp.lowercased(), default: 0] += 1
            }
            UserDefaults.standard.set(existing, forKey: "paya_custom_supplement_counts")
        }
    }

    private func saveAllToProfile() {
        profile.bloodTypeRaw = bloodType
        profile.chronicConditionsRaw = Array(selectedConditions)
        profile.geneticDisordersRaw = Array(selectedGenetics)
        profile.allergiesRaw = Array(selectedAllergies)
        profile.medicationsRaw = medications
        profile.currentSupplementsRaw = mergedSupplements
        profile.occupationTypeRaw = occupation
        profile.smokingStatusRaw = smokingStatus
        profile.alcoholFrequencyRaw = alcoholFrequency
        profile.dailyScreenTimeHours = screenTime
        profile.sleepDisordersRaw = Array(sleepDisorders)
        profile.mentalHealthConditionsRaw = Array(mentalConditions)
        profile.digestiveIssuesRaw = Array(digestiveIssues)
        profile.averageDailyUrinations = dailyUrinations
        profile.averageDailyBowelMovements = dailyBowels
        profile.pastSurgeriesRaw = Array(pastSurgeries)
        profile.mobilityLimitationsRaw = Array(mobilityLimits)
        profile.healthGoalsRaw = Array(healthGoals)
        try? modelContext.save()
    }

    private func completeJourney() {
        saveAllToProfile()
        trackCustomAdditions()
        profile.healthJourneyCompleted = true
        profile.healthJourneyCompletedAt = Date()

        // Also sync the first chronic condition to the legacy single-condition field
        // so FlareDetectionEngine keeps working.
        if let firstCondition = selectedConditions.first,
           let legacy = ChronicCondition(rawValue: firstCondition) {
            profile.chronicCondition = legacy
            profile.hasInflammatoryCondition = true
        }

        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onComplete?()
        dismiss()
    }

    // MARK: - Shared Components

    @ViewBuilder
    private func journeyHero(icon: String, color: Color, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 72, height: 72)
                Circle()
                    .fill(color.opacity(0.06))
                    .frame(width: 96, height: 96)
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(color)
            }

            Text(title)
                .font(.title2.bold())
                .foregroundColor(Pulse.textPrimary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(Pulse.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 16)
        .padding(.horizontal, 24)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundColor(Pulse.textTertiary)
            .textCase(.uppercase)
            .tracking(0.8)
    }

    @ViewBuilder
    private func multiSelectGrid(
        items: [(id: String, name: String, icon: String)],
        selected: Binding<Set<String>>,
        color: Color
    ) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(items, id: \.id) { item in
                let isSelected = selected.wrappedValue.contains(item.id)
                Button {
                    withAnimation(.spring(response: 0.2)) {
                        if isSelected {
                            selected.wrappedValue.remove(item.id)
                        } else {
                            selected.wrappedValue.insert(item.id)
                        }
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : item.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isSelected ? color : Pulse.textTertiary)
                            .frame(width: 18)

                        Text(item.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isSelected ? Pulse.textPrimary : Pulse.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? color.opacity(0.12) : Pulse.surfaceFallback)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? color.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func singleSelectList(
        options: [(id: String, label: String, icon: String)],
        selected: Binding<String>,
        color: Color
    ) -> some View {
        VStack(spacing: 6) {
            ForEach(options, id: \.id) { option in
                let isSelected = selected.wrappedValue == option.id
                Button {
                    withAnimation(.spring(response: 0.2)) { selected.wrappedValue = option.id }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: option.icon)
                            .font(.system(size: 14))
                            .foregroundColor(isSelected ? color : Pulse.textTertiary)
                            .frame(width: 22)

                        Text(option.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(isSelected ? Pulse.textPrimary : Pulse.textSecondary)

                        Spacer()

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? color : Color.white.opacity(0.15))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? color.opacity(0.1) : Pulse.surfaceFallback)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? color.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func freeTextListEditor(
        items: Binding<[String]>,
        newItem: Binding<String>,
        placeholder: String,
        color: Color
    ) -> some View {
        VStack(spacing: 10) {
            // Input field
            HStack(spacing: 8) {
                TextField(placeholder, text: newItem)
                    .font(.subheadline)
                    .padding(12)
                    .background(Pulse.surfaceFallback)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button {
                    let trimmed = newItem.wrappedValue.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    items.wrappedValue.append(trimmed)
                    newItem.wrappedValue = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(color)
                }
                .disabled(newItem.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // Current items as chips
            if !items.wrappedValue.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(items.wrappedValue.enumerated()), id: \.offset) { idx, item in
                        HStack(spacing: 4) {
                            Text(item)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Pulse.textPrimary)

                            Button {
                                items.wrappedValue.remove(at: idx)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(Pulse.textTertiary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(color.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func infoCard(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(Pulse.textTertiary)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundColor(Pulse.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func continueButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Continue")
                .font(.headline.weight(.bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(accentGradient)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func skipOrContinue(_ action: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            continueButton(action)

            Button {
                action()
            } label: {
                Text("Skip this step")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Pulse.textTertiary)
            }
        }
    }
}

// MARK: - Contraindication Preview Sheet

struct ContraindicationPreviewSheet: View {

    let profile: PersonProfile
    @Environment(\.dismiss) private var dismiss

    private var report: HealthContraindicationEngine.ContraindicationReport {
        HealthContraindicationEngine.generate(for: profile)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Hero
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 36))
                            .foregroundColor(Pulse.ai)
                        Text("Your Health Insights")
                            .font(.title2.bold())
                            .foregroundColor(Pulse.textPrimary)
                        Text("Based on your health profile, here's what Paya will watch for.")
                            .font(.subheadline)
                            .foregroundColor(Pulse.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 24)

                    warningSection("Nutrition", icon: "fork.knife", color: Pulse.nutrition, warnings: report.nutritionWarnings)
                    warningSection("Supplements", icon: "pills.fill", color: Color(hex: "FFB547"), warnings: report.supplementWarnings)
                    warningSection("Exercise", icon: "figure.run", color: Pulse.energy, warnings: report.exerciseWarnings)
                    warningSection("Sleep", icon: "moon.fill", color: Pulse.recovery, warnings: report.sleepGuidance)
                    warningSection("Mental Health", icon: "brain.head.profile", color: Pulse.ai, warnings: report.mentalHealthNotes)
                    warningSection("Digestive", icon: "stomach", color: Color(hex: "059669"), warnings: report.digestiveNotes)

                    // Disclaimer
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "heart.text.clipboard")
                            .font(.subheadline)
                            .foregroundColor(Pulse.critical)
                        Text("These insights are based on published clinical guidelines and your self-reported conditions. They are not diagnoses. Always consult your healthcare provider before making medical decisions.")
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Pulse.critical.opacity(0.06))
                    )
                    .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
            }
            .background(Pulse.canvasFallback.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Pulse.ai)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func warningSection(_ title: String, icon: String, color: Color, warnings: [HealthContraindicationEngine.Warning]) -> some View {
        if !warnings.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.caption.weight(.bold))
                        .foregroundColor(color)
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Pulse.textPrimary)
                    Spacer()
                    Text("\(warnings.count)")
                        .font(.caption.weight(.black))
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.15))
                        .clipShape(Capsule())
                }

                ForEach(warnings) { warning in
                    warningCard(warning, color: color)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func warningCard(_ warning: HealthContraindicationEngine.Warning, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                severityBadge(warning.severity)
                Text(warning.title)
                    .font(.caption.weight(.bold))
                    .foregroundColor(Pulse.textPrimary)
            }

            Text(warning.detail)
                .font(.caption2)
                .foregroundColor(Pulse.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(warning.source)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Pulse.textTertiary)
                .italic()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Pulse.surfaceFallback)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(severityColor(warning.severity).opacity(0.2), lineWidth: 0.5)
                )
        )
    }

    @ViewBuilder
    private func severityBadge(_ severity: HealthContraindicationEngine.Warning.Severity) -> some View {
        Text(severity.rawValue.uppercased())
            .font(.system(size: 8, weight: .black))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(severityColor(severity))
            .clipShape(Capsule())
    }

    private func severityColor(_ severity: HealthContraindicationEngine.Warning.Severity) -> Color {
        switch severity {
        case .info: return Pulse.hydration
        case .caution: return Pulse.warning
        case .warning: return Color(hex: "FF6B3D")
        case .critical: return Pulse.critical
        }
    }
}
