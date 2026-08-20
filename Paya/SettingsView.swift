import SwiftUI
import SwiftData
import StoreKit
import UniformTypeIdentifiers

struct SettingsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var showAPIKeyField = false
    @State private var apiKeyInput = ""
    @State private var showGeminiAPIKeyField = false
    @State private var geminiAPIKeyInput = ""
    @State private var showExportConfirm = false
    @State private var exportedCSV = ""
    @State private var showCSVSheet = false
    @State private var showDoctorReport = false
    @State private var showFocusModeSettings = false
    @State private var showSaved = false
    @State private var showConnectWearable = false
        @State private var showHeartRateMonitor = false
        @State private var showGoalPicker = false
        @State private var showTrainingProfile = false
        @State private var backupFile: BackupJSONFile? = nil
        @State private var showFileExporter = false
        @State private var showFileImporter = false
        @State private var restoreResultMessage: String? = nil
        @State private var showRestoreResult = false
    @State private var showPaywall = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false

    var body: some View {
        NavigationStack {
            List {

                // MARK: - Training Goal
                                Section {
                                    Button {
                                        showGoalPicker = true
                                    } label: {
                                        HStack {
                                            SettingsIcon(
                                                icon: appState.profile.goal.icon,
                                                color: appState.profile.goal.color
                                            )
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Training Goal")
                                                    .foregroundColor(.primary)
                                                Text(appState.profile.goal.displayName)
                                                    .font(.caption)
                                                    .foregroundColor(appState.profile.goal.color)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                } header: {
                                    SectionHeader(title: "Goal", icon: "target")
                                }
                Section {
                    ProfileNameRow()
                    ProfileWeightRow()
                    ProfileProteinRow()
                    ProfileCalorieRows()
                    HStack {
                        SettingsIcon(icon: "scalemass", color: Color(hex: "0891B2"))
                        Text("Weight Unit")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { appState.profile.prefersLbs },
                            set: { appState.profile.prefersLbs = $0 }
                        )) {
                            Text("kg").tag(false)
                            Text("lbs").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                } header: {
                    SectionHeader(title: "Profile", icon: "person.fill")
                }

                // MARK: - Training
                Section {
                    TrainingDaysRow()
                    Button {
                        showTrainingProfile = true
                    } label: {
                        HStack {
                            SettingsIcon(icon: "figure.strengthtraining.traditional", color: Color(hex: "8B5CF6"))
                            Text("Training Profile")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .sheet(isPresented: $showTrainingProfile) {
                        TrainingProfileView()
                    }
                } header: {
                    SectionHeader(title: "Training", icon: "dumbbell.fill")
                }

                // MARK: - Wearables
                                Section {
                                    Button {
                                        showConnectWearable = true
                                    } label: {
                                        HStack {
                                            SettingsIcon(icon: "applewatch.watchface", color: Color(hex: "2563EB"))
                                            Text("Connect Wearable")
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Button {
                                        showHeartRateMonitor = true
                                    } label: {
                                        HStack {
                                            SettingsIcon(icon: "heart.fill", color: Color(hex: "DC2626"))
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Heart Rate Monitor")
                                                    .foregroundColor(.primary)
                                                if case .connected = BLEHeartRateManager.shared.connectionState,
                                                   let name = BLEHeartRateManager.shared.connectedDeviceName {
                                                    Text(name)
                                                        .font(.caption)
                                                        .foregroundColor(Color(hex: "059669"))
                                                }
                                            }
                                            Spacer()
                                            if let bpm = LiveHRManager.shared.currentBPM {
                                                Text("\(bpm) BPM")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundColor(.red)
                                            }
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                } header: {
                                    SectionHeader(title: "Wearables", icon: "applewatch")
                                } footer: {
                                    Text("Wearable data uses Apple Health. Heart Rate Monitor pairs directly via Bluetooth.")
                                        .font(.caption)
                                }

                // MARK: - AI
                Section {
                    Toggle(isOn: Bindable(appState).hasConsentedToExternalAI) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Allow External AI", systemImage: "arrow.up.right.square")
                            Text("When enabled, food descriptions and fitness data may be sent to Claude or Gemini APIs for analysis. Apple Intelligence (on-device) works without this.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(Color(hex: "059669"))
                } header: {
                    SectionHeader(title: "AI Data Sharing", icon: "hand.raised.fill")
                } footer: {
                    Text("Required by GDPR. Your data is never stored by these services beyond processing your request. You can revoke this at any time.")
                        .font(.caption)
                }

                Section {
                    APIKeyRow(
                        showAPIKeyField: $showAPIKeyField,
                        apiKeyInput: $apiKeyInput
                    )
                } header: {
                    SectionHeader(title: "AI — Claude API", icon: "sparkles")
                } footer: {
                    Text("Your API key is stored securely in the iOS Keychain. Get yours at console.anthropic.com")
                        .font(.caption)
                }

                Section {
                    APIKeyRow(
                        title: "Gemini API Key",
                        placeholder: "AIza...",
                        maskPrefix: "",
                        iconColor: Color(hex: "8B5CF6"),
                        currentValue: { appState.geminiAPIKey },
                        save: { appState.geminiAPIKey = $0 },
                        showAPIKeyField: $showGeminiAPIKeyField,
                        apiKeyInput: $geminiAPIKeyInput
                    )
                } header: {
                    SectionHeader(title: "AI — Gemini (free tier)", icon: "mic.and.signal.meter.fill")
                } footer: {
                    Text("Used for \"Describe a food\" in Nutrition. Free API keys are available at aistudio.google.com — no card required.")
                        .font(.caption)
                }

                // MARK: - Notifications
                                Section {
                                    NotificationRow()
                                    HStack {
                                        SettingsIcon(icon: "sun.horizon.fill", color: Color(hex: "F59E0B"))
                                        Text("Morning Check-in")
                                        Spacer()
                                        Toggle("", isOn: Binding(
                                            get: { appState.morningCheckInEnabled },
                                            set: { appState.morningCheckInEnabled = $0 }
                                        ))
                                        .labelsHidden()
                                    }
                                } header: {
                                    SectionHeader(title: "Reminders", icon: "bell.fill")
                                }

                // MARK: - Focus
                Section {
                    Button {
                        showFocusModeSettings = true
                    } label: {
                        HStack {
                            SettingsIcon(icon: "hand.raised.slash.fill", color: Color(hex: "DC2626"))
                            Text("Block Distractions")
                                .foregroundColor(.primary)
                        }
                    }
                } header: {
                    SectionHeader(title: "Focus", icon: "hand.raised.slash.fill")
                } footer: {
                    Text("Blocks apps you choose (Instagram, etc.) for the duration of an active training session.")
                        .font(.caption)
                }

                // MARK: - Cloud Sync
                Section {
                    CloudSyncSettingsRow()
                } header: {
                    SectionHeader(title: "Cloud Backup", icon: "icloud.fill")
                } footer: {
                    Text("Sync all your data to the cloud so you never lose it. Your data is encrypted and only accessible with your account.")
                }

                // MARK: - Data
                Section {
                    ProGate(featureName: "Doctor Report (PDF)") {
                        Button {
                            showDoctorReport = true
                        } label: {
                            HStack {
                                SettingsIcon(icon: "doc.text.fill", color: Color(hex: "DC2626"))
                                Text("Doctor Report (PDF)")
                                    .foregroundColor(.primary)
                            }
                        }
                    }

                    ProGate(featureName: "Export Data as CSV") {
                        Button {
                            exportedCSV = exportCSV(context: modelContext)
                            showCSVSheet = true
                        } label: {
                            HStack {
                                SettingsIcon(icon: "square.and.arrow.up", color: Color(hex: "059669"))
                                Text("Export Data as CSV")
                                    .foregroundColor(.primary)
                            }
                        }
                    }

                    Button {
                        if let data = DataBackupManager.export(context: modelContext) {
                            backupFile = BackupJSONFile(data: data)
                            showFileExporter = true
                        }
                    } label: {
                        HStack {
                            SettingsIcon(icon: "arrow.down.doc.fill", color: Color(hex: "8B5CF6"))
                            Text("Backup Data (restorable file)")
                                .foregroundColor(.primary)
                        }
                    }

                    Button {
                        showFileImporter = true
                    } label: {
                        HStack {
                            SettingsIcon(icon: "arrow.up.doc.fill", color: Color(hex: "8B5CF6"))
                            Text("Restore from Backup")
                                .foregroundColor(.primary)
                        }
                    }

                    Button(role: .destructive) {
                        showExportConfirm = true
                    } label: {
                        HStack {
                            SettingsIcon(icon: "trash", color: .red)
                            Text("Clear All Data")
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    SectionHeader(title: "Data", icon: "externaldrive.fill")
                } footer: {
                    Text("Backup exports training history, body weight, measurements, and nutrition logs to one file you can save anywhere (Files, iCloud Drive, email) and restore from on any device — CSV export above is read-only, this isn't. Progress photos aren't included; those rely on your device's own iCloud Backup.")
                }

                // MARK: - Paya Pro
                Section {
                    if PurchaseManager.shared.isPro {
                        HStack {
                            SettingsIcon(icon: "star.fill", color: Color(hex: "059669"))
                            Text("Paya Pro")
                            Spacer()
                            Text("Active")
                                .font(.caption.weight(.bold))
                                .foregroundColor(Color(hex: "059669"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: "059669").opacity(0.1))
                                .clipShape(Capsule())
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                SettingsIcon(icon: "star.fill", color: Color(hex: "8B5CF6"))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upgrade to Paya Pro")
                                        .foregroundColor(.primary)
                                    Text("AI coaching, advanced analytics, unlimited history")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(PurchaseManager.shared.product?.displayPrice ?? "$14.99")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundColor(Color(hex: "8B5CF6"))
                            }
                        }

                        Button {
                            Task { await PurchaseManager.shared.restore() }
                        } label: {
                            HStack {
                                SettingsIcon(icon: "arrow.clockwise", color: .secondary)
                                Text("Restore purchase")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                } header: {
                    SectionHeader(title: "Paya Pro", icon: "star.fill")
                }

                // MARK: - About
                Section {
                    HStack {
                        SettingsIcon(icon: "app.fill", color: Color(hex: "2563EB"))
                        Text("App Name")
                        Spacer()
                        Text("Paya")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        SettingsIcon(icon: "number", color: .secondary)
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Button {
                        showPrivacyPolicy = true
                    } label: {
                        HStack {
                            SettingsIcon(icon: "hand.raised.fill", color: Color(hex: "2563EB"))
                            Text("Privacy policy")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button {
                        showTermsOfService = true
                    } label: {
                        HStack {
                            SettingsIcon(icon: "doc.text.fill", color: .secondary)
                            Text("Terms of service")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    SectionHeader(title: "About", icon: "info.circle.fill")
                }

                // Health disclaimer — Apple Review Guideline 5.3.3
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.text.clipboard")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "DC2626"))
                            Text("Health disclaimer")
                                .font(.caption.weight(.semibold))
                        }
                        Text("Paya is a fitness tracking tool, not a medical device. The readiness scores, sleep analysis, recovery suggestions, and other insights provided are for informational and educational purposes only. They do not constitute medical advice, diagnosis, or treatment. Always consult a qualified healthcare professional before making changes to your exercise, nutrition, or health routine.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Clear All Data", isPresented: $showExportConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    clearAllData(context: modelContext)
                }
            } message: {
                Text("This will permanently delete all sessions, nutrition logs, health logs and weight entries. This cannot be undone.")
            }
            .sheet(isPresented: $showCSVSheet) {
                CSVExportSheet(csv: exportedCSV)
            }
            .sheet(isPresented: $showDoctorReport) {
                DoctorReportView()
            }
            .sheet(isPresented: $showFocusModeSettings) {
                FocusModeSettingsView()
            }
            .fileExporter(
                isPresented: $showFileExporter,
                document: backupFile,
                contentType: .json,
                defaultFilename: "Paya-Backup-\(Date().formatted(.iso8601.year().month().day()))"
            ) { _ in }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    guard let data = try? Data(contentsOf: url) else {
                        restoreResultMessage = "Couldn't read that file."
                        showRestoreResult = true
                        return
                    }
                    do {
                        let count = try DataBackupManager.importBackup(data: data, context: modelContext)
                        restoreResultMessage = "Restored \(count) entries."
                        appState.dataRefreshTrigger = UUID()
                    } catch {
                        restoreResultMessage = "That file doesn't look like a Paya backup — restore failed."
                    }
                    showRestoreResult = true
                case .failure:
                    restoreResultMessage = "Couldn't open that file."
                    showRestoreResult = true
                }
            }
            .alert("Restore", isPresented: $showRestoreResult) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreResultMessage ?? "")
            }
            .sheet(isPresented: $showConnectWearable) {
                            ConnectWearableView(biometrics: BiometricStore.shared)
                        }
                        .sheet(isPresented: $showHeartRateMonitor) {
                            HeartRateMonitorView()
                        }
                        .sheet(isPresented: $showGoalPicker) {
                                        GoalPickerView()
                                    }
                        .sheet(isPresented: $showPaywall) {
                            PaywallView()
                        }
                        .sheet(isPresented: $showPrivacyPolicy) {
                            PrivacyPolicyView()
                        }
                        .sheet(isPresented: $showTermsOfService) {
                            TermsOfServiceView()
                        }
                    }
        .onAppear {
            apiKeyInput = appState.anthropicAPIKey
        }
    }

    // MARK: - Export CSV

    func exportCSV(context: ModelContext) -> String {
        var lines: [String] = []
        let pid = ActiveProfile.id

        // Sessions
        lines.append("--- TRAINING SESSIONS ---")
        lines.append("Date,Session,Duration(min),FlareDay,Volume(kg)")
        let sessionDesc = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.isCompleted == true && $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        if let sessions = try? context.fetch(sessionDesc) {
            for s in sessions {
                let volume = s.exercises.reduce(0.0) { total, ex in
                    total + ex.sets.filter { $0.isCompleted }
                        .reduce(0.0) { $0 + ($1.weightKg * Double($1.reps)) }
                }
                let date = s.date.formatted(.dateTime.day().month().year())
                lines.append("\(date),\(s.sessionType),\(s.durationMinutes),\(s.isFlareDay),\(Int(volume))")
            }
        }

        // Nutrition
        lines.append("")
        lines.append("--- NUTRITION LOGS ---")
        lines.append("Date,Protein(g),Calories,Target Protein,Target Calories")
        let nutritionDesc = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        if let logs = try? context.fetch(nutritionDesc) {
            for log in logs {
                let date = log.date.formatted(.dateTime.day().month().year())
                lines.append("\(date),\(Int(log.totalProtein)),\(Int(log.totalCalories)),\(Int(log.proteinTarget)),\(Int(log.calorieTarget))")
            }
        }

        // Weight
        lines.append("")
        lines.append("--- BODY WEIGHT ---")
        lines.append("Date,Weight(kg)")
        let weightDesc = FetchDescriptor<BodyWeightLog>(
            predicate: #Predicate<BodyWeightLog> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        if let logs = try? context.fetch(weightDesc) {
            for log in logs {
                let date = log.date.formatted(.dateTime.day().month().year())
                lines.append("\(date),\(log.weightKg)")
            }
        }

        // Health
        lines.append("")
        lines.append("--- HEALTH LOGS ---")
        lines.append("Date,Pain(0-10),Sleep(h),Energy,FlareDay")
        let healthDesc = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        if let logs = try? context.fetch(healthDesc) {
            for log in logs {
                let date = log.date.formatted(.dateTime.day().month().year())
                let energy = log.energyLevel == 1 ? "Low" : log.energyLevel == 2 ? "OK" : "High"
                lines.append("\(date),\(log.jointPainLevel),\(log.sleepHours),\(energy),\(log.isFlareDay)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Clear All Data

    // Scoped to the active profile only — `context.delete(model:)` with no
    // predicate deletes that model's rows for EVERY profile on the device,
    // which meant "Clear All Data" for one profile silently wiped every
    // other profile's training/nutrition/health/weight history too.
    // ExerciseLog/SetLog cascade-delete from TrainingSession (see Models.swift
    // relationship rules) and MealLog cascades from NutritionLog, so only the
    // parent models need explicit, profile-scoped deletion here.
    func clearAllData(context: ModelContext) {
        let pid = ActiveProfile.id

        // Delete ALL user data for this profile — GDPR Article 17 compliance.
        // Uses fetch + delete pattern because #Predicate on optional UUID
        // comparison is fragile across SwiftData versions.
        func deleteAll<T: PersistentModel>(_ type: T.Type, matching: (T) -> Bool) {
            let desc = FetchDescriptor<T>()
            if let items = try? context.fetch(desc) {
                for item in items where matching(item) {
                    context.delete(item)
                }
            }
        }

        try? context.delete(model: TrainingSession.self, where: #Predicate { $0.profileId == pid })
        try? context.delete(model: NutritionLog.self, where: #Predicate { $0.profileId == pid })
        try? context.delete(model: HealthLog.self, where: #Predicate { $0.profileId == pid })
        try? context.delete(model: BodyWeightLog.self, where: #Predicate { $0.profileId == pid })
        // Additional models — use fetch+filter for optional UUID safety
        func deleteProfileData<T: PersistentModel>(_ type: T.Type, idPath: KeyPath<T, UUID?>) {
            let desc = FetchDescriptor<T>()
            if let items = try? context.fetch(desc) {
                for item in items where item[keyPath: idPath] == pid {
                    context.delete(item)
                }
            }
        }
        deleteProfileData(DailyCheckIn.self, idPath: \.profileId)
        deleteProfileData(WaterEventLog.self, idPath: \.profileId)
        // NotificationRecord has non-optional profileId
        if let pid = pid {
            try? context.delete(model: NotificationRecord.self, where: #Predicate<NotificationRecord> { $0.profileId == pid })
        }
        deleteProfileData(ProgressPhoto.self, idPath: \.profileId)
        deleteProfileData(BloodPressureLog.self, idPath: \.profileId)
        deleteProfileData(SorenessRegionLog.self, idPath: \.profileId)
        deleteProfileData(OutdoorTimeLog.self, idPath: \.profileId)
        deleteProfileData(SymptomLog.self, idPath: \.profileId)
        deleteProfileData(BehaviorLog.self, idPath: \.profileId)
        deleteProfileData(BodyMeasurementLog.self, idPath: \.profileId)

        // Models without profileId — delete all
        try? context.delete(model: MobilityCheckIn.self)
        try? context.delete(model: Achievement.self)

        // Clear UserDefaults data
        let keysToRemove = [
            "glp1_enabled", "glp1_medication", "glp1_last_injection",
            "glp1_side_effects_today", "glp1_injection_day",
            "personal_health_narrative_cache", "personal_health_narrative_date",
        ]
        keysToRemove.forEach { UserDefaults.standard.removeObject(forKey: $0) }

        try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

// MARK: - Profile Rows

/// Every row below used to write only to `appState.profile` (an in-memory
/// mirror) — invisible on ProfileSwitcherView, fed stale values into the AI
/// lifestyle plan, and got silently reverted on next launch when
/// `syncFromPersonProfile` re-copied the untouched persisted profile back
/// over it. This writes through to the real, persisted `PersonProfile` too.
@MainActor
private func persistToProfile(context: ModelContext, _ mutate: (PersonProfile) -> Void) {
    guard let profile = ProfileStore.current(context: context) else { return }
    mutate(profile)
    try? context.save()
}

struct ProfileNameRow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""

    var body: some View {
        HStack {
            SettingsIcon(icon: "person.fill", color: Color(hex: "2563EB"))
            TextField("Your name", text: Binding(
                get: { appState.profile.name },
                set: { newValue in
                    appState.profile.name = newValue
                    persistToProfile(context: modelContext) { $0.name = newValue }
                }
            ))
        }
    }
}

struct ProfileWeightRow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack {
            SettingsIcon(icon: "scalemass.fill", color: Color(hex: "059669"))
            Text("Weight Goal")
            Spacer()
            TextField("kg", value: Binding(
                get: { appState.profile.bodyWeightGoalKg },
                set: { newValue in
                    appState.profile.bodyWeightGoalKg = newValue
                    persistToProfile(context: modelContext) { $0.bodyWeightGoalKg = newValue }
                }
            ), format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 60)
            .foregroundColor(.secondary)
            Text("kg")
                .foregroundColor(.secondary)
                .font(.subheadline)
        }
    }
}

struct ProfileProteinRow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack {
            SettingsIcon(icon: "fork.knife", color: Color(hex: "B45309"))
            Text("Protein Target")
            Spacer()
            TextField("g", value: Binding(
                get: { appState.profile.proteinTargetG },
                set: { newValue in
                    appState.profile.proteinTargetG = newValue
                    persistToProfile(context: modelContext) { $0.proteinTargetG = newValue }
                }
            ), format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 60)
            .foregroundColor(.secondary)
            Text("g")
                .foregroundColor(.secondary)
                .font(.subheadline)
        }
    }
}

struct ProfileCalorieRows: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack {
            SettingsIcon(icon: "flame.fill", color: Color(hex: "2563EB"))
            Text("Training Day kcal")
            Spacer()
            TextField("kcal", value: Binding(
                get: { appState.profile.trainingDayCalories },
                set: { newValue in
                    appState.profile.trainingDayCalories = newValue
                    persistToProfile(context: modelContext) { $0.trainingDayCalories = newValue }
                }
            ), format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 70)
            .foregroundColor(.secondary)
        }

        HStack {
            SettingsIcon(icon: "moon.fill", color: .purple)
            Text("Rest Day kcal")
            Spacer()
            TextField("kcal", value: Binding(
                get: { appState.profile.restDayCalories },
                set: { newValue in
                    appState.profile.restDayCalories = newValue
                    persistToProfile(context: modelContext) { $0.restDayCalories = newValue }
                }
            ), format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 70)
            .foregroundColor(.secondary)
        }
    }
}

// MARK: - Training Days Row

struct TrainingDaysRow: View {
    @Environment(AppState.self) private var appState

    let days: [(Int, String, String)] = [
        (2, "Mon", "Rest"),
        (3, "Tue", "A"),
        (4, "Wed", "Rest"),
        (5, "Thu", "B"),
        (6, "Fri", "Rest"),
        (7, "Sat", "C"),
        (1, "Sun", "Rest")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SettingsIcon(icon: "calendar", color: Color(hex: "2563EB"))
                Text("Training Days")
            }
            HStack(spacing: 6) {
                ForEach(days, id: \.0) { weekday, label, session in
                    let isTraining = appState.profile.trainingDays.contains(weekday)
                    VStack(spacing: 3) {
                        Text(label)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(session)
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 32, height: 32)
                            .background(isTraining
                                ? Color(hex: "2563EB")
                                : Color(.tertiarySystemBackground))
                            .foregroundColor(isTraining ? .white : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(.leading, 40)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - API Key Row

struct APIKeyRow: View {
    @Environment(AppState.self) private var appState
    var title: String = "Claude API Key"
    var placeholder: String = "sk-ant-..."
    var maskPrefix: String = "sk-"
    var iconColor: Color = Color(hex: "B45309")
    var currentValue: (() -> String)? = nil
    var save: ((String) -> Void)? = nil
    @Binding var showAPIKeyField: Bool
    @Binding var apiKeyInput: String
    @State private var saved = false

    private func readKey() -> String {
        currentValue?() ?? appState.anthropicAPIKey
    }
    private func writeKey(_ value: String) {
        if let save { save(value) } else { appState.anthropicAPIKey = value }
    }

    var maskedKey: String {
        let key = readKey()
        guard key.count > 8 else { return key.isEmpty ? "Not set" : "••••••••" }
        return maskPrefix + "••••••••" + String(key.suffix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation { showAPIKeyField.toggle() }
                if !showAPIKeyField { apiKeyInput = readKey() }
            } label: {
                HStack {
                    SettingsIcon(icon: "key.fill", color: iconColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .foregroundColor(.primary)
                        Text(maskedKey)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: showAPIKeyField ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if showAPIKeyField {
                let trimmedInput = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                VStack(spacing: 10) {
                    TextField(placeholder, text: $apiKeyInput)
                        .font(.system(.caption, design: .monospaced))
                        .padding(10)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    // Previously this had no validation at all — tapping
                    // Save with an empty field (paste didn't register, or
                    // tapped before pasting) still showed "Saved ✓" and
                    // silently stored an empty string, which looks exactly
                    // like "I clicked save and nothing happened."
                    Button {
                        guard !trimmedInput.isEmpty else { return }
                        writeKey(trimmedInput)
                        saved = true
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            saved = false
                            showAPIKeyField = false
                        }
                    } label: {
                        Text(saved ? "Saved ✓" : "Save API Key")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(saved
                                ? Color(hex: "059669")
                                : (trimmedInput.isEmpty ? Color(.systemGray4) : Color(hex: "2563EB")))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(trimmedInput.isEmpty)

                    if trimmedInput.isEmpty {
                        Text("Paste your key into the field above first.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Notification Row

struct NotificationRow: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var showPreferences = false

    private static let weekdayAbbreviations = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var scheduledDaysLabel: String {
        let names = TrainingDayStore.allSnapshots(context: modelContext)
            .filter { (1...7).contains($0.weekday) }
            .sorted { $0.weekday < $1.weekday }
            .map { Self.weekdayAbbreviations[$0.weekday] }
        return names.isEmpty ? "No days configured yet" : names.joined(separator: ", ")
    }

    var body: some View {
        @Bindable var state = appState
        VStack(spacing: 14) {

            // Training reminders row
            HStack {
                SettingsIcon(icon: "bell.fill", color: Color(hex: "2563EB"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Training Reminders")
                    Text(scheduledDaysLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { appState.profile.reminderEnabled },
                    set: { newVal in handleTrainingToggle(newVal, appState: appState) }
                ))
                .labelsHidden()
                .tint(Color(hex: "2563EB"))
            }

            if appState.profile.reminderEnabled {
                HStack {
                    SettingsIcon(icon: "clock.fill", color: .secondary)
                    Text("Remind me at")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    Spacer()
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { appState.profile.reminderTime },
                            set: { newTime in
                                appState.profile.reminderTime = newTime
                                Task {
                                    await NotificationManager.shared
                                        .scheduleTrainingReminders(at: newTime, profile: appState.profile, context: modelContext)
                                }
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }
            }

            Divider()

            // Pre-flare alerts row
            HStack {
                SettingsIcon(icon: "flame.fill", color: Color(hex: "DC2626"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pre-flare Alerts")
                    Text("Notified at 9 AM on elevated-risk days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { appState.profile.preFlareAlertsEnabled },
                    set: { newVal in handlePreFlareToggle(newVal, appState: appState) }
                ))
                .labelsHidden()
                .tint(Color(hex: "DC2626"))
            }

            Divider()

            // Notification preferences row
            Button {
                showPreferences = true
            } label: {
                HStack {
                    SettingsIcon(icon: "slider.horizontal.3", color: .secondary)
                    Text("Notification preferences")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .sheet(isPresented: $showPreferences) {
                NotificationPreferencesView()
            }
        }
        .padding(.vertical, 4)
    }

    private func handleTrainingToggle(_ newVal: Bool, appState: AppState) {
        Task {
            if newVal {
                let granted = await NotificationManager.shared.requestAuthorization()
                if granted {
                    appState.profile.reminderEnabled = true
                    await NotificationManager.shared
                        .scheduleTrainingReminders(at: appState.profile.reminderTime, profile: appState.profile, context: modelContext)
                } else {
                    appState.profile.reminderEnabled = false
                }
            } else {
                appState.profile.reminderEnabled = false
                NotificationManager.shared.cancelAllTrainingReminders()
            }
        }
    }

    private func handlePreFlareToggle(_ newVal: Bool, appState: AppState) {
        Task {
            if newVal {
                let granted = await NotificationManager.shared.requestAuthorization()
                appState.profile.preFlareAlertsEnabled = granted
            } else {
                appState.profile.preFlareAlertsEnabled = false
                NotificationManager.shared.cancelPreFlareAlertForToday()
            }
        }
    }
}

// MARK: - Notification Preferences

struct NotificationPreferencesView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    private static let groups: [(String, [NotificationCategory])] = [
        ("Activity", [.training, .restTimer]),
        ("Nutrition", [.meal, .supplement, .hydration, .postWorkoutNutrition]),
        ("Recovery", [.recovery, .weighIn, .flareRisk, .medication, .eyeCare, .circadian]),
        ("Progress", [.milestone, .weeklyDigest]),
    ]

    var body: some View {
        @Bindable var state = appState
        NavigationStack {
            List {
                ForEach(Self.groups, id: \.0) { group in
                    Section(group.0) {
                        ForEach(group.1) { category in
                            Toggle(isOn: Binding(
                                get: { appState.profile.notificationCategoryEnabled[category.rawValue] ?? false },
                                set: { appState.profile.notificationCategoryEnabled[category.rawValue] = $0 }
                            )) {
                                Text(category.displayName)
                            }
                        }
                    }
                }

                Section("Quiet hours") {
                    Toggle("Enable quiet hours", isOn: $state.profile.notificationsQuietHoursEnabled)
                    if appState.profile.notificationsQuietHoursEnabled {
                        DatePicker(
                            "Start",
                            selection: $state.profile.quietHoursStart,
                            displayedComponents: .hourAndMinute
                        )
                        DatePicker(
                            "End",
                            selection: $state.profile.quietHoursEnd,
                            displayedComponents: .hourAndMinute
                        )
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Backup File Document

struct BackupJSONFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - CSV Export Sheet

struct CSVExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    var csv: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(csv)
                    .font(.system(.caption, design: .monospaced))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: csv, subject: Text("Paya Data Export")) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share CSV")
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    var title: String
    var icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(title)
        }
    }
}

// MARK: - Settings Icon

struct SettingsIcon: View {
    var icon: String
    var color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .frame(width: 28, height: 28)
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}
