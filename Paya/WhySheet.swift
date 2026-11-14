import SwiftUI

// MARK: - "Why this number?"
// Every headline number can explain itself: where it comes from, how fresh it
// is, and how much to trust it. Answers the "is this made up?" question in one tap.

struct WhyItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let rows: [(label: String, text: String)]
    var note: String? = nil
}

struct WhySheet: View {
    let item: WhyItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(item.title)
                        .font(.pulse(size: 13, weight: .bold))
                        .foregroundColor(Pulse.textSecondary)
                        .textCase(.uppercase)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.pulse(size: 22))
                            .foregroundColor(Pulse.textTertiary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close")
                }

                Text(item.value)
                    .font(.pulse(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(Pulse.textPrimary)

                ForEach(Array(item.rows.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.label)
                            .font(.pulse(size: 12, weight: .bold))
                            .foregroundColor(Pulse.hydration)
                        Text(row.text)
                            .font(.pulse(size: 15))
                            .foregroundColor(Pulse.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let note = item.note {
                    Text(note)
                        .font(.pulse(size: 12))
                        .foregroundColor(Pulse.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
        }
        .background(Pulse.canvasFallback.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
