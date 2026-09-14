import SwiftUI
import SwiftData

// MARK: - Trend Journal
//
// DailyNarrativeEngine only ever showed today's story. This is the
// retrospective view — a chronological log of each day's headline, so a
// pattern spanning weeks (a stress-load climb that broke, a run of good
// weeks) is visible as a sequence instead of disappearing the moment the
// day ends.

struct TrendJournalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var entries: [NarrativeHistoryEntry] = []

    private var groupedByWeek: [(weekStart: Date, entries: [NarrativeHistoryEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: entry.date)) ?? entry.date
        }
        return grouped.keys.sorted(by: >).compactMap { key in
            guard let entries = grouped[key] else { return nil }
            return (key, entries.sorted { $0.date > $1.date })
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(groupedByWeek, id: \.weekStart) { group in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(weekLabel(group.weekStart))
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(Pulse.textTertiary)
                                        .textCase(.uppercase)
                                        .padding(.horizontal, 2)

                                    VStack(spacing: 0) {
                                        ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                                            journalRow(entry)
                                            if index < group.entries.count - 1 {
                                                Divider().padding(.leading, 44)
                                            }
                                        }
                                    }
                                    .payaCard(padding: 4)
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Pulse.canvasFallback.ignoresSafeArea())
            .navigationTitle("Trend Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            entries = NarrativeHistoryStore.recent(days: 60, context: modelContext)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "book.pages")
                .font(.system(size: 40))
                .foregroundColor(Pulse.textTertiary)
            Text("No entries yet")
                .font(.headline)
            Text("Each day's top story gets logged here automatically — check back after a few days to see the pattern.")
                .font(.caption)
                .foregroundColor(Pulse.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Spacer()
        }
    }

    private func journalRow(_ entry: NarrativeHistoryEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(hex: entry.colorHex).opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: entry.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: entry.colorHex))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.date.formatted(.dateTime.weekday(.abbreviated).day()))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Pulse.textTertiary)
                    Text(entry.source)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(hex: entry.colorHex))
                }
                Text(entry.headline)
                    .font(.system(size: 12.5))
                    .foregroundColor(Pulse.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
    }

    private func weekLabel(_ weekStart: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(weekStart, equalTo: .now, toGranularity: .weekOfYear) {
            return "This week"
        }
        if let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: .now),
           calendar.isDate(weekStart, equalTo: lastWeek, toGranularity: .weekOfYear) {
            return "Last week"
        }
        return "Week of \(weekStart.formatted(.dateTime.month(.abbreviated).day()))"
    }
}
