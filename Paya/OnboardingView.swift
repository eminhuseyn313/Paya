import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Onboarding
// First-launch flow: profile → goal → program. Shown when no profiles exist
// AND no legacy data to migrate (i.e. a genuinely new user/device).

struct OnboardingView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    var onComplete: () -> Void

    private static let stepCount = 8

    @State private var step: Int = 0

    // Profile inputs
    @State private var name: String = ""
    @State private var age: Int = 30
    @State private var sexRaw: String = "male"
    @State private var heightCm: Double = 175
    @State private var weightKg: Double = 75
    @State private var hasRA: Bool = false
    @State private var chronicCondition: ChronicCondition = .rheumatoidArthritis

    // Goal
    @State private var goal: TrainingGoal = .stayFit
    @State private var daysPerWeek: Int = 3

    // Personalization — feeds the program assembler directly, so the very
    // first plan installed is already built for this person instead of a
    // generic template that gets replaced once they later visit Settings.
    @State private var experience: ExperienceLevel = .beginner
    @State private var equipment: EquipmentAccess = .fullGym
    @State private var injuries: Set<InjuryArea> = []

    // Lifestyle — feeds LifestylePlanEngine's AI-generated end-to-end plan.
    @State private var dietPreference: DietPreference = .omnivore
    @State private var sleepTargetHours: Double = 8
    @State private var stressLevel: Int = 2
    @State private var priorityMuscle: MusclePriority = .none

    var body: some View {
        VStack(spacing: 0) {

            HStack(spacing: 12) {
                if step > 0 {
                    Button {
                        withAnimation { step -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundColor(Color(hex: "2563EB"))
                            .frame(width: 36, height: 36)
                            .background(Color(hex: "2563EB").opacity(0.1))
                            .clipShape(Circle())
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.tertiarySystemBackground))
                        Capsule()
                            .fill(Color(hex: "2563EB"))
                            .frame(width: geo.size.width * CGFloat(step + 1) / CGFloat(Self.stepCount))
                            .animation(.spring(response: 0.35), value: step)
                    }
                }
                .frame(height: 6)

                Text("\(step + 1)/\(Self.stepCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.secondary)
                    .frame(width: 30)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)

            TabView(selection: $step) {
                profileStep.tag(0)
                goalStep.tag(1)
                experienceStep.tag(2)
                equipmentStep.tag(3)
                injuriesStep.tag(4)
                lifestyleStep.tag(5)
                notificationStep.tag(6)
                programStep.tag(7)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(response: 0.35), value: step)
        }
    }

    // MARK: - Step 1: Profile

    var profileStep: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "2563EB"))
                    Text("Welcome to Paya")
                        .font(.title.bold())
                    Text("Let's set you up in under a minute.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button {
                        prefillFromHealthKit()
                    } label: {
                        Label("Auto-fill from Apple Health", systemImage: "heart.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color(hex: "DC2626"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(hex: "DC2626").opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 30)

                VStack(spacing: 12) {
                    TextField("Your name", text: $name)
                        .font(.headline)
                        .payaCard(padding: 14)

                    HStack {
                        Text("Age")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Stepper("\(age)", value: $age, in: 12...90)
                            .labelsHidden()
                        Text("\(age)")
                            .font(.headline)
                            .frame(width: 40)
                    }
                    .payaCard(padding: 14)

                    HStack(spacing: 8) {
                        ForEach([("male", "Male"), ("female", "Female")], id: \.0) { value, label in
                            Button {
                                sexRaw = value
                            } label: {
                                Text(label)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(sexRaw == value ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(sexRaw == value
                                        ? Color(hex: "2563EB")
                                        : Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        VStack(spacing: 4) {
                            Text("Height")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                TextField("cm", value: $heightCm, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.center)
                                    .font(.headline)
                                Text("cm").foregroundColor(.secondary).font(.caption)
                            }
                        }
                        .payaCard(padding: 12)

                        VStack(spacing: 4) {
                            Text("Weight")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                TextField("kg", value: $weightKg, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.center)
                                    .font(.headline)
                                Text("kg").foregroundColor(.secondary).font(.caption)
                            }
                        }
                        .payaCard(padding: 12)
                    }

                    Toggle(isOn: $hasRA) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chronic condition affecting energy or joints")
                                .font(.subheadline.weight(.semibold))
                            Text("Enables flare-risk tracking and joint-safe load adjustments")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .payaCard(padding: 14)

                    if hasRA {
                        Picker("Condition", selection: $chronicCondition) {
                            ForEach(ChronicCondition.allCases) { condition in
                                Text(condition.displayName).tag(condition)
                            }
                        }
                        .payaCard(padding: 14)
                    }
                }
                .padding(.horizontal, 20)

                Button {
                    withAnimation { step = 1 }
                } label: {
                    Text("Continue")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(name.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.secondary.opacity(0.4)
                            : Color(hex: "2563EB"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 20)

                Spacer().frame(height: 30)
            }
        }
    }

    // MARK: - Step 2: Goal

    var goalStep: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("What's your goal?")
                        .font(.title2.bold())
                    Text("This shapes your program, nutrition, and how effort is measured.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                .padding(.horizontal, 20)

                ForEach(TrainingGoal.allCases, id: \.self) { g in
                    Button {
                        withAnimation(.spring(response: 0.25)) { goal = g }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(g.color.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: g.icon)
                                    .foregroundColor(g.color)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(g.displayName)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundColor(.primary)
                                Text(g.summary)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: goal == g ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(goal == g ? g.color : .secondary.opacity(0.4))
                        }
                        .payaCard(padding: 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(goal == g ? g.color : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                }

                if goal == .hypertrophy {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Any muscle you want to prioritize?")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        Picker("Focus muscle", selection: $priorityMuscle) {
                            ForEach(MusclePriority.allCases) { m in
                                Text(m.displayName).tag(m)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(goal.color)
                    }
                    .payaCard(padding: 14)
                    .padding(.horizontal, 20)
                }

                Button {
                    withAnimation { step = 2 }
                } label: {
                    Text("Continue")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(goal.color)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 30)
            }
        }
    }

    // MARK: - Step 3: Experience

    var experienceStep: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("How long have you trained?")
                        .font(.title2.bold())
                    Text("Sets the starting weights and how hard sessions push you — not the exercises themselves.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                .padding(.horizontal, 20)

                ForEach(ExperienceLevel.allCases) { level in
                    Button {
                        withAnimation(.spring(response: 0.25)) { experience = level }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.displayName.capitalized)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundColor(.primary)
                                Text(level == .beginner ? "0–1 year" : level == .intermediate ? "1–3 years" : "3+ years")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: experience == level ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(experience == level ? Color(hex: "2563EB") : .secondary.opacity(0.4))
                        }
                        .payaCard(padding: 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(experience == level ? Color(hex: "2563EB") : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                }

                Button {
                    withAnimation { step = 3 }
                } label: {
                    Text("Continue")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color(hex: "2563EB"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 30)
            }
        }
    }

    // MARK: - Step 4: Equipment

    var equipmentStep: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("What do you have access to?")
                        .font(.title2.bold())
                    Text("Every exercise in your plan is chosen to fit this — not swapped in after the fact.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                .padding(.horizontal, 20)

                ForEach(EquipmentAccess.allCases) { access in
                    Button {
                        withAnimation(.spring(response: 0.25)) { equipment = access }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(icon: access.icon, color: Color(hex: "059669"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(access.displayName)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundColor(.primary)
                                Text(access.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: equipment == access ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(equipment == access ? Color(hex: "059669") : .secondary.opacity(0.4))
                        }
                        .payaCard(padding: 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(equipment == access ? Color(hex: "059669") : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                }

                Button {
                    withAnimation { step = 4 }
                } label: {
                    Text("Continue")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color(hex: "059669"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 30)
            }
        }
    }

    // MARK: - Step 5: Injuries

    var injuriesStep: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("Anywhere to go easy on?")
                        .font(.title2.bold())
                    Text("Optional — flagged areas get a gentler alternative swapped in when one exists.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                .padding(.horizontal, 20)

                VStack(spacing: 10) {
                    ForEach(InjuryArea.allCases) { area in
                        Button {
                            withAnimation(.spring(response: 0.2)) {
                                if injuries.contains(area) { injuries.remove(area) } else { injuries.insert(area) }
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack {
                                Text(area.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: injuries.contains(area) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(injuries.contains(area) ? Color(hex: "DC2626") : .secondary.opacity(0.4))
                            }
                            .payaCard(padding: 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                Button {
                    withAnimation { step = 5 }
                } label: {
                    Text("Continue")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color(hex: "2563EB"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 30)
            }
        }
    }

    // MARK: - Step 6: Lifestyle

    var lifestyleStep: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("A little about your lifestyle")
                        .font(.title2.bold())
                    Text("Feeds your AI-generated nutrition, supplement, and recovery plan.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Diet preference")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    ForEach(DietPreference.allCases) { pref in
                        Button {
                            withAnimation(.spring(response: 0.2)) { dietPreference = pref }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pref.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.primary)
                                    Text(pref.subtitle)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: dietPreference == pref ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(dietPreference == pref ? Color(hex: "059669") : .secondary.opacity(0.4))
                            }
                            .payaCard(padding: 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Sleep target")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(sleepTargetHours, specifier: "%.1f")h")
                            .font(.subheadline.weight(.bold))
                    }
                    Slider(value: $sleepTargetHours, in: 5...10, step: 0.5)
                        .tint(Color(hex: "2563EB"))
                }
                .payaCard(padding: 14)
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Typical stress level")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        ForEach(1...5, id: \.self) { level in
                            Button {
                                withAnimation(.spring(response: 0.2)) { stressLevel = level }
                            } label: {
                                Text("\(level)")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundColor(stressLevel == level ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(stressLevel == level ? Color(hex: "B45309") : Color(.tertiarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    HStack {
                        Text("Low").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                        Spacer()
                        Text("High").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                    }
                }
                .payaCard(padding: 14)
                .padding(.horizontal, 20)

                Button {
                    withAnimation { step = 6 }
                } label: {
                    Text("Continue")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color(hex: "2563EB"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 30)
            }
        }
    }

    // MARK: - Step 7: Notifications

    @State private var notifTraining: Bool = true
    @State private var notifMeal: Bool = true
    @State private var notifHydration: Bool = true
    @State private var notifRecovery: Bool = true
    @State private var notifMilestone: Bool = true
    @State private var notifWeeklyDigest: Bool = true

    var notificationStep: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: "8B5CF6"))
                    Text("Stay on track")
                        .font(.title2.bold())
                    Text("Choose which reminders help you — you can change these anytime in Settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                .padding(.horizontal, 20)

                VStack(spacing: 10) {
                    notifToggle(icon: "dumbbell.fill", color: "2563EB", title: "Training reminders", subtitle: "Nudge before your scheduled sessions", isOn: $notifTraining)
                    notifToggle(icon: "fork.knife", color: "059669", title: "Meal reminders", subtitle: "Hit your protein & calorie targets", isOn: $notifMeal)
                    notifToggle(icon: "drop.fill", color: "0891B2", title: "Hydration reminders", subtitle: "Stay hydrated throughout the day", isOn: $notifHydration)
                    notifToggle(icon: "heart.fill", color: "DC2626", title: "Recovery insights", subtitle: "Readiness scores & rest-day guidance", isOn: $notifRecovery)
                    notifToggle(icon: "trophy.fill", color: "F59E0B", title: "Milestone celebrations", subtitle: "PRs, streaks, and achievements", isOn: $notifMilestone)
                    notifToggle(icon: "chart.bar.fill", color: "8B5CF6", title: "Weekly digest", subtitle: "Summary of your week every Sunday", isOn: $notifWeeklyDigest)
                }
                .padding(.horizontal, 20)

                Button {
                    applyNotificationPrefs()
                    withAnimation { step = 7 }
                } label: {
                    Text("Enable notifications")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color(hex: "8B5CF6"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)

                Button {
                    withAnimation { step = 7 }
                } label: {
                    Text("Skip for now")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)

                Spacer().frame(height: 30)
            }
        }
    }

    private func notifToggle(icon: String, color: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: color).opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundColor(Color(hex: color))
                    .font(.system(size: 16, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color(hex: color))
        }
        .payaCard(padding: 12)
    }

    private func applyNotificationPrefs() {
        appState.profile.reminderEnabled = true
        appState.profile.notificationCategoryEnabled[NotificationCategory.training.rawValue] = notifTraining
        appState.profile.notificationCategoryEnabled[NotificationCategory.meal.rawValue] = notifMeal
        appState.profile.notificationCategoryEnabled[NotificationCategory.hydration.rawValue] = notifHydration
        appState.profile.notificationCategoryEnabled[NotificationCategory.recovery.rawValue] = notifRecovery
        appState.profile.notificationCategoryEnabled[NotificationCategory.milestone.rawValue] = notifMilestone
        appState.profile.notificationCategoryEnabled[NotificationCategory.weeklyDigest.rawValue] = notifWeeklyDigest

        // Request system notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    // MARK: - Step 8: Program

    var scienceRecommendation: TrainingScienceEngine.Recommendation? {
        TrainingScienceEngine.recommend(
            goal: goal,
            experience: experience,
            equipment: equipment,
            injuries: injuries,
            daysPerWeek: daysPerWeek,
            priorityMuscle: priorityMuscle,
            sexRaw: sexRaw
        )
    }

    var programStep: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("Your program")
                        .font(.title2.bold())
                    Text("Generated for \(goal.displayName.lowercased()) from everything you just answered — not a fixed template.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Days per week you can train")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Picker("Days per week", selection: $daysPerWeek) {
                        ForEach(Array(TrainingScienceEngine.allowedDaysRange), id: \.self) { n in
                            Text("\(n)×").tag(n)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 20)

                if let rec = scienceRecommendation {
                    RecommendedProgramCard(recommendation: rec, profile: nil, onInstall: { finish(installing: rec.template) })
                        .padding(.horizontal, 20)
                }

                Button {
                    finish(installing: nil)
                } label: {
                    Text("Skip — I'll build my own program")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 6)

                // MARK: Health Disclaimer (Apple Guideline 5.3.3)
                VStack(spacing: 8) {
                    Divider().padding(.horizontal, 20)

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "heart.text.clipboard")
                            .font(.title3)
                            .foregroundColor(Color(hex: "DC2626"))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Health Disclaimer")
                                .font(.caption.weight(.bold))
                            Text("Paya is a fitness tracking tool, not a medical device. It does not diagnose, treat, cure, or prevent any disease. Always consult a qualified healthcare professional before starting any exercise or nutrition program.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 12)

                Spacer().frame(height: 30)
            }
        }
    }

    // MARK: - Apple Health Pre-fill

    private func prefillFromHealthKit() {
        Task {
            let manager = HealthKitManager.shared
            if !manager.isAuthorized {
                await manager.requestAuthorization()
            }
            if let weightData = await manager.fetchLatestBodyWeight() {
                weightKg = round(weightData.weight * 10) / 10
            }
            if let h = await manager.fetchHeight() {
                heightCm = round(h)
            }
            if let dob = await manager.fetchDateOfBirth() {
                let years = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 30
                age = max(12, min(90, years))
            }
            if let sex = await manager.fetchBiologicalSex() {
                sexRaw = sex
            }
        }
    }

    // MARK: - Finish

    private func finish(installing template: ProgramTemplate?) {
        // 1. Create the profile
        let profile = ProfileStore.add(
            name: name.trimmingCharacters(in: .whitespaces),
            context: modelContext
        )
        profile.age = age
        profile.sexRaw = sexRaw
        profile.heightCm = heightCm
        profile.currentWeightKg = weightKg
        profile.bodyWeightGoalKg = weightKg
        profile.goal = goal
        profile.hasInflammatoryCondition = hasRA
        profile.chronicCondition = chronicCondition
        profile.preferredTrainingDaysPerWeek = daysPerWeek
        profile.experienceLevel = experience
        profile.equipmentAccess = equipment
        profile.injuryFlags = injuries
        profile.dietPreference = dietPreference
        profile.sleepTargetHours = sleepTargetHours
        profile.stressLevel = stressLevel
        profile.priorityMuscle = priorityMuscle

        // 2. Compute nutrition targets from goal
        let targets = GoalEngine.targets(
            goal: goal,
            bodyWeightKg: weightKg,
            age: age,
            heightCm: heightCm,
            sexRaw: sexRaw
        )
        profile.proteinTargetG = targets.proteinG
        profile.trainingDayCalories = targets.trainingDayCalories
        profile.restDayCalories = targets.restDayCalories
        try? modelContext.save()

        // 3. Activate + sync
        ProfileStore.setCurrent(profile)
        appState.syncFromPersonProfile(profile)

        // 4. Install chosen program (scoped to the new profile)
        if let template = template {
            ProgramInstaller.install(template, context: modelContext)
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onComplete()

        // 5. Kick off the AI lifestyle plan in the background — end-to-end
        // synthesis of everything just answered, ready by the time the
        // user checks the Nutrition tab instead of a cold start there.
        let apiKey = appState.anthropicAPIKey
        Task {
            _ = await LifestylePlanEngine.generate(profile: profile, context: modelContext, apiKey: apiKey)
            try? modelContext.save()
        }
    }
}

