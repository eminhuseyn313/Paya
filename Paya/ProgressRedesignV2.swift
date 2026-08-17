import SwiftUI
import SwiftData

// MARK: - Training Calendar V2
// Month-based calendar: real dates, day-code colors from your actual
// training days, month navigation, tap a day to see its sessions.

struct TrainingCalendarV2: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var monthOffset = 0
    @State private var sessionsByDay: [Date: [TrainingSession]] = [:]
    @State private var dayColors: [String: String] = [:]   // code -> hex
    @State private var selectedDate: Date? = nil

    private var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2   // Monday
        return c
    }

    private var displayedMonth: Date {
        calendar.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Text("Training Calendar")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    monthOffset -= 1
                    selectedDate = nil
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Pulse.textTertiary)
                        .frame(width: 28, height: 28)
                        .background(Pulse.surfaceElevatedFallback)
                        .clipShape(Circle())
                }
                Text(monthTitle)
                    .font(.caption.weight(.semibold))
                    .frame(minWidth: 100)
                Button {
                    if monthOffset < 0 {
                        monthOffset += 1
                        selectedDate = nil
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundColor(monthOffset < 0 ? .secondary : .secondary.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .background(Pulse.surfaceElevatedFallback)
                        .clipShape(Circle())
                }
                .disabled(monthOffset >= 0)
            }

            // Weekday labels
            HStack(spacing: 4) {
                ForEach(["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Pulse.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Grid
            let days = monthDays()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let date = day {
                        CalendarDayCell(
                            date: date,
                            sessions: sessionsByDay[calendar.startOfDay(for: date)] ?? [],
                            dayColors: dayColors,
                            isToday: calendar.isDateInToday(date),
                            isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false,
                            isFuture: date > Date()
                        )
                        .onTapGesture {
                            let key = calendar.startOfDay(for: date)
                            if !(sessionsByDay[key] ?? []).isEmpty {
                                withAnimation(.spring(response: 0.25)) {
                                    selectedDate = selectedDate == date ? nil : date
                                }
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(date.formatted(date: .abbreviated, time: .omitted))
                        .accessibilityValue((sessionsByDay[calendar.startOfDay(for: date)] ?? []).isEmpty ? "No session" : "Session logged")
                        .accessibilityAddTraits((sessionsByDay[calendar.startOfDay(for: date)] ?? []).isEmpty ? [] : .isButton)
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }

            // Selected day detail
            if let selected = selectedDate {
                let key = calendar.startOfDay(for: selected)
                let daySessions = sessionsByDay[key] ?? []
                if !daySessions.isEmpty {
                    Divider()
                    ForEach(daySessions, id: \.id) { session in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(hex: dayColors[session.sessionType] ?? "6B7280"))
                                .frame(width: 8, height: 8)
                            Text(session.sessionType)
                                .font(.caption.weight(.bold))
                            Text("\(session.durationMinutes) min")
                                .font(.caption)
                                .foregroundColor(Pulse.textTertiary)
                            Spacer()
                            Text(selected.formatted(.dateTime.day().month()))
                                .font(.caption2)
                                .foregroundColor(Pulse.textTertiary)
                        }
                    }
                }
            }

            // Month summary
            HStack {
                let count = sessionsInDisplayedMonth()
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(Pulse.positive)
                Text("\(count) session\(count == 1 ? "" : "s") this month")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
                Spacer()
            }
        }
        .payaCard(padding: 14)
        .onAppear { reload() }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in reload() }
        .onChange(of: monthOffset) { _, _ in reload() }
    }

    // MARK: - Data

    private func reload() {
        let pid = ActiveProfile.id

        // Sessions in a generous window around the displayed month
        let monthStart = calendar.dateInterval(of: .month, for: displayedMonth)?.start ?? Date()
        let windowStart = calendar.date(byAdding: .day, value: -7, to: monthStart) ?? monthStart
        let windowEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? Date()

        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate {
                $0.profileId == pid && $0.isCompleted == true &&
                $0.date >= windowStart && $0.date <= windowEnd
            }
        )
        let sessions = (try? modelContext.fetch(descriptor)) ?? []

        var grouped: [Date: [TrainingSession]] = [:]
        for s in sessions {
            let key = calendar.startOfDay(for: s.date)
            grouped[key, default: []].append(s)
        }
        sessionsByDay = grouped

        // Day code -> color from current training day configs
        var colors: [String: String] = [:]
        for config in TrainingDayStore.all(context: modelContext) {
            colors[config.code] = config.colorHex
        }
        dayColors = colors
    }

    private func monthDays() -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstDay = interval.start
        let dayCount = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30

        // Leading blanks so day 1 lands on its weekday (Monday-first)
        let weekdayOfFirst = calendar.component(.weekday, from: firstDay)   // 1=Sun...7=Sat
        let leadingBlanks = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<dayCount {
            days.append(calendar.date(byAdding: .day, value: offset, to: firstDay))
        }
        return days
    }

    private func sessionsInDisplayedMonth() -> Int {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return 0 }
        return sessionsByDay
            .filter { $0.key >= interval.start && $0.key < interval.end }
            .reduce(0) { $0 + $1.value.count }
    }
}

struct CalendarDayCell: View {
    let date: Date
    let sessions: [TrainingSession]
    let dayColors: [String: String]
    let isToday: Bool
    let isSelected: Bool
    let isFuture: Bool

    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: date))"
    }

    private var cellColor: Color {
        guard let first = sessions.first else {
            return Pulse.surfaceElevatedFallback
        }
        return Color(hex: dayColors[first.sessionType] ?? "2563EB")
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(sessions.isEmpty
                      ? Pulse.surfaceElevatedFallback
                      : cellColor.opacity(isSelected ? 1.0 : 0.85))
            Text(dayNumber)
                .font(.system(size: 12, weight: sessions.isEmpty ? .regular : .bold))
                .foregroundColor(
                    sessions.isEmpty
                        ? (isFuture ? .secondary.opacity(0.35) : .secondary)
                        : .white
                )
        }
        .frame(height: 38)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday ? Pulse.warning : .clear, lineWidth: 2)
        )
    }
}

// MARK: - Session History V2
// Profile-scoped, resolves names + colors from your ACTUAL training days.

struct SessionHistoryCardV2: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var sessions: [TrainingSession] = []
    @State private var dayMap: [String: (name: String, colorHex: String)] = [:]
    @State private var sessionToEdit: TrainingSession? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Session History")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Tap to edit")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
            }

            if sessions.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2)
                            .foregroundColor(Pulse.textTertiary)
                        Text("No sessions completed yet")
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                ForEach(sessions, id: \.id) { session in
                    Button {
                        sessionToEdit = session
                    } label: {
                        HistoryRowV2(
                            session: session,
                            dayInfo: dayMap[session.sessionType]
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PulsePress())
                    .contextMenu {
                        Button(role: .destructive) {
                            delete(session)
                        } label: {
                            Label("Delete session", systemImage: "trash")
                        }
                    }
                    if session.id != sessions.last?.id {
                        Divider()
                    }
                }
            }
        }
        .payaCard(padding: 16)
        .sheet(item: $sessionToEdit) { session in
            SessionEditView(session: session)
        }
        .onAppear { reload() }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in reload() }
    }

    private func reload() {
        let pid = ActiveProfile.id
        var descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.profileId == pid && $0.isCompleted == true },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 15
        sessions = (try? modelContext.fetch(descriptor)) ?? []

        var map: [String: (String, String)] = [:]
        for config in TrainingDayStore.all(context: modelContext) {
            map[config.code] = (config.name, config.colorHex)
        }
        dayMap = map
    }

    private func delete(_ session: TrainingSession) {
        modelContext.delete(session)
        try? modelContext.save()
        reload()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

struct HistoryRowV2: View {
    var session: TrainingSession
    var dayInfo: (name: String, colorHex: String)?

    private var color: Color {
        Color(hex: dayInfo?.colorHex ?? "6B7280")
    }

    private var displayName: String {
        session.sourceRaw == "appleFitness" ? session.sessionType : (dayInfo?.name ?? "Session \(session.sessionType)")
    }

    private var totalVolume: Double {
        session.exercises.reduce(0.0) { total, ex in
            total + ex.sets.filter { $0.isCompleted }
                .reduce(0.0) { $0 + ($1.weightKg * Double($1.reps)) }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                if session.sourceRaw == "appleFitness" {
                    Image(systemName: "figure.run")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(color)
                } else {
                    Text(session.sessionType)
                        .font(.caption.weight(.bold))
                        .foregroundColor(color)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Pulse.textPrimary)
                    if session.sourceRaw == "appleFitness" {
                        Text("Apple Fitness")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Pulse.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Pulse.surfaceElevatedFallback)
                            .clipShape(Capsule())
                    }
                }
                Text(session.date.formatted(.dateTime.weekday(.abbreviated).day().month()))
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f kg", totalVolume))
                    .font(.caption.weight(.bold))
                    .foregroundColor(color)
                    .monospacedDigit()
                HStack(spacing: 4) {
                    if session.isFlareDay {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Pulse.warning)
                    }
                    Text("\(session.durationMinutes) min")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                        .monospacedDigit()
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.vertical, 4)
    }
}
