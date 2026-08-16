import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Privacy Badge Card
// Turns Paya's local-first architecture from an invisible technical
// choice into a visible competitive advantage. Whoop/Fitbit users
// constantly complain about data lock-in and opaque privacy policies.
//
// This card:
// 1. Shows a visible "100% local — your data stays on-device" badge
// 2. Surfaces data stats (total entries, days tracked)
// 3. Provides one-tap full data export (JSON) so users can verify
//    and own their data at any time
//
// Cost to build: zero. Cost to Paya: zero server fees forever.
// Marketing value: enormous against subscription-cloud competitors.

struct PrivacyBadgeCard: View {

    @Environment(\.modelContext) private var modelContext

    @State private var sessionCount = 0
    @State private var nutritionDays = 0
    @State private var weightEntries = 0
    @State private var measurementEntries = 0
    @State private var checkInCount = 0
    @State private var behaviorLogCount = 0
    @State private var waterEventCount = 0
    @State private var totalDataPoints = 0
    @State private var oldestDate: Date?
    @State private var showExportSheet = false
    @State private var exportJSON: String = ""
    @State private var showFullDashboard = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(Pulse.positive)
                Text("Your data, your device")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 9))
                    Text("100% local")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(Pulse.positive)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Pulse.positive.opacity(0.1))
                .clipShape(Capsule())
            }

            // Data stats (compact row)
            HStack(spacing: 0) {
                dataStat(value: "\(sessionCount)", label: "Sessions", icon: "dumbbell.fill")
                Divider().frame(height: 30).padding(.horizontal, 8)
                dataStat(value: "\(nutritionDays)", label: "Nutrition days", icon: "fork.knife")
                Divider().frame(height: 30).padding(.horizontal, 8)
                dataStat(value: "\(weightEntries)", label: "Weigh-ins", icon: "scalemass.fill")
            }

            // Expandable full breakdown
            if showFullDashboard {
                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        dataStat(value: "\(checkInCount)", label: "Check-ins", icon: "sun.max.fill")
                        Divider().frame(height: 30).padding(.horizontal, 8)
                        dataStat(value: "\(behaviorLogCount)", label: "Behavior logs", icon: "tag.fill")
                        Divider().frame(height: 30).padding(.horizontal, 8)
                        dataStat(value: "\(waterEventCount)", label: "Water events", icon: "drop.fill")
                    }

                    HStack(spacing: 0) {
                        dataStat(value: "\(measurementEntries)", label: "Measurements", icon: "ruler.fill")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showFullDashboard.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text(showFullDashboard ? "Less detail" : "Full data breakdown")
                        .font(.system(size: 10, weight: .medium))
                    Image(systemName: showFullDashboard ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                }
                .foregroundColor(Pulse.positive)
            }

            // Days tracked
            if let oldest = oldestDate {
                let days = Calendar.current.dateComponents([.day], from: oldest, to: Date()).day ?? 0
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 9))
                        .foregroundColor(Pulse.textTertiary)
                    Text("\(totalDataPoints) data points across \(days) days — all stored locally on this device.")
                        .font(.system(size: 10))
                        .foregroundColor(Pulse.textTertiary)
                }
            }

            // Differentiator callout
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Pulse.hydration)
                    .padding(.top, 1)
                Text("No account, no cloud sync, no subscription wall. Your training, nutrition, and health data never leaves your iPhone. Export anytime — it's yours.")
                    .font(.system(size: 10))
                    .foregroundColor(Pulse.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Export button
            Button {
                exportJSON = buildExportJSON()
                showExportSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11, weight: .bold))
                    Text("Export all my data")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(Pulse.positive)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Pulse.positive.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .payaCard(padding: 14)
        .onAppear { loadStats() }
        .sheet(isPresented: $showExportSheet) {
            DataExportSheet(json: exportJSON)
        }
    }

    private func dataStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(Pulse.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func loadStats() {
        let pid = ActiveProfile.id

        let sessionDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.profileId == pid && $0.isCompleted }
        )
        sessionCount = (try? modelContext.fetchCount(sessionDescriptor)) ?? 0

        let nutritionDescriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.profileId == pid }
        )
        nutritionDays = (try? modelContext.fetchCount(nutritionDescriptor)) ?? 0

        let weightDescriptor = FetchDescriptor<BodyWeightLog>(
            predicate: #Predicate<BodyWeightLog> { $0.profileId == pid }
        )
        weightEntries = (try? modelContext.fetchCount(weightDescriptor)) ?? 0

        let measurementDescriptor = FetchDescriptor<BodyMeasurementLog>(
            predicate: #Predicate<BodyMeasurementLog> { $0.profileId == pid }
        )
        measurementEntries = (try? modelContext.fetchCount(measurementDescriptor)) ?? 0

        let checkInDescriptor = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate<DailyCheckIn> { $0.profileId == pid }
        )
        checkInCount = (try? modelContext.fetchCount(checkInDescriptor)) ?? 0

        let behaviorDescriptor = FetchDescriptor<BehaviorLog>(
            predicate: #Predicate<BehaviorLog> { $0.profileId == pid }
        )
        behaviorLogCount = (try? modelContext.fetchCount(behaviorDescriptor)) ?? 0

        let waterDescriptor = FetchDescriptor<WaterEventLog>(
            predicate: #Predicate<WaterEventLog> { $0.profileId == pid }
        )
        waterEventCount = (try? modelContext.fetchCount(waterDescriptor)) ?? 0

        totalDataPoints = sessionCount + nutritionDays + weightEntries + measurementEntries + checkInCount + behaviorLogCount + waterEventCount

        // Find oldest entry
        let oldestSessionDesc = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        let oldestSession = (try? modelContext.fetch(oldestSessionDesc))?.first?.date

        let oldestNutritionDesc = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        let oldestNutrition = (try? modelContext.fetch(oldestNutritionDesc))?.first?.date

        oldestDate = [oldestSession, oldestNutrition].compactMap { $0 }.min()
    }

    // MARK: - Export JSON

    private func buildExportJSON() -> String {
        let pid = ActiveProfile.id
        let dateFormatter = ISO8601DateFormatter()

        // Sessions
        let sessDesc = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.profileId == pid && $0.isCompleted },
            sortBy: [SortDescriptor(\.date)]
        )
        let sessions = (try? modelContext.fetch(sessDesc)) ?? []

        var sessionEntries: [[String: Any]] = []
        for s in sessions {
            var entry: [String: Any] = [
                "date": dateFormatter.string(from: s.date),
                "type": s.sessionType,
                "durationMinutes": s.durationMinutes
            ]
            if let rpe = s.subjectiveRPE { entry["rpe"] = rpe }
            var exercises: [[String: Any]] = []
            for ex in s.exercises {
                var sets: [[String: Any]] = []
                for set in ex.sets where set.isCompleted {
                    sets.append([
                        "weightKg": round(set.weightKg * 100) / 100,
                        "reps": set.reps
                    ])
                }
                exercises.append([
                    "name": ex.exerciseName,
                    "sets": sets
                ])
            }
            entry["exercises"] = exercises
            sessionEntries.append(entry)
        }

        // Nutrition
        let nutDesc = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        let nutritionLogs = (try? modelContext.fetch(nutDesc)) ?? []
        var nutritionEntries: [[String: Any]] = []
        for n in nutritionLogs {
            nutritionEntries.append([
                "date": dateFormatter.string(from: n.date),
                "proteinG": round(n.totalProtein * 10) / 10,
                "calories": round(n.totalCalories),
                "mealCount": n.meals.count
            ])
        }

        // Body weight
        let wDesc = FetchDescriptor<BodyWeightLog>(
            predicate: #Predicate<BodyWeightLog> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        let weights = (try? modelContext.fetch(wDesc)) ?? []
        var weightEntries: [[String: Any]] = []
        for w in weights {
            weightEntries.append([
                "date": dateFormatter.string(from: w.date),
                "weightKg": round(w.weightKg * 100) / 100
            ])
        }

        // Check-ins
        let ciDesc = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate<DailyCheckIn> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        let checkIns = (try? modelContext.fetch(ciDesc)) ?? []
        var checkInEntries: [[String: Any]] = []
        for ci in checkIns {
            checkInEntries.append([
                "date": dateFormatter.string(from: ci.date),
                "soreness": ci.soreness,
                "energy": ci.energy,
                "symptomTags": ci.symptomTags
            ])
        }

        // Behavior logs
        let blDesc = FetchDescriptor<BehaviorLog>(
            predicate: #Predicate<BehaviorLog> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        let behaviorLogs = (try? modelContext.fetch(blDesc)) ?? []
        var behaviorEntries: [[String: Any]] = []
        for bl in behaviorLogs {
            behaviorEntries.append([
                "date": dateFormatter.string(from: bl.date),
                "behaviors": bl.tagIds
            ])
        }

        let export: [String: Any] = [
            "app": "Paya",
            "exportDate": dateFormatter.string(from: Date()),
            "dataOwnership": "This data belongs to you. Exported from Paya — 100% on-device, never sent to any server.",
            "sessions": sessionEntries,
            "nutrition": nutritionEntries,
            "bodyWeight": weightEntries,
            "checkIns": checkInEntries,
            "behaviorLogs": behaviorEntries
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"error\": \"Failed to export\"}"
        }
        return json
    }
}

// MARK: - Data Export Sheet

struct DataExportSheet: View {
    var json: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(Pulse.positive)
                        Text("Your data export")
                            .font(.headline)
                    }

                    Text("Everything Paya knows about you, in standard JSON format. Copy, save, import into any tool — it's yours.")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)

                    Text(String(json.prefix(5000)))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Pulse.textTertiary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Pulse.surfaceElevatedFallback)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    if json.count > 5000 {
                        Text("… \(json.count - 5000) more characters (full data in shared file)")
                            .font(.system(size: 9))
                            .foregroundColor(Pulse.textTertiary)
                    }
                }
                .padding()
            }
            .navigationTitle("Data export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: json, subject: Text("Paya Data Export")) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
