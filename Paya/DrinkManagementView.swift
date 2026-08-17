import SwiftUI
import SwiftData
import Charts

struct DrinkManagementView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var waterMl: Int = 0
    @State private var caffeineMg: Double = 0
    @State private var drinkCalories: Double = 0
    @State private var drinkSugar: Double = 0
    @State private var selectedDrink: DrinkType = .water
    @State private var customMl: String = ""
    @State private var todayEvents: [WaterEventLog] = []
    @State private var weekData: [(date: Date, ml: Int)] = []

    private var progress: Double {
        min(1.0, Double(waterMl) / Double(WaterStore.dailyTargetMl))
    }

    private var targetL: String {
        String(format: "%.1fL", Double(WaterStore.dailyTargetMl) / 1000.0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    progressHeader
                    quickAddSection
                    caffeineCard
                    todayTimelineCard
                    weekChartCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .navigationTitle("Drinks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { reload() }
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Pulse.recovery.opacity(0.12), lineWidth: 12)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Pulse.recovery, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: progress)
                VStack(spacing: 2) {
                    HeroNumberText(
                        value: String(format: "%.1f", Double(waterMl) / 1000.0),
                        size: 28,
                        color: Pulse.recovery
                    )
                    Text("of \(targetL)")
                        .font(.caption2)
                        .foregroundColor(Pulse.textTertiary)
                }
            }

            if progress >= 1.0 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Pulse.positive)
                    Text("Daily target reached")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Pulse.positive)
                }
            } else {
                let remaining = max(0, WaterStore.dailyTargetMl - waterMl)
                Text("\(remaining)ml remaining")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .payaCard(padding: 20)
    }

    // MARK: - Quick Add

    private var drinkColor: Color { Color(hex: selectedDrink.colorHex) }

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ADD DRINK")
                .font(.caption.weight(.bold))
                .foregroundColor(Pulse.textTertiary)

            // Drink type selector — scrollable grid
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(DrinkType.allCases) { type in
                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                selectedDrink = type
                            }
                        } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(selectedDrink == type
                                              ? Color(hex: type.colorHex).opacity(0.18)
                                              : Pulse.surfaceElevatedFallback)
                                        .frame(width: 44, height: 44)
                                    Image(systemName: type.icon)
                                        .font(.system(size: 15))
                                        .foregroundColor(selectedDrink == type ? Color(hex: type.colorHex) : .secondary)
                                }
                                Text(type.displayName)
                                    .font(.system(size: 9, weight: selectedDrink == type ? .bold : .medium))
                                    .foregroundColor(selectedDrink == type ? .primary : .secondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 56)
                        }
                        .buttonStyle(PulsePress())
                    }
                }
                .padding(.horizontal, 2)
            }

            // Component breakdown for selected drink
            drinkComponentCard

            // Preset amounts
            HStack(spacing: 8) {
                ForEach(selectedDrink == .espresso ? [30, 60, 90] : [100, 200, 250, 330, 500], id: \.self) { amount in
                    Button { add(amount) } label: {
                        Text(selectedDrink == .espresso ? "\(amount)ml" : "\(amount)ml")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(drinkColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(drinkColor.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PulsePress())
                }
            }

            // Custom amount
            HStack(spacing: 8) {
                TextField("Custom ml", text: $customMl)
                    .keyboardType(.numberPad)
                    .font(.subheadline)
                    .padding(10)
                    .background(Pulse.surfaceElevatedFallback)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button {
                    if let ml = Int(customMl), ml > 0 {
                        add(ml)
                        customMl = ""
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(drinkColor)
                }
                .buttonStyle(PulsePress())
                .disabled(Int(customMl) == nil || Int(customMl)! <= 0)
            }
        }
        .payaCard(padding: 14)
    }

    // MARK: - Drink Components

    private var drinkComponentCard: some View {
        let comps = selectedDrink.components
        let cols = comps.count <= 4
            ? [GridItem](repeating: GridItem(.flexible()), count: comps.count)
            : [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: selectedDrink.icon)
                    .font(.system(size: 12))
                    .foregroundColor(drinkColor)
                Text("What's in \(selectedDrink.displayName.lowercased())")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("per 250ml")
                    .font(.system(size: 9))
                    .foregroundColor(Pulse.textTertiary)
            }

            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(comps, id: \.label) { comp in
                    VStack(spacing: 3) {
                        Image(systemName: comp.icon)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: comp.hex))
                        Text(comp.value)
                            .font(.system(size: 10, weight: .bold).monospacedDigit())
                        Text(comp.label)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(Pulse.textTertiary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color(hex: comp.hex).opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(10)
        .background(drinkColor.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Drink Intake Summary

    private var caffeineCard: some View {
        Group {
            if caffeineMg > 0 || drinkCalories > 0 || drinkSugar > 0 {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("TODAY'S DRINK INTAKE")
                            .font(.caption.weight(.bold))
                            .foregroundColor(Pulse.textTertiary)
                        Spacer()
                    }

                    HStack(spacing: 0) {
                        if caffeineMg > 0 {
                            intakeStat(
                                icon: "bolt.fill",
                                value: "\(Int(caffeineMg))mg",
                                label: "Caffeine",
                                hex: caffeineColorHex,
                                badge: caffeineLevel
                            )
                        }
                        if drinkCalories > 0 {
                            intakeStat(
                                icon: "flame.fill",
                                value: "\(Int(drinkCalories))",
                                label: "Drink kcal",
                                hex: "DC2626",
                                badge: nil
                            )
                        }
                        if drinkSugar > 0 {
                            intakeStat(
                                icon: "cube.fill",
                                value: "\(Int(drinkSugar))g",
                                label: "Sugar",
                                hex: sugarLevel > 50 ? "DC2626" : "F59E0B",
                                badge: sugarLevel > 50 ? "High" : nil
                            )
                        }
                    }

                    if caffeineMg > 400 {
                        Text("FDA considers 400mg/day a safe upper bound for most healthy adults. Consider cutting back, especially after 2pm.")
                            .font(.system(size: 10))
                            .foregroundColor(Pulse.critical)
                    } else if caffeineMg > 200 {
                        Text("Moderate intake. Avoid caffeine 6+ hours before bed — Gardiner et al. (J Clin Sleep Med 2023) found it measurably shortens deep sleep even at this level.")
                            .font(.system(size: 10))
                            .foregroundColor(Pulse.textTertiary)
                    }

                    if drinkSugar > 50 {
                        Text("WHO recommends keeping added sugar under 25g/day. Your drink sugar alone is \(Int(drinkSugar))g — consider switching to water or unsweetened alternatives.")
                            .font(.system(size: 10))
                            .foregroundColor(Pulse.warning)
                    }
                }
                .payaCard(padding: 14)
            }
        }
    }

    private func intakeStat(icon: String, value: String, label: String, hex: String, badge: String?) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color(hex: hex).opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: hex))
            }
            Text(value)
                .font(.system(size: 14, weight: .bold).monospacedDigit())
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Pulse.textTertiary)
            if let badge {
                Text(badge)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color(hex: hex))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: hex).opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var sugarLevel: Double { drinkSugar }

    private var caffeineLevel: String {
        switch caffeineMg {
        case ..<100: return "Low"
        case 100..<300: return "Moderate"
        case 300..<400: return "High"
        default: return "Very high"
        }
    }

    private var caffeineColorHex: String {
        switch caffeineMg {
        case ..<100: return "059669"
        case 100..<300: return "F59E0B"
        case 300..<400: return "B45309"
        default: return "DC2626"
        }
    }

    private var caffeineColor: Color { Color(hex: caffeineColorHex) }

    // MARK: - Today Timeline

    private var todayTimelineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TODAY'S LOG")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Pulse.textTertiary)
                Spacer()
                Text("\(todayEvents.count) entries")
                    .font(.caption2)
                    .foregroundColor(Pulse.textTertiary)
            }

            if todayEvents.isEmpty {
                Text("No drinks logged yet today")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ForEach(todayEvents.reversed()) { event in
                    let type = event.drinkType
                    let eventColor = Color(hex: type.colorHex)
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(eventColor.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: type.icon)
                                .font(.system(size: 11))
                                .foregroundColor(eventColor)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(type.displayName)
                                .font(.caption.weight(.semibold))
                            HStack(spacing: 6) {
                                Text(event.date.formatted(date: .omitted, time: .shortened))
                                if type.caffeineMgPer250ml > 0 {
                                    let caffMg = Int(Double(event.ml) / 250.0 * type.caffeineMgPer250ml)
                                    Text("\(caffMg)mg caff")
                                        .foregroundColor(Pulse.warning)
                                }
                                if type.sugarGPer250ml > 0 {
                                    let sugarG = Int(Double(event.ml) / 250.0 * type.sugarGPer250ml)
                                    Text("\(sugarG)g sugar")
                                        .foregroundColor(Pulse.nutrition)
                                }
                            }
                            .font(.system(size: 9))
                            .foregroundColor(Pulse.textTertiary)
                        }
                        Spacer()
                        Text("\(event.ml)ml")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(eventColor)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .payaCard(padding: 14)
    }

    // MARK: - Week Chart

    private var weekChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THIS WEEK")
                .font(.caption.weight(.bold))
                .foregroundColor(Pulse.textTertiary)

            if weekData.isEmpty {
                Text("No data yet")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                Chart(weekData, id: \.date) { day in
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("ml", day.ml)
                    )
                    .foregroundStyle(
                        day.ml >= WaterStore.dailyTargetMl
                            ? Pulse.positive.opacity(0.7)
                            : Pulse.recovery.opacity(0.6)
                    )
                    .cornerRadius(4)

                    RuleMark(y: .value("Target", WaterStore.dailyTargetMl))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { val in
                        AxisValueLabel {
                            if let d = val.as(Date.self) {
                                Text(d.formatted(.dateTime.weekday(.abbreviated)))
                                    .font(.system(size: 9))
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 100)

                HStack(spacing: 12) {
                    legendDot("Target met", color: "059669")
                    legendDot("Below target", color: "0891B2")
                }
            }
        }
        .payaCard(padding: 14)
    }

    private func legendDot(_ label: String, color: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(Color(hex: color)).frame(width: 6, height: 6)
            Text(label).font(.system(size: 9)).foregroundColor(Pulse.textTertiary)
        }
    }

    // MARK: - Actions

    private func add(_ ml: Int) {
        waterMl = WaterStore.addWater(ml, drinkType: selectedDrink, context: modelContext)
        caffeineMg = WaterStore.todayCaffeineMg(context: modelContext)
        drinkCalories = WaterStore.todayDrinkCalories(context: modelContext)
        drinkSugar = WaterStore.todayDrinkSugar(context: modelContext)
        WatchSessionManager.shared.pushWaterTotal(waterMl)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        loadTodayEvents()
    }

    private func reload() {
        waterMl = WaterStore.todayTotal(context: modelContext)
        caffeineMg = WaterStore.todayCaffeineMg(context: modelContext)
        drinkCalories = WaterStore.todayDrinkCalories(context: modelContext)
        drinkSugar = WaterStore.todayDrinkSugar(context: modelContext)
        loadTodayEvents()
        loadWeekData()
    }

    private func loadTodayEvents() {
        let pid = ActiveProfile.id
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<WaterEventLog>(
            predicate: #Predicate<WaterEventLog> { $0.date >= startOfDay && $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        todayEvents = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func loadWeekData() {
        let pid = ActiveProfile.id
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: today) else { return }
        let descriptor = FetchDescriptor<WaterEventLog>(
            predicate: #Predicate<WaterEventLog> { $0.date >= weekAgo && $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        let events = (try? modelContext.fetch(descriptor)) ?? []
        var dayTotals: [Date: Int] = [:]
        for i in 0..<7 {
            if let d = calendar.date(byAdding: .day, value: i, to: weekAgo) {
                dayTotals[calendar.startOfDay(for: d)] = 0
            }
        }
        for event in events {
            let dayStart = calendar.startOfDay(for: event.date)
            dayTotals[dayStart, default: 0] += event.ml
        }
        weekData = dayTotals.sorted { $0.key < $1.key }.map { (date: $0.key, ml: $0.value) }
    }
}
