import WidgetKit
import SwiftUI

struct PayaWidgetSnapshot: Codable {
    var recoveryScore: Int?
    var recoveryBand: String?
    var trainingDayLabel: String?
    var isTrainingDay: Bool
    var waterMl: Int
    var waterTargetMl: Int
    var proteinG: Double
    var proteinTargetG: Double
    var calories: Double
    var calorieTarget: Double
    var streak: Int
    var stepsToday: Int?
    var stepGoal: Int?
    var nextExercises: [String]?
    var updatedAt: Date

    init(
        recoveryScore: Int? = nil, recoveryBand: String? = nil,
        trainingDayLabel: String? = nil, isTrainingDay: Bool = false,
        waterMl: Int = 0, waterTargetMl: Int = 2500,
        proteinG: Double = 0, proteinTargetG: Double = 0,
        calories: Double = 0, calorieTarget: Double = 0,
        streak: Int = 0, stepsToday: Int? = nil, stepGoal: Int? = nil,
        nextExercises: [String]? = nil, updatedAt: Date = .now
    ) {
        self.recoveryScore = recoveryScore
        self.recoveryBand = recoveryBand
        self.trainingDayLabel = trainingDayLabel
        self.isTrainingDay = isTrainingDay
        self.waterMl = waterMl
        self.waterTargetMl = waterTargetMl
        self.proteinG = proteinG
        self.proteinTargetG = proteinTargetG
        self.calories = calories
        self.calorieTarget = calorieTarget
        self.streak = streak
        self.stepsToday = stepsToday
        self.stepGoal = stepGoal
        self.nextExercises = nextExercises
        self.updatedAt = updatedAt
    }
}

// MARK: - Shared Provider

struct PayaEntry: TimelineEntry {
    let date: Date
    let snapshot: PayaWidgetSnapshot?
}

struct PayaProvider: TimelineProvider {
    static let appGroupId = "group.Paya.Paya.shared"
    static let snapshotKey = "widget_snapshot"

    func placeholder(in context: Context) -> PayaEntry {
        PayaEntry(date: .now, snapshot: PayaWidgetSnapshot(
            recoveryScore: 78, recoveryBand: "Steady", trainingDayLabel: "Push Day",
            isTrainingDay: true, waterMl: 1200, waterTargetMl: 2500,
            proteinG: 95, proteinTargetG: 160, calories: 1400, calorieTarget: 2200,
            updatedAt: .now
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (PayaEntry) -> Void) {
        completion(PayaEntry(date: .now, snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PayaEntry>) -> Void) {
        let entry = PayaEntry(date: .now, snapshot: loadSnapshot())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadSnapshot() -> PayaWidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId),
              let data = defaults.data(forKey: Self.snapshotKey) else { return nil }
        return try? JSONDecoder().decode(PayaWidgetSnapshot.self, from: data)
    }
}

// MARK: - Recovery Widget Views

struct RecoveryWidgetView: View {
    var entry: PayaEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemSmall:
                SmallRecoveryView(snapshot: snapshot)
            default:
                MediumRecoveryView(snapshot: snapshot)
            }
        } else {
            PlaceholderView()
        }
    }
}

private struct SmallRecoveryView: View {
    let snapshot: PayaWidgetSnapshot

    private var bandColor: Color {
        switch snapshot.recoveryBand?.lowercased() {
        case "primed": return Color(red: 0.02, green: 0.59, blue: 0.41)
        case "steady": return Color(red: 0.15, green: 0.39, blue: 0.92)
        case "caution": return Color(red: 0.96, green: 0.62, blue: 0.04)
        default: return Color(red: 0.86, green: 0.15, blue: 0.15)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(bandColor).frame(width: 8, height: 8)
                Text("RECOVERY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
            }

            Text(snapshot.recoveryScore.map { "\($0)" } ?? "—")
                .font(.system(size: 36, weight: .bold, design: .rounded))

            Text(snapshot.recoveryBand ?? "No data")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(bandColor)

            Spacer(minLength: 2)

            if snapshot.isTrainingDay, let label = snapshot.trainingDayLabel {
                HStack(spacing: 3) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 8))
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                }
                .lineLimit(1)
            } else {
                Text("Rest day")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct MediumRecoveryView: View {
    let snapshot: PayaWidgetSnapshot

    private var bandColor: Color {
        switch snapshot.recoveryBand?.lowercased() {
        case "primed": return Color(red: 0.02, green: 0.59, blue: 0.41)
        case "steady": return Color(red: 0.15, green: 0.39, blue: 0.92)
        case "caution": return Color(red: 0.96, green: 0.62, blue: 0.04)
        default: return Color(red: 0.86, green: 0.15, blue: 0.15)
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Circle().fill(bandColor).frame(width: 7, height: 7)
                    Text("RECOVERY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
                Text(snapshot.recoveryScore.map { "\($0)" } ?? "—")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text(snapshot.recoveryBand ?? "No data")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(bandColor)

                Spacer(minLength: 2)

                if snapshot.isTrainingDay {
                    HStack(spacing: 3) {
                        Image(systemName: "dumbbell.fill").font(.system(size: 8))
                        Text(snapshot.trainingDayLabel ?? "Training day")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .lineLimit(1)
                } else {
                    Text("Rest day")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                MiniProgress(label: "Protein", value: snapshot.proteinG, target: snapshot.proteinTargetG, unit: "g", color: Color(red: 0.15, green: 0.39, blue: 0.92))
                MiniProgress(label: "Calories", value: snapshot.calories, target: snapshot.calorieTarget, unit: "kcal", color: Color(red: 0.71, green: 0.26, blue: 0.04))
                MiniProgress(label: "Water", value: Double(snapshot.waterMl), target: Double(snapshot.waterTargetMl), unit: "ml", color: .cyan)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Nutrition Widget Views

struct NutritionWidgetView: View {
    var entry: PayaEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemSmall:
                SmallNutritionView(snapshot: snapshot)
            default:
                MediumNutritionView(snapshot: snapshot)
            }
        } else {
            PlaceholderView()
        }
    }
}

private struct SmallNutritionView: View {
    let snapshot: PayaWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NUTRITION")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(snapshot.proteinG))g")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))
                Text("protein")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 2)

            MiniProgress(label: "Cal", value: snapshot.calories, target: snapshot.calorieTarget, unit: "", color: Color(red: 0.71, green: 0.26, blue: 0.04))
            MiniProgress(label: "Water", value: Double(snapshot.waterMl), target: Double(snapshot.waterTargetMl), unit: "", color: .cyan)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct MediumNutritionView: View {
    let snapshot: PayaWidgetSnapshot

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("NUTRITION")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(snapshot.proteinG))")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))
                    if snapshot.proteinTargetG > 0 {
                        Text("/ \(Int(snapshot.proteinTargetG))g")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                Text("protein")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer(minLength: 2)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                MiniProgress(label: "Calories", value: snapshot.calories, target: snapshot.calorieTarget, unit: "kcal", color: Color(red: 0.71, green: 0.26, blue: 0.04))

                MiniProgress(label: "Water", value: Double(snapshot.waterMl), target: Double(snapshot.waterTargetMl), unit: "ml", color: .cyan)

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Shared Components

private struct MiniProgress: View {
    let label: String
    let value: Double
    let target: Double
    let unit: String
    let color: Color

    private var fraction: Double {
        guard target > 0 else { return 0 }
        return min(1, value / target)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.system(size: 9, weight: .medium)).foregroundColor(.secondary)
                Spacer()
                Text(unit.isEmpty ? "\(Int(value))/\(Int(target))" : "\(Int(value))\(unit)")
                    .font(.system(size: 9, weight: .semibold))
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15)).frame(height: 4)
                    Capsule().fill(color).frame(width: geo.size.width * fraction, height: 4)
                }
            }
            .frame(height: 4)
        }
    }
}

private struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "heart.text.square")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("Open Paya to sync")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Widget Declarations

struct RecoveryWidget: Widget {
    let kind: String = "PayaRecoveryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PayaProvider()) { entry in
            RecoveryWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Recovery & Today")
        .description("Recovery score, training day, protein, calories, and water at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NutritionWidget: Widget {
    let kind: String = "PayaNutritionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PayaProvider()) { entry in
            NutritionWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Nutrition")
        .description("Protein, calorie, and water intake progress for today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Hydration Widget

struct HydrationWidgetView: View {
    var entry: PayaEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            SmallHydrationView(snapshot: snapshot)
        } else {
            PlaceholderView()
        }
    }
}

private struct SmallHydrationView: View {
    let snapshot: PayaWidgetSnapshot

    private var fraction: Double {
        guard snapshot.waterTargetMl > 0 else { return 0 }
        return min(1, Double(snapshot.waterMl) / Double(snapshot.waterTargetMl))
    }

    private var glassesLeft: Int {
        let remaining = max(0, snapshot.waterTargetMl - snapshot.waterMl)
        return (remaining + 249) / 250
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.cyan)
                Text("HYDRATION")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
            }

            Text("\(snapshot.waterMl)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.cyan)
            + Text(" ml")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.cyan.opacity(0.15)).frame(height: 6)
                    Capsule().fill(Color.cyan).frame(width: geo.size.width * fraction, height: 6)
                }
            }
            .frame(height: 6)

            Spacer(minLength: 2)

            if glassesLeft > 0 {
                Text("\(glassesLeft) glasses to go")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.cyan)
                    Text("Target reached")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.cyan)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct HydrationWidget: Widget {
    let kind: String = "PayaHydrationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PayaProvider()) { entry in
            HydrationWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Hydration")
        .description("Water intake progress with glasses remaining.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Today's Training Widget

struct TrainingWidgetView: View {
    var entry: PayaEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            SmallTrainingView(snapshot: snapshot)
        } else {
            PlaceholderView()
        }
    }
}

private struct SmallTrainingView: View {
    let snapshot: PayaWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 10))
                    .foregroundColor(snapshot.isTrainingDay ? Color(red: 0.02, green: 0.59, blue: 0.41) : .secondary)
                Text("TODAY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
            }

            if snapshot.isTrainingDay, let label = snapshot.trainingDayLabel {
                Text(label)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(2)
            } else {
                Text("Rest Day")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 2)

            if let exercises = snapshot.nextExercises, !exercises.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(exercises.prefix(3), id: \.self) { name in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(red: 0.02, green: 0.59, blue: 0.41).opacity(0.6))
                                .frame(width: 4, height: 4)
                            Text(name)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    if exercises.count > 3 {
                        Text("+\(exercises.count - 3) more")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            } else if snapshot.isTrainingDay {
                Text("Open Paya to start")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            } else {
                HStack(spacing: 4) {
                    if snapshot.streak > 0 {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text("\(snapshot.streak) day streak")
                            .font(.system(size: 10, weight: .semibold))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct TrainingWidget: Widget {
    let kind: String = "PayaTrainingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PayaProvider()) { entry in
            TrainingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Training")
        .description("Today's workout plan with exercise preview.")
        .supportedFamilies([.systemSmall])
    }
}
