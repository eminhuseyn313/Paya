import Foundation
import SwiftData

// MARK: - Personal Health Timeline Engine
// Assembles one day into 24 hour blocks, each carrying whatever's known for
// that hour — calendar events, weather, steps, heart rate, meals, water,
// sleep — so the Personal Health Management view can render a single
// connected picture instead of five separate disconnected screens.

struct HourBlock: Identifiable {
    var id: Int { hour }
    let hour: Int
    var weather: HourlyWeather?
    var events: [CalendarEventSummary] = []
    var steps: Int = 0
    var avgHR: Double?
    var meals: [MealLog] = []
    var waterMl: Int = 0
    var isAsleep: Bool = false
    var noiseDb: Double?

    /// WHO/NIOSH-referenced ambient-noise bands (not app-invented): under
    /// ~70dB is generally considered safe for prolonged exposure, 70-85dB
    /// is a moderate/loud environment, and above 85dB is where sustained
    /// exposure carries a recognized hearing-risk profile.
    var isLoudHour: Bool { (noiseDb ?? 0) >= 70 }

    var hasAnyData: Bool {
        weather != nil || !events.isEmpty || steps > 0 || avgHR != nil || !meals.isEmpty || waterMl > 0 || isAsleep || noiseDb != nil
    }

    var label: String {
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "AM" : "PM"
        return "\(h12)\(suffix)"
    }
}

struct DayOverview {
    let hours: [HourBlock]
    let totalSteps: Int
    let meetingMinutes: Int
    let sleepHours: Double?
    let mealCount: Int
    let totalWaterMl: Int
    let sunnyHoursWalked: Int    // hours that were both sunny AND had meaningful steps
    let timeInDaylightMin: Int   // real ambient-light-sensor reading (Watch), not inferred from weather+steps
    let sleepOnsetHour: Double?  // fractional hour of first sleep period that night (23.5 = 11:30pm; past midnight wraps past 24)
    let checkIn: DailyCheckIn?
    let symptomLogs: [SymptomLog]
    let insights: [String]
}

struct WeekDaySummary: Identifiable {
    var id: Date { date }
    let date: Date
    let totalSteps: Int
    let sleepHours: Double?
    let mealCount: Int
    let eventCount: Int
    let sunnyHours: Int
    let checkInEnergy: Int?
    let sleepOnsetHour: Double?

    var weekdayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        return f.string(from: date)
    }
}

enum PersonalHealthTimelineEngine {

    private static let meaningfulStepsThreshold = 200

    @MainActor
    static func build(for date: Date, context: ModelContext, progress: LoadProgress? = nil) async -> DayOverview {
        let today = date
        let pid = ActiveProfile.id
        let calendar = Calendar.current
        let isPastDay = !calendar.isDateInToday(date)

        let hrRangeEnd = isPastDay
            ? (calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today)) ?? today)
            : Date.now

        async let hourlySteps = HealthKitManager.shared.fetchHourlySteps(for: today)
        async let hrSamples = HealthKitManager.shared.fetchHeartRateSamples(since: calendar.startOfDay(for: today), until: hrRangeEnd)
        async let sleepPeriods = HealthKitManager.shared.fetchSleepPeriods(for: today)
        async let weather = WeatherService.shared.hourlyWeather(for: today)
        async let hourlyNoise = HealthKitManager.shared.fetchHourlyEnvironmentalNoise(for: today)
        async let daylightByDay = HealthKitManager.shared.fetchDailyTimeInDaylight(daysBack: 1)

        let events = CalendarService.shared.events(on: today)

        let nDescriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.profileId == pid }
        )
        let todaysMeals = ((try? context.fetch(nDescriptor)) ?? [])
            .first { calendar.isDate($0.date, inSameDayAs: today) }?.meals ?? []

        let startOfDay = calendar.startOfDay(for: today)
        let waterDescriptor = FetchDescriptor<WaterEventLog>(
            predicate: #Predicate<WaterEventLog> { $0.date >= startOfDay && $0.profileId == pid }
        )
        let waterEvents = (try? context.fetch(waterDescriptor)) ?? []

        let checkInDescriptor = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate<DailyCheckIn> { $0.date >= startOfDay && $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let checkIn = (try? context.fetch(checkInDescriptor))?.first

        let symptomDescriptor = FetchDescriptor<SymptomLog>(
            predicate: #Predicate<SymptomLog> { $0.date >= startOfDay && $0.profileId == pid },
            sortBy: [SortDescriptor(\.onsetDate)]
        )
        let symptomLogs = (try? context.fetch(symptomDescriptor)) ?? []

        let steps = await hourlySteps
        progress?.step("Steps")
        let hr = await hrSamples
        progress?.step("Heart rate")
        let sleep = await sleepPeriods
        progress?.step("Sleep")
        let weatherByHour = await weather
        progress?.step("Weather")
        let noise = await hourlyNoise
        progress?.step("Noise levels")
        let daylightMap = await daylightByDay
        progress?.step("Daylight")
        let timeInDaylightMin = Int(daylightMap[calendar.startOfDay(for: today)] ?? 0)

        var blocks: [HourBlock] = (0..<24).map { HourBlock(hour: $0) }

        for i in blocks.indices {
            let hour = blocks[i].hour
            blocks[i].steps = steps[hour] ?? 0
            blocks[i].weather = weatherByHour?.first { $0.hour == hour }
            blocks[i].noiseDb = noise[hour]

            let hourHRs = hr.filter { calendar.component(.hour, from: $0.date) == hour }
            if !hourHRs.isEmpty {
                blocks[i].avgHR = hourHRs.map(\.bpm).reduce(0, +) / Double(hourHRs.count)
            }

            blocks[i].events = events.filter { event in
                guard let hourStart = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today),
                      let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) else { return false }
                return event.startDate < hourEnd && event.endDate > hourStart
            }

            blocks[i].meals = todaysMeals.filter { calendar.component(.hour, from: $0.loggedAt) == hour }

            blocks[i].waterMl = waterEvents
                .filter { calendar.component(.hour, from: $0.date) == hour }
                .reduce(0) { $0 + $1.ml }

            if let hourStart = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today),
               let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) {
                blocks[i].isAsleep = sleep.contains { $0.start < hourEnd && $0.end > hourStart }
            }
        }

        let totalSteps = steps.values.reduce(0, +)
        let sleepHours = sleep.isEmpty ? nil : sleep.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) / 3600.0 }
        let totalWater = waterEvents.reduce(0) { $0 + $1.ml }
        let sunnyWalked = blocks.filter { ($0.weather?.isSunny ?? false) && $0.steps >= meaningfulStepsThreshold }.count
        let meetingMinutes = mergedMeetingMinutes(events.filter { !$0.isAllDay })

        // Bedtime, expressed as a continuous fractional hour past noon so a
        // 12:30am onset (0.5) and an 11:30pm onset (23.5) — only an hour
        // apart in reality — don't read as maximally far apart after
        // midnight wraps to 0. Sleep-timing CONSISTENCY (not just duration)
        // independently predicts recovery and metabolic health (Cheng et
        // al. 2021's Sleep Regularity Index research), which duration alone
        // can't capture — someone can average 8h/night while going to bed
        // at wildly different times.
        let earliestSleepStart = sleep.map(\.start).min()
        let sleepOnsetHour: Double? = earliestSleepStart.map { start in
            let comps = calendar.dateComponents([.hour, .minute], from: start)
            var h = Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0
            if h < 12 { h += 24 }
            return h
        }

        let allSymptomTags: [String] = {
            var tags = checkIn?.symptomTags ?? []
            for log in symptomLogs where !tags.contains(log.tag) {
                tags.append(log.tag)
            }
            return tags
        }()
        let insights = buildInsights(blocks: blocks, sunnyWalked: sunnyWalked, checkIn: checkIn, symptomTags: allSymptomTags, symptomLogs: symptomLogs)

        return DayOverview(
            hours: blocks,
            totalSteps: totalSteps,
            meetingMinutes: meetingMinutes,
            sleepHours: sleepHours,
            mealCount: todaysMeals.count,
            totalWaterMl: totalWater,
            sunnyHoursWalked: sunnyWalked,
            timeInDaylightMin: timeInDaylightMin,
            sleepOnsetHour: sleepOnsetHour,
            checkIn: checkIn,
            symptomLogs: symptomLogs,
            insights: insights
        )
    }

    /// Rolls the last 7 days into daily totals — real patterns (sleep vs.
    /// energy, sunny hours vs. steps) only surface once you can see several
    /// days side by side, which a single day's hour-by-hour view can't show.
    @MainActor
    static func buildWeekSummary(context: ModelContext, progress: LoadProgress? = nil) async -> [WeekDaySummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let dates = (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed()
        progress?.reset(total: 7)

        // Each day's build() does its own weather/HealthKit network calls —
        // running the 7 days sequentially meant paying for 7 round-trips to
        // the weather API back to back (6 of them hitting the slower
        // archive endpoint), which is what made this page take minutes to
        // open. Building all 7 days concurrently instead: total time is
        // roughly the slowest single day, not the sum of all seven. (A
        // separate bug — WeatherService's shared location request getting
        // stomped by concurrent callers — was the other, bigger reason this
        // page could hang; see WeatherService.currentLocation.)
        let overviews = await withTaskGroup(of: (Date, DayOverview).self) { group in
            for date in dates {
                group.addTask {
                    (date, await build(for: date, context: context))
                }
            }
            var collected: [(Date, DayOverview)] = []
            for await pair in group {
                progress?.step(DateFormatter.localizedString(from: pair.0, dateStyle: .medium, timeStyle: .none))
                collected.append(pair)
            }
            return collected
        }

        return overviews
            .sorted { $0.0 < $1.0 }
            .map { date, overview in
                let eventCount = Set(overview.hours.flatMap { $0.events.map(\.id) }).count
                let sunnyHours = overview.hours.filter { $0.weather?.isSunny ?? false }.count
                return WeekDaySummary(
                    date: date,
                    totalSteps: overview.totalSteps,
                    sleepHours: overview.sleepHours,
                    mealCount: overview.mealCount,
                    eventCount: eventCount,
                    sunnyHours: sunnyHours,
                    checkInEnergy: overview.checkIn?.energy,
                    sleepOnsetHour: overview.sleepOnsetHour
                )
            }
    }

    static func buildWeekInsights(_ summaries: [WeekDaySummary]) -> [String] {
        var notes: [String] = []

        let withEnergy = summaries.filter { $0.checkInEnergy != nil && $0.sleepHours != nil }
        let higherEnergyNights = withEnergy.filter { ($0.checkInEnergy ?? 0) >= 3 }.compactMap(\.sleepHours)
        let lowerEnergyNights = withEnergy.filter { ($0.checkInEnergy ?? 0) < 3 }.compactMap(\.sleepHours)
        if higherEnergyNights.count >= 2 && lowerEnergyNights.count >= 2 {
            let hiAvg = higherEnergyNights.reduce(0, +) / Double(higherEnergyNights.count)
            let loAvg = lowerEnergyNights.reduce(0, +) / Double(lowerEnergyNights.count)
            if hiAvg - loAvg >= 0.5 {
                notes.append("On days you felt more energized, you'd slept \(String(format: "%.1f", hiAvg))h the night before, vs \(String(format: "%.1f", loAvg))h on low-energy days.")
            }
        }

        let onsets = summaries.compactMap(\.sleepOnsetHour)
        if onsets.count >= 4 {
            let mean = onsets.reduce(0, +) / Double(onsets.count)
            let variance = onsets.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(onsets.count)
            let stdDevMinutes = sqrt(variance) * 60
            let clockLabel = clockLabel(forFractionalHour: mean)
            if stdDevMinutes >= 60 {
                notes.append("Your bedtime swung by about \(Int(stdDevMinutes)) minutes night to night this week (averaging \(clockLabel)) — sleep-timing consistency, not just total hours, is its own predictor of recovery.")
            } else if stdDevMinutes <= 30 {
                notes.append("Your bedtime was consistent this week (around \(clockLabel), ±\(Int(stdDevMinutes))min) — that regularity itself supports recovery, independent of total sleep hours.")
            }
        }

        let sunnyDays = summaries.filter { $0.sunnyHours >= 3 }
        let overcastDays = summaries.filter { $0.sunnyHours < 3 }
        if sunnyDays.count >= 2 && overcastDays.count >= 2 {
            let sunnyAvgSteps = sunnyDays.map(\.totalSteps).reduce(0, +) / sunnyDays.count
            let overcastAvgSteps = overcastDays.map(\.totalSteps).reduce(0, +) / overcastDays.count
            if sunnyAvgSteps > overcastAvgSteps + 500 {
                notes.append("You averaged \(sunnyAvgSteps) steps on sunnier days vs \(overcastAvgSteps) on overcast ones this week.")
            }
        }

        let busyDays = summaries.filter { $0.eventCount >= 4 }
        if !busyDays.isEmpty {
            let busyAvgSteps = busyDays.map(\.totalSteps).reduce(0, +) / busyDays.count
            let quietDays = summaries.filter { $0.eventCount < 4 }
            if !quietDays.isEmpty {
                let quietAvgSteps = quietDays.map(\.totalSteps).reduce(0, +) / quietDays.count
                if quietAvgSteps > busyAvgSteps + 500 {
                    notes.append("Meeting-heavy days (4+ events) averaged \(busyAvgSteps) steps vs \(quietAvgSteps) on lighter days — worth a walking break between calls.")
                }
            }
        }

        let sleepValues = summaries.compactMap(\.sleepHours)
        if sleepValues.count >= 4 {
            let avg = sleepValues.reduce(0, +) / Double(sleepValues.count)
            if avg < 7.0 {
                notes.append("You averaged \(String(format: "%.1f", avg))h of sleep this week — below the 7-9h range most adults need to recover (National Sleep Foundation).")
            }
        }

        if notes.isEmpty {
            notes.append("Log a few more check-ins and this week's patterns will get clearer.")
        }
        return notes
    }

    /// Formats a fractional hour (which may run past 24 to represent a
    /// past-midnight bedtime continuing the prior evening) as a clock time.
    private static func clockLabel(forFractionalHour hour: Double) -> String {
        let wrapped = hour.truncatingRemainder(dividingBy: 24)
        let h24 = Int(wrapped)
        let minute = Int((wrapped - Double(h24)) * 60)
        let period = h24 < 12 ? "AM" : "PM"
        let h12 = h24 % 12 == 0 ? 12 : h24 % 12
        return String(format: "%d:%02d%@", h12, minute, period)
    }

    /// Scans the REMAINING hours of today for the best still-available
    /// walk window: sunny, no calendar conflict, hasn't happened yet.
    /// Context-triggered prompts (a specific window you can act on right
    /// now) drive behavior more reliably than retrospective stats alone —
    /// the Fogg Behavior Model's "prompt at the moment of high motivation/
    /// ability" principle — so this looks forward instead of only summarizing
    /// what already happened today.
    static func suggestedWalkWindow(blocks: [HourBlock], now: Date = .now) -> String? {
        let calendar = Calendar.current
        guard calendar.isDateInToday(now) else { return nil }
        let currentHour = calendar.component(.hour, from: now)

        let candidate = blocks.first { block in
            block.hour > currentHour &&
            block.hour < 21 &&
            (block.weather?.isSunny ?? false) &&
            block.events.isEmpty
        }
        guard let candidate else { return nil }
        return "\(candidate.label) looks open and sunny — a good window for a walk if your calendar holds."
    }

    /// Total time actually in meetings, merging overlapping/back-to-back
    /// events into a union of intervals first — naive summing of each
    /// event's duration would double-count concurrent meetings and
    /// overstate the real total.
    private static func mergedMeetingMinutes(_ events: [CalendarEventSummary]) -> Int {
        guard !events.isEmpty else { return 0 }
        let sorted = events.sorted { $0.startDate < $1.startDate }
        var merged: [(start: Date, end: Date)] = []
        for event in sorted {
            if let last = merged.last, event.startDate <= last.end {
                merged[merged.count - 1].end = max(last.end, event.endDate)
            } else {
                merged.append((event.startDate, event.endDate))
            }
        }
        let totalSeconds = merged.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
        return Int(totalSeconds / 60)
    }

    private static func buildInsights(blocks: [HourBlock], sunnyWalked: Int, checkIn: DailyCheckIn?, symptomTags: [String] = [], symptomLogs: [SymptomLog] = []) -> [String] {
        var notes: [String] = []

        if !symptomTags.isEmpty {
            let symptomInsights = buildSymptomInsights(
                tags: symptomTags, blocks: blocks,
                checkIn: checkIn ?? DailyCheckIn(soreness: 3, energy: 2),
                symptomLogs: symptomLogs
            )
            notes.append(contentsOf: symptomInsights)
        }

        let sunnyHours = blocks.filter { $0.weather?.isSunny ?? false }.count
        if sunnyHours > 0 {
            if sunnyWalked == 0 {
                notes.append("It was sunny for \(sunnyHours)h today and you didn't walk much during any of them — an easy window to add a short walk.")
            } else {
                notes.append("You moved during \(sunnyWalked) of \(sunnyHours) sunny hours today.")
            }
        }

        let busiestCalendarHour = blocks.max { $0.events.count < $1.events.count }
        if let busiest = busiestCalendarHour, busiest.events.count >= 2, let hr = busiest.avgHR, hr > 90 {
            notes.append("Your heart rate ran higher (~\(Int(hr))bpm) during your busiest calendar hour (\(busiest.label)) — worth noticing if back-to-back meetings are a stress pattern.")
        }

        let mealHours = blocks.filter { !$0.meals.isEmpty }.map(\.hour).sorted()
        if let last = mealHours.last, last >= 21 {
            notes.append("Your last meal was logged at \(blocks[last].label) — late eating can push sleep onset later.")
        }

        if let checkIn, checkIn.energy == 1, !checkIn.symptomTags.contains("headache") {
            notes.append("You logged feeling drained this morning — cross-reference against last night's sleep and today's meal timing above.")
        }

        let loudHours = blocks.filter(\.isLoudHour)
        if loudHours.count >= 3 {
            let sleepHour = blocks.first { $0.isAsleep }?.hour
            let loudNearSleep = sleepHour.map { sh in loudHours.contains { abs($0.hour - sh) <= 2 } } ?? false
            if loudNearSleep {
                notes.append("\(loudHours.count)h of elevated ambient noise today (70dB+), including hours close to when you fell asleep — worth checking if that's affecting sleep onset.")
            } else {
                notes.append("\(loudHours.count)h of elevated ambient noise today (70dB+) — \(loudHours.map(\.label).prefix(3).joined(separator: ", ")).")
            }
        }

        if notes.isEmpty {
            notes.append("Nothing stands out today — log a few more days to start seeing real patterns.")
        }
        return notes
    }

    private static let symptomLabels: [String: String] = [
        "headache": "Headache", "feeling_unwell": "Feeling unwell",
        "shoulder_pain": "Shoulder pain", "wrist_pain": "Wrist pain",
        "back_tight": "Back tightness", "knee_pain": "Knee pain",
        "digestive": "Stomach issues", "dehydrated": "Dehydration",
        "motivation_low": "Low motivation", "travel": "Traveling",
    ]

    private static func buildSymptomInsights(tags: [String], blocks: [HourBlock], checkIn: DailyCheckIn, symptomLogs: [SymptomLog] = []) -> [String] {
        var notes: [String] = []
        let tagNames = tags.compactMap { symptomLabels[$0] }
        let label = tagNames.isEmpty ? tags.joined(separator: ", ") : tagNames.joined(separator: ", ")

        let sleepBlocks = blocks.filter(\.isAsleep)
        let sleepHours = sleepBlocks.isEmpty ? nil : Double(sleepBlocks.count)
        let totalWater = blocks.reduce(0) { $0 + $1.waterMl }

        let earliestOnset = symptomLogs.min(by: { $0.onsetDate < $1.onsetDate })
        let onsetHour = earliestOnset.map { Calendar.current.component(.hour, from: $0.onsetDate) }

        if let onset = earliestOnset, let hour = onsetHour {
            let timeStr = onset.onsetDate.formatted(date: .omitted, time: .shortened)
            let symptomName = symptomLabels[onset.tag] ?? onset.tag
            notes.append("You logged \(symptomName.lowercased()) starting at \(timeStr) — scanning what happened in the hours before \(blocks[min(hour, 23)].label):")
        } else {
            notes.append("You flagged \(label) today — here's what your data shows that could be related:")
        }

        if tags.contains("headache") || tags.contains("feeling_unwell") || tags.contains("nausea") || tags.contains("dizziness") || tags.contains("fatigue") || tags.contains("brain_fog") || tags.contains("anxiety") || tags.contains("eye_strain") {
            var triggers: [String] = []
            let scanEnd = onsetHour ?? min(Calendar.current.component(.hour, from: .now), 23)
            let beforeOnset = onsetHour != nil ? " before onset" : ""

            // -- Overnight / daily factors --
            if let sleep = sleepHours, sleep < 7 {
                triggers.append("Short sleep (~\(Int(sleep))h) — under 7h raises headache risk (Boardman et al. 2020)")
            }

            // -- Hour-by-hour timeline scan --
            // Water gaps: find the longest stretch without water, prioritizing gaps before onset
            let waterHours = blocks.enumerated().filter { $0.element.waterMl > 0 && $0.offset <= scanEnd }.map(\.offset)
            let checkpoints = [0] + waterHours + [scanEnd]
            var longestWaterGap: (startHour: Int, endHour: Int, hours: Int) = (0, 0, 0)
            for i in 1..<checkpoints.count {
                let gap = checkpoints[i] - checkpoints[i - 1]
                if gap > longestWaterGap.hours {
                    longestWaterGap = (checkpoints[i - 1], checkpoints[i], gap)
                }
            }
            if longestWaterGap.hours >= 3 {
                triggers.append("\(longestWaterGap.hours)h without water (\(blocks[longestWaterGap.startHour].label)–\(blocks[min(longestWaterGap.endHour, 23)].label))\(beforeOnset) — dehydration is the most common modifiable headache trigger (Blau et al. 2004)")
            } else if totalWater < 500 {
                triggers.append("Very low water intake so far (\(totalWater)ml)")
            }

            // Meal gaps: find longest stretch without food, focused on pre-onset window
            let mealHourIndices = blocks.enumerated().filter { !$0.element.meals.isEmpty && $0.offset <= scanEnd }.map(\.offset)
            if mealHourIndices.isEmpty {
                let mealNote = onsetHour != nil ? "No meals logged before symptom onset" : "No meals logged today"
                triggers.append("\(mealNote) — fasting drops blood glucose, a direct headache trigger")
            } else {
                let wakeHour = sleepBlocks.last.map { $0.hour + 1 } ?? 7
                let mealCheckpoints = [wakeHour] + mealHourIndices
                var longestMealGap: (startHour: Int, endHour: Int, hours: Int) = (0, 0, 0)
                for i in 1..<mealCheckpoints.count {
                    let gap = mealCheckpoints[i] - mealCheckpoints[i - 1]
                    if gap > longestMealGap.hours {
                        longestMealGap = (mealCheckpoints[i - 1], mealCheckpoints[i], gap)
                    }
                }
                let trailingGap = scanEnd - (mealHourIndices.last ?? wakeHour)
                if trailingGap > longestMealGap.hours {
                    longestMealGap = (mealHourIndices.last ?? wakeHour, scanEnd, trailingGap)
                }
                if longestMealGap.hours >= 4 {
                    triggers.append("\(longestMealGap.hours)h gap between meals (\(blocks[longestMealGap.startHour].label)–\(blocks[min(longestMealGap.endHour, 23)].label))\(beforeOnset) — prolonged fasting triggers tension headaches via blood sugar dips")
                }
            }

            // HR spikes: find the peak hour before onset
            let hrBlocks = blocks.filter { $0.avgHR != nil && $0.hour <= scanEnd }
            if hrBlocks.count >= 4 {
                let baseline = hrBlocks.compactMap(\.avgHR).reduce(0, +) / Double(hrBlocks.count)
                let peakBlock = hrBlocks.max { ($0.avgHR ?? 0) < ($1.avgHR ?? 0) }
                if let peak = peakBlock, let peakHR = peak.avgHR, peakHR - baseline >= 10 {
                    let context = peak.events.isEmpty ? "" : " (during \(peak.events.first?.title ?? "an event"))"
                    triggers.append("HR spiked to ~\(Int(peakHR))bpm at \(peak.label)\(context) — \(Int(peakHR - baseline))bpm above your day's average. Stress-driven HR elevation is a recognized tension headache pathway")
                }
            }

            // Calendar stress blocks: find consecutive busy hours before onset
            let preOnsetBlocks = onsetHour != nil ? Array(blocks.prefix(scanEnd + 1)) : blocks
            let busyStretch = findBusiestStretch(preOnsetBlocks)
            if let stretch = busyStretch, stretch.eventCount >= 3 {
                triggers.append("\(stretch.eventCount) events packed into \(blocks[stretch.startHour].label)–\(blocks[stretch.endHour].label)\(beforeOnset) — sustained screen time and cognitive load compound headache risk")
            }

            // Noise: flag loud hours with timestamps
            let loudHours = blocks.filter(\.isLoudHour)
            if !loudHours.isEmpty {
                let loudLabels = loudHours.prefix(3).map(\.label).joined(separator: ", ")
                triggers.append("\(loudHours.count)h of elevated noise (70dB+) at \(loudLabels) — sustained noise raises cortisol and muscle tension")
            }

            // Weather: check for pressure/temperature changes
            let weatherBlocks = blocks.filter { $0.weather != nil }
            if let morning = weatherBlocks.first(where: { $0.hour >= 6 && $0.hour <= 9 })?.weather,
               let afternoon = weatherBlocks.first(where: { $0.hour >= 12 && $0.hour <= 15 })?.weather {
                let tempDelta = abs(afternoon.temperatureC - morning.temperatureC)
                if tempDelta >= 8 {
                    triggers.append("Temperature swung \(Int(tempDelta))°C between morning and afternoon — large thermal shifts are a known migraine trigger (Hoffmann et al. 2015)")
                }
            }

            if triggers.isEmpty {
                notes.append("No obvious triggers found in today's data — could be cumulative factors from prior days, or something not tracked here (barometric pressure, caffeine withdrawal, screen brightness).")
            } else {
                for t in triggers { notes.append(t) }
            }
        }

        if tags.contains("digestive") {
            let mealHours = blocks.filter { !$0.meals.isEmpty }.map(\.hour).sorted()
            if let first = mealHours.first, let last = mealHours.last, mealHours.count >= 2 {
                let spread = last - first
                if spread <= 4 {
                    notes.append("Meals were clustered within \(spread)h (\(blocks[first].label)–\(blocks[last].label)) — spacing them more evenly can reduce GI load.")
                }
            }
            // Check for large meal followed by HR elevation
            for mealHour in mealHours {
                let postMealHR = blocks.filter { $0.hour > mealHour && $0.hour <= mealHour + 2 }.compactMap(\.avgHR)
                let preMealHR = blocks.filter { $0.hour >= mealHour - 2 && $0.hour < mealHour }.compactMap(\.avgHR)
                if let postAvg = postMealHR.isEmpty ? nil : postMealHR.reduce(0, +) / Double(postMealHR.count),
                   let preAvg = preMealHR.isEmpty ? nil : preMealHR.reduce(0, +) / Double(preMealHR.count),
                   postAvg - preAvg >= 8 {
                    notes.append("HR rose ~\(Int(postAvg - preAvg))bpm in the 2h after your \(blocks[mealHour].label) meal — could indicate a food that's harder to digest (Westerterp 2004)")
                    break
                }
            }
        }

        if tags.contains("dehydrated") {
            notes.append("Water logged so far: \(totalWater)ml. Aim for at least 2L across the day, adjusted up for activity and heat.")
        }

        if tags.contains("motivation_low") {
            if let sleep = sleepHours, sleep < 6 {
                notes.append("Only ~\(Int(sleep))h of sleep — motivation tracks closely with sleep quality (Pilcher & Huffcutt 1996 meta-analysis).")
            }
            if checkIn.soreness >= 4 {
                notes.append("High soreness (\(checkIn.soreness)/5) — accumulated fatigue can suppress motivation. Consider a lighter session or active recovery.")
            }
        }

        if tags.contains("shoulder_pain") || tags.contains("back_tight") || tags.contains("wrist_pain") || tags.contains("knee_pain") {
            let painLabel = tags.compactMap { symptomLabels[$0] }.first ?? "pain"
            if checkIn.soreness >= 4 {
                notes.append("Soreness at \(checkIn.soreness)/5 alongside \(painLabel.lowercased()) — could be DOMS from recent training or cumulative load.")
            }
            if let sleep = sleepHours, sleep < 6 {
                notes.append("Short sleep (~\(Int(sleep))h) impairs tissue repair — recovery quality drops significantly below 7h (Dattilo et al. 2011)")
            }
        }

        return notes
    }

    private static func findBusiestStretch(_ blocks: [HourBlock]) -> (startHour: Int, endHour: Int, eventCount: Int)? {
        var best: (startHour: Int, endHour: Int, eventCount: Int)? = nil
        for windowSize in [2, 3, 4] {
            for start in 0..<(24 - windowSize) {
                let count = (start..<(start + windowSize)).reduce(0) { $0 + blocks[$1].events.count }
                if count > (best?.eventCount ?? 0) {
                    best = (start, start + windowSize, count)
                }
            }
        }
        return best
    }
}
