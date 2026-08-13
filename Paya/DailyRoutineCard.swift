import SwiftUI
import CoreLocation

// MARK: - Daily Routine Reminders Card
//
// Context-aware routine reminders that integrate with environmental
// data (UV index via WeatherKit, step count via HealthKit) and time
// of day to surface the RIGHT reminder at the RIGHT time.
//
// Evidence basis:
// - WHO (2024): UV index ≥3 requires sun protection; SPF 30+
//   reapplied every 2 hours during exposure.
// - EFSA (2017): adequate water intake 2.5L/day (men), 2.0L/day
//   (women); increase 500ml per hour of exercise.
// - AAO (2023): artificial tears every 2-4 hours for digital eye
//   strain; blink rate drops 66% during screen use.
//
// Users can add custom routines. Built-in routines are seeded on
// first launch and can be disabled.

// MARK: - Routine Model (UserDefaults-backed, no SwiftData)

struct DailyRoutine: Codable, Identifiable {
    var id: UUID
    var name: String
    var icon: String           // SF Symbol name
    var category: String       // sun, hydration, eye, custom
    var isEnabled: Bool
    var intervalMinutes: Int   // how often (0 = once daily)
    var timeOfDay: String      // morning, midday, evening, anytime
    var conditions: [String]   // "sunny", "hot", "exercised", "screen"
    var lastDone: Date?
    var isBuiltIn: Bool

    var isDue: Bool {
        guard isEnabled else { return false }
        guard let last = lastDone else { return true }
        if intervalMinutes == 0 {
            return !Calendar.current.isDateInToday(last)
        }
        return Date().timeIntervalSince(last) > Double(intervalMinutes * 60)
    }

    var nextDueLabel: String {
        guard let last = lastDone, intervalMinutes > 0 else { return "Now" }
        let nextDue = last.addingTimeInterval(Double(intervalMinutes * 60))
        if nextDue <= Date() { return "Now" }
        let remaining = Int(nextDue.timeIntervalSince(Date()) / 60)
        if remaining < 60 { return "in \(remaining)m" }
        return "in \(remaining / 60)h"
    }
}

@MainActor
@Observable
class DailyRoutineStore {
    static let shared = DailyRoutineStore()
    private let key = "paya_daily_routines"
    private let weatherCheckedKey = "paya_routine_weather_last"

    var routines: [DailyRoutine] = []
    var uvIndex: Int? = nil
    var temperature: Double? = nil // Celsius
    var weatherCondition: String = "" // "sunny", "cloudy", etc.

    init() { load() }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([DailyRoutine].self, from: data)
        else {
            seedDefaults()
            return
        }
        routines = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(routines) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func markDone(_ id: UUID) {
        if let idx = routines.firstIndex(where: { $0.id == id }) {
            routines[idx].lastDone = Date()
            save()
        }
    }

    func toggle(_ id: UUID) {
        if let idx = routines.firstIndex(where: { $0.id == id }) {
            routines[idx].isEnabled.toggle()
            save()
        }
    }

    func addCustom(name: String, icon: String, intervalMinutes: Int) {
        let routine = DailyRoutine(
            id: UUID(),
            name: name,
            icon: icon,
            category: "custom",
            isEnabled: true,
            intervalMinutes: intervalMinutes,
            timeOfDay: "anytime",
            conditions: [],
            isBuiltIn: false
        )
        routines.append(routine)
        save()
    }

    func remove(_ id: UUID) {
        routines.removeAll { $0.id == id && !$0.isBuiltIn }
        save()
    }

    var dueRoutines: [DailyRoutine] {
        let hour = Calendar.current.component(.hour, from: Date())
        return routines.filter { routine in
            guard routine.isDue else { return false }

            // Time-of-day filter
            switch routine.timeOfDay {
            case "morning": if hour > 11 { return false }
            case "midday": if hour < 10 || hour > 16 { return false }
            case "evening": if hour < 17 { return false }
            default: break
            }

            // Condition filter
            for condition in routine.conditions {
                switch condition {
                case "sunny":
                    if let uv = uvIndex, uv < 3 { return false }
                case "hot":
                    if let temp = temperature, temp < 25 { return false }
                default: break
                }
            }
            return true
        }
    }

    // MARK: - Weather fetch (Open-Meteo — free, no API key, no paid entitlements)

    func fetchWeatherIfNeeded() async {
        let lastCheck = UserDefaults.standard.double(forKey: weatherCheckedKey)
        let now = Date().timeIntervalSince1970
        guard now - lastCheck > 1800 else { return }

        let locationManager = CLLocationManager()
        guard let location = locationManager.location else { return }

        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,uv_index,weather_code&timezone=auto"
        guard let url = URL(string: urlStr) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let current = json["current"] as? [String: Any] {
                if let uv = current["uv_index"] as? Double {
                    uvIndex = Int(uv.rounded())
                }
                if let temp = current["temperature_2m"] as? Double {
                    temperature = temp
                }
                if let code = current["weather_code"] as? Int {
                    // WMO weather codes: 0-1 = clear, 2-3 = cloudy, 51+ = rain
                    switch code {
                    case 0, 1: weatherCondition = "sunny"
                    case 2, 3: weatherCondition = "cloudy"
                    case 45, 48: weatherCondition = "foggy"
                    default: weatherCondition = "rainy"
                    }
                }
                UserDefaults.standard.set(now, forKey: weatherCheckedKey)
            }
        } catch {
            // Network unavailable — fail silently, routines still work without weather
        }
    }

    // MARK: - Seed

    private func seedDefaults() {
        routines = [
            DailyRoutine(
                id: UUID(), name: "Apply sunscreen", icon: "sun.max.trianglebadge.exclamationmark.fill",
                category: "sun", isEnabled: true, intervalMinutes: 120,
                timeOfDay: "anytime", conditions: ["sunny"],
                isBuiltIn: true
            ),
            DailyRoutine(
                id: UUID(), name: "Drink water", icon: "drop.fill",
                category: "hydration", isEnabled: true, intervalMinutes: 60,
                timeOfDay: "anytime", conditions: [],
                isBuiltIn: true
            ),
            DailyRoutine(
                id: UUID(), name: "Eye drops", icon: "eye.fill",
                category: "eye", isEnabled: true, intervalMinutes: 180,
                timeOfDay: "anytime", conditions: [],
                isBuiltIn: true
            ),
            DailyRoutine(
                id: UUID(), name: "Stretch break", icon: "figure.flexibility",
                category: "mobility", isEnabled: true, intervalMinutes: 120,
                timeOfDay: "anytime", conditions: [],
                isBuiltIn: true
            ),
            DailyRoutine(
                id: UUID(), name: "Take vitamins", icon: "pill.fill",
                category: "supplement", isEnabled: true, intervalMinutes: 0,
                timeOfDay: "morning", conditions: [],
                isBuiltIn: true
            ),
            DailyRoutine(
                id: UUID(), name: "SPF lip balm", icon: "mouth.fill",
                category: "sun", isEnabled: false, intervalMinutes: 120,
                timeOfDay: "anytime", conditions: ["sunny"],
                isBuiltIn: true
            ),
        ]
        save()
    }
}

// MARK: - Daily Routine Card View

struct DailyRoutineCard: View {

    @State private var store = DailyRoutineStore.shared
    @State private var showSettings = false
    @State private var showAddSheet = false

    var body: some View {
        let due = store.dueRoutines
        if !due.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "checklist.checked")
                        .foregroundColor(Color(hex: "059669"))
                    Text("Daily routines")
                        .font(.subheadline.weight(.semibold))
                    Spacer()

                    // Weather badge
                    if let uv = store.uvIndex, uv >= 3 {
                        HStack(spacing: 3) {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 9))
                            Text("UV \(uv)")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(uv >= 6 ? Color(hex: "DC2626") : Color(hex: "F59E0B"))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background((uv >= 6 ? Color(hex: "DC2626") : Color(hex: "F59E0B")).opacity(0.1))
                        .clipShape(Capsule())
                    }

                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                ForEach(due) { routine in
                    HStack(spacing: 10) {
                        Image(systemName: routine.icon)
                            .font(.system(size: 14))
                            .foregroundColor(colorForCategory(routine.category))
                            .frame(width: 28, height: 28)
                            .background(colorForCategory(routine.category).opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 1) {
                            Text(routine.name)
                                .font(.system(size: 12, weight: .semibold))
                            if routine.intervalMinutes > 0 {
                                Text("Every \(routine.intervalMinutes / 60)h")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // Sun-specific: show UV info
                        if routine.category == "sun", let uv = store.uvIndex {
                            Text("UV \(uv)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(uv >= 6 ? Color(hex: "DC2626") : Color(hex: "F59E0B"))
                        }

                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                store.markDone(routine.id)
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 22))
                                .foregroundColor(Color(hex: "059669"))
                        }
                    }
                    .padding(.vertical, 2)
                }

                // Sunscreen-specific tip
                if let uv = store.uvIndex, uv >= 6 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "DC2626"))
                        Text("UV index is \(uv) — reapply SPF 30+ every 2 hours outdoors (WHO 2024).")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "DC2626"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .payaCard(padding: 14)
            .onAppear {
                Task { await store.fetchWeatherIfNeeded() }
            }
            .sheet(isPresented: $showSettings) {
                RoutineSettingsSheet(store: store, showAddSheet: $showAddSheet)
            }
            .sheet(isPresented: $showAddSheet) {
                AddRoutineSheet(store: store)
            }
        }
    }

    private func colorForCategory(_ category: String) -> Color {
        switch category {
        case "sun": return Color(hex: "F59E0B")
        case "hydration": return Color(hex: "0891B2")
        case "eye": return Color(hex: "2563EB")
        case "mobility": return Color(hex: "8B5CF6")
        case "supplement": return Color(hex: "059669")
        default: return Color(hex: "059669")
        }
    }
}

// MARK: - Settings Sheet

struct RoutineSettingsSheet: View {
    var store: DailyRoutineStore
    @Binding var showAddSheet: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Built-in routines") {
                    ForEach(store.routines.filter(\.isBuiltIn)) { routine in
                        HStack {
                            Image(systemName: routine.icon)
                                .foregroundColor(.secondary)
                                .frame(width: 24)
                            Text(routine.name)
                                .font(.subheadline)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { routine.isEnabled },
                                set: { _ in store.toggle(routine.id) }
                            ))
                            .labelsHidden()
                        }
                    }
                }

                let custom = store.routines.filter { !$0.isBuiltIn }
                if !custom.isEmpty {
                    Section("Custom routines") {
                        ForEach(custom) { routine in
                            HStack {
                                Image(systemName: routine.icon)
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)
                                Text(routine.name)
                                    .font(.subheadline)
                                Spacer()
                                Button {
                                    store.remove(routine.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showAddSheet = true
                        }
                    } label: {
                        Label("Add custom routine", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Routines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Add Routine Sheet

struct AddRoutineSheet: View {
    var store: DailyRoutineStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var icon = "star.fill"
    @State private var intervalHours = 2

    private let iconOptions = [
        "star.fill", "heart.fill", "drop.fill", "eye.fill",
        "pill.fill", "figure.walk", "cup.and.saucer.fill",
        "leaf.fill", "cross.case.fill", "brain.head.profile.fill",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Take medication", text: $name)
                }
                Section("Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(iconOptions, id: \.self) { opt in
                                Button {
                                    icon = opt
                                } label: {
                                    Image(systemName: opt)
                                        .font(.title3)
                                        .foregroundColor(icon == opt ? .white : .secondary)
                                        .frame(width: 40, height: 40)
                                        .background(icon == opt ? Color(hex: "059669") : Color(.tertiarySystemBackground))
                                        .clipShape(Circle())
                                }
                            }
                        }
                    }
                }
                Section("Frequency") {
                    Picker("Repeat every", selection: $intervalHours) {
                        Text("Once daily").tag(0)
                        Text("Every hour").tag(1)
                        Text("Every 2 hours").tag(2)
                        Text("Every 3 hours").tag(3)
                        Text("Every 4 hours").tag(4)
                    }
                }
            }
            .navigationTitle("New routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        guard !name.isEmpty else { return }
                        store.addCustom(name: name, icon: icon, intervalMinutes: intervalHours * 60)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
