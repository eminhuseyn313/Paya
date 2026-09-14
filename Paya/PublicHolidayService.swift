import Foundation

// MARK: - Public Holiday Service
//
// Nager.Date (date.nager.at) — free, no API key, public holidays by
// country. Adds context to the trend journal and narrative: "this rough
// week included a holiday" explains a dip in routine (training,
// nutrition consistency, sleep schedule) instead of it just looking like
// an unexplained bad stretch.
//
// Country comes from the device's region setting (Locale.current.region) —
// not GPS, since someone traveling still cares about explaining their
// USUAL routine's disruption relative to their home calendar, and this
// needs no location permission at all. A future pass could offer per-trip
// overrides if that turns out to matter.

enum PublicHolidayService {

    struct Holiday: Decodable {
        let date: String
        let localName: String
        let name: String
    }

    private static var cache: [Holiday] = []
    private static var cachedYear: Int? = nil

    /// Fetches (and caches, once per year) the device region's public
    /// holidays, then returns today's holiday name if today is one.
    static func todaysHolidayName() async -> String? {
        guard let countryCode = Locale.current.region?.identifier else { return nil }
        let year = Calendar.current.component(.year, from: .now)

        if cachedYear != year || cache.isEmpty {
            guard let url = URL(string: "https://date.nager.at/api/v3/PublicHolidays/\(year)/\(countryCode)") else { return nil }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
                cache = (try? JSONDecoder().decode([Holiday].self, from: data)) ?? []
                cachedYear = year
            } catch {
                return nil
            }
        }

        let todayString = DateFormatter.isoDateOnly.string(from: .now)
        return cache.first { $0.date == todayString }?.localName
    }

    /// True if `date` fell within `daysBack` days of a holiday (inclusive of
    /// today) — used by the trend journal to explain a rough stretch rather
    /// than checking one day at a time.
    static func hadRecentHoliday(daysBack: Int = 7) async -> String? {
        guard Locale.current.region?.identifier != nil else { return nil }
        let year = Calendar.current.component(.year, from: .now)
        if cachedYear != year || cache.isEmpty {
            _ = await todaysHolidayName() // populates cache as a side effect
        }
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -daysBack, to: .now) ?? .now
        let formatter = DateFormatter.isoDateOnly
        let recent = cache.first { holiday in
            guard let date = formatter.date(from: holiday.date) else { return false }
            return date >= cutoff && date <= .now
        }
        return recent?.localName
    }
}

private extension DateFormatter {
    static let isoDateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()
}
