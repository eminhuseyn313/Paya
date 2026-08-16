import SwiftUI
import SwiftData

// MARK: - User Profile

struct UserProfile: Codable {
    var name: String = "Emin"
    /// Birth year — age is computed dynamically so it never goes stale.
    /// Migrated from legacy `age` field on first decode.
    var birthYear: Int = Calendar.current.component(.year, from: Date()) - 30
    var sexRaw: String = "male"
    var heightCm: Double = 178.0
    var bodyWeightGoalKg: Double = 80.0
    var currentWeightKg: Double = 85.0
    var proteinTargetG: Double = 170.0
    var trainingDayCalories: Double = 2200.0
    var restDayCalories: Double = 1900.0
    var trainingDays: [Int] = [2, 5, 7]
    var flareEngineEnabled: Bool = true

    // Custom coding keys to handle migration from `age` to `birthYear`
    private enum CodingKeys: String, CodingKey {
        case name, birthYear, sexRaw, heightCm, bodyWeightGoalKg, currentWeightKg
        case proteinTargetG, trainingDayCalories, restDayCalories, trainingDays
        case flareEngineEnabled, reminderEnabled, reminderTime, preFlareAlertsEnabled
        case notificationCategoryEnabled, notificationsQuietHoursEnabled
        case quietHoursStart, quietHoursEnd, favoriteAzeFoodIds, prefersLbs, goalRaw
        // Legacy key — read-only, used to migrate old JSON
        case legacyAge = "age"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? "Emin"
        sexRaw = (try? c.decode(String.self, forKey: .sexRaw)) ?? "male"
        heightCm = (try? c.decode(Double.self, forKey: .heightCm)) ?? 178
        bodyWeightGoalKg = (try? c.decode(Double.self, forKey: .bodyWeightGoalKg)) ?? 80
        currentWeightKg = (try? c.decode(Double.self, forKey: .currentWeightKg)) ?? 85
        proteinTargetG = (try? c.decode(Double.self, forKey: .proteinTargetG)) ?? 170
        trainingDayCalories = (try? c.decode(Double.self, forKey: .trainingDayCalories)) ?? 2200
        restDayCalories = (try? c.decode(Double.self, forKey: .restDayCalories)) ?? 1900
        trainingDays = (try? c.decode([Int].self, forKey: .trainingDays)) ?? [2, 5, 7]
        flareEngineEnabled = (try? c.decode(Bool.self, forKey: .flareEngineEnabled)) ?? true
        reminderEnabled = (try? c.decode(Bool.self, forKey: .reminderEnabled)) ?? true
        reminderTime = (try? c.decode(Date.self, forKey: .reminderTime)) ?? (Calendar.current.date(from: DateComponents(hour: 8)) ?? Date())
        preFlareAlertsEnabled = (try? c.decode(Bool.self, forKey: .preFlareAlertsEnabled)) ?? false
        notificationCategoryEnabled = (try? c.decode([String: Bool].self, forKey: .notificationCategoryEnabled)) ?? UserProfile().notificationCategoryEnabled
        notificationsQuietHoursEnabled = (try? c.decode(Bool.self, forKey: .notificationsQuietHoursEnabled)) ?? false
        quietHoursStart = (try? c.decode(Date.self, forKey: .quietHoursStart)) ?? (Calendar.current.date(from: DateComponents(hour: 22)) ?? Date())
        quietHoursEnd = (try? c.decode(Date.self, forKey: .quietHoursEnd)) ?? (Calendar.current.date(from: DateComponents(hour: 7)) ?? Date())
        favoriteAzeFoodIds = (try? c.decode([String].self, forKey: .favoriteAzeFoodIds)) ?? []
        prefersLbs = (try? c.decode(Bool.self, forKey: .prefersLbs)) ?? false
        goalRaw = (try? c.decode(String.self, forKey: .goalRaw)) ?? TrainingGoal.hypertrophy.rawValue

        // Migration: prefer `birthYear`; fall back to legacy `age` → birthYear
        let currentYear = Calendar.current.component(.year, from: Date())
        if let by = try? c.decode(Int.self, forKey: .birthYear) {
            birthYear = by
        } else if let legacyAge = try? c.decode(Int.self, forKey: .legacyAge) {
            birthYear = currentYear - legacyAge
        } else {
            birthYear = currentYear - 30
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(birthYear, forKey: .birthYear)
        try c.encode(sexRaw, forKey: .sexRaw)
        try c.encode(heightCm, forKey: .heightCm)
        try c.encode(bodyWeightGoalKg, forKey: .bodyWeightGoalKg)
        try c.encode(currentWeightKg, forKey: .currentWeightKg)
        try c.encode(proteinTargetG, forKey: .proteinTargetG)
        try c.encode(trainingDayCalories, forKey: .trainingDayCalories)
        try c.encode(restDayCalories, forKey: .restDayCalories)
        try c.encode(trainingDays, forKey: .trainingDays)
        try c.encode(flareEngineEnabled, forKey: .flareEngineEnabled)
        try c.encode(reminderEnabled, forKey: .reminderEnabled)
        try c.encode(reminderTime, forKey: .reminderTime)
        try c.encode(preFlareAlertsEnabled, forKey: .preFlareAlertsEnabled)
        try c.encode(notificationCategoryEnabled, forKey: .notificationCategoryEnabled)
        try c.encode(notificationsQuietHoursEnabled, forKey: .notificationsQuietHoursEnabled)
        try c.encode(quietHoursStart, forKey: .quietHoursStart)
        try c.encode(quietHoursEnd, forKey: .quietHoursEnd)
        try c.encode(favoriteAzeFoodIds, forKey: .favoriteAzeFoodIds)
        try c.encode(prefersLbs, forKey: .prefersLbs)
        try c.encode(goalRaw, forKey: .goalRaw)
        // Note: we intentionally do NOT encode `legacyAge` — once migrated,
        // only `birthYear` is persisted.
    }

    // Notifications
    var reminderEnabled: Bool = true
    var reminderTime: Date = Calendar.current.date(
        from: DateComponents(hour: 8, minute: 0)
    ) ?? Date()
    var preFlareAlertsEnabled: Bool = false
    var notificationCategoryEnabled: [String: Bool] = [
        NotificationCategory.training.rawValue: true,
        NotificationCategory.milestone.rawValue: true,
        NotificationCategory.flareRisk.rawValue: true,
        NotificationCategory.meal.rawValue: true,
        NotificationCategory.supplement.rawValue: true,
        NotificationCategory.hydration.rawValue: true,
        NotificationCategory.recovery.rawValue: true,
        NotificationCategory.weighIn.rawValue: true,
        NotificationCategory.restTimer.rawValue: false,
        NotificationCategory.medication.rawValue: true,
        NotificationCategory.eyeCare.rawValue: true,
        NotificationCategory.circadian.rawValue: true,
        NotificationCategory.postWorkoutNutrition.rawValue: true,
        NotificationCategory.weeklyDigest.rawValue: true,
    ]
    var notificationsQuietHoursEnabled: Bool = false
    var quietHoursStart: Date = Calendar.current.date(
        from: DateComponents(hour: 22, minute: 0)
    ) ?? Date()
    var quietHoursEnd: Date = Calendar.current.date(
        from: DateComponents(hour: 7, minute: 0)
    ) ?? Date()
    var favoriteAzeFoodIds: [String] = []
    var prefersLbs: Bool = false

    /// Age computed from `birthYear` so it stays accurate over time.
    var age: Int {
        get { Calendar.current.component(.year, from: Date()) - birthYear }
        set { birthYear = Calendar.current.component(.year, from: Date()) - newValue }
    }

    // Training goal
        var goalRaw: String = TrainingGoal.hypertrophy.rawValue

        var goal: TrainingGoal {
            get { TrainingGoal(rawValue: goalRaw) ?? .hypertrophy }
            set { goalRaw = newValue.rawValue }
        }
}

// MARK: - AppState

@MainActor
@Observable
class AppState {

    // MARK: - Persisted via UserDefaults

    var isFlareDay: Bool = false {
        didSet { UserDefaults.standard.set(isFlareDay, forKey: "isFlareDay") }
    }

    var morningCheckInEnabled: Bool = true {
        didSet { UserDefaults.standard.set(morningCheckInEnabled, forKey: "morningCheckInEnabled") }
    }

    var profile: UserProfile = UserProfile() {
        didSet {
            if let encoded = try? JSONEncoder().encode(profile) {
                UserDefaults.standard.set(encoded, forKey: "userProfile")
            }
        }
    }

    var anthropicAPIKey: String = "" {
        didSet { KeychainHelper.save(key: "anthropic_api_key", value: anthropicAPIKey) }
    }

    // Google AI Studio key — Gemini's free tier is generous enough to use
    // for one-off "what's the macro breakdown of this food" requests
    // without needing the paid Claude path.
    var geminiAPIKey: String = "" {
        didSet { KeychainHelper.save(key: "gemini_api_key", value: geminiAPIKey) }
    }

    /// User has explicitly consented to sending health/fitness data to
    /// external AI services (Claude API, Gemini API). Required by GDPR
    /// Art. 9 (special-category health data) and App Store Guideline 5.1.1(i).
    /// Apple Intelligence (on-device) does NOT require this — data never
    /// leaves the device.
    var hasConsentedToExternalAI: Bool = false {
        didSet { UserDefaults.standard.set(hasConsentedToExternalAI, forKey: "hasConsentedToExternalAI") }
    }

    var flareEngineEnabled: Bool = true
    
    // MARK: - Profile Sync (Phase 2)
        // Mirrors the active PersonProfile into the legacy profile struct so
        // existing views keep working unchanged.

        var currentProfileId: UUID? = nil

        func syncFromPersonProfile(_ p: PersonProfile) {
            currentProfileId = p.id
            profile.name = p.name
            profile.age = p.currentAge
            profile.sexRaw = p.sexRaw
            profile.heightCm = p.heightCm
            profile.currentWeightKg = p.currentWeightKg
            profile.bodyWeightGoalKg = p.bodyWeightGoalKg
            profile.goalRaw = p.goalRaw
            profile.proteinTargetG = p.proteinTargetG
            profile.trainingDayCalories = p.trainingDayCalories
            profile.restDayCalories = p.restDayCalories
            flareEngineEnabled = p.hasInflammatoryCondition
            LiveHRManager.shared.setMaxHRFromAge(p.currentAge)
            dataRefreshTrigger = UUID()        }

    // MARK: - Today's Health Snapshot (lightweight, for dashboard)

    var todayPainLevel: Int = 0
    var todaySleepHours: Double = 7.0
    var todayEnergyLevel: Int = 2   // 1=low, 2=ok, 3=high

    // MARK: - Data refresh trigger
    // Bumped whenever the user switches tabs so dashboards reload fresh data

    var dataRefreshTrigger: UUID = UUID()

    // MARK: - Active Session State (visible across all tabs)

    var activeSessionType: SessionType? = ProgramData.todaySessionType
    var sessionStartTime: Date? = nil
    var isSessionActive: Bool = false
    var isSessionPaused: Bool = false

    var activeSessionLabel: String = ""        // "Session A"
    var activeSessionColor: Color = .blue
    var completedSetsInSession: Int = 0
    var totalSetsInSession: Int = 0

    // MARK: - Init

    init() {
        // Restore flare day
        isFlareDay = UserDefaults.standard.bool(forKey: "isFlareDay")

        // Restore morning check-in preference (defaults to true on first launch)
        if UserDefaults.standard.object(forKey: "morningCheckInEnabled") != nil {
            morningCheckInEnabled = UserDefaults.standard.bool(forKey: "morningCheckInEnabled")
        }

        // Restore profile
        if let data = UserDefaults.standard.data(forKey: "userProfile"),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = decoded
        }

        // Restore AI consent
        hasConsentedToExternalAI = UserDefaults.standard.bool(forKey: "hasConsentedToExternalAI")

        // Restore API key from Keychain
        anthropicAPIKey = KeychainHelper.load(key: "anthropic_api_key") ?? ""
        geminiAPIKey = KeychainHelper.load(key: "gemini_api_key") ?? ""
    }

    // MARK: - Computed Properties

    var todaySessionType: SessionType? {
        ProgramData.todaySessionType
    }

    var isTrainingDay: Bool {
        todaySessionType != nil
    }

    var todayCalorieTarget: Double {
        isTrainingDay ? profile.trainingDayCalories : profile.restDayCalories
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Good night"
        }
    }

    var flareWarningText: String {
        "RA flare day active — weights reduced by 25%"
    }

    // MARK: - Session Helpers

    func startSession() {
        isSessionActive = true
        sessionStartTime = Date()
    }

    func endSession() {
        isSessionActive = false
        isSessionPaused = false
        sessionStartTime = nil
        activeSessionLabel = ""
        completedSetsInSession = 0
        totalSetsInSession = 0
    }

    func updateSessionProgress(
        label: String,
        color: Color,
        completed: Int,
        total: Int
    ) {
        activeSessionLabel = label
        activeSessionColor = color
        completedSetsInSession = completed
        totalSetsInSession = total
    }

    var sessionDurationMinutes: Int {
        guard let start = sessionStartTime else { return 0 }
        return Int(Date().timeIntervalSince(start) / 60)
    }

    var sessionDurationDisplay: String {
        let mins = sessionDurationMinutes
        if mins < 60 { return "\(mins)m" }
        return "\(mins / 60)h \(mins % 60)m"
    }

    var sessionProgressPercent: Double {
        guard totalSetsInSession > 0 else { return 0 }
        return Double(completedSetsInSession) / Double(totalSetsInSession)
    }

    // MARK: - Calorie Target Label

    func calorieTargetLabel() -> String {
        isTrainingDay
            ? "Training Day — \(Int(profile.trainingDayCalories)) kcal"
            : "Rest Day — \(Int(profile.restDayCalories)) kcal"
    }

    // MARK: - Energy Label

    func energyLabel(_ level: Int) -> String {
        switch level {
        case 1: return "Low"
        case 2: return "OK"
        case 3: return "High"
        default: return "OK"
        }
    }

    func energyColor(_ level: Int) -> Color {
        switch level {
        case 1: return .red
        case 2: return Color(hex: "B45309")
        case 3: return Color(hex: "059669")
        default: return .gray
        }
    }
}

// MARK: - Keychain Helper

enum KeychainHelper {

    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrAccount:     key,
            kSecValueData:       data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrAccount:  key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
