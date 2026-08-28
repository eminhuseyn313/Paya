import SwiftUI

// MARK: - Food Quick Picker Sheet
//
// Presented from the dashboard's "Log food" chip and nudge cards.
// Shows all food-logging methods as large tap targets so the user
// picks how they want to log, then deep-links to the Nutrition tab
// with the right sheet auto-opened.

struct FoodQuickPickerSheet: View {

    let onPick: (AppState.NutritionAction) -> Void

    private let options: [(AppState.NutritionAction, String, String, String)] = [
        (.describe, "mic.fill", "Describe it", "Say what you ate — AI estimates nutrition"),
        (.scan, "barcode.viewfinder", "Scan barcode", "Instant lookup from product database"),
        (.photo, "camera.fill", "Photo estimate", "Take a photo — AI identifies the food"),
        (.search, "magnifyingglass", "Search food", "Browse the food database"),
        (.label, "doc.text.viewfinder", "Scan label", "Read a nutrition facts label"),
        (.manual, "square.and.pencil", "Manual entry", "Enter calories & macros directly"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                ForEach(options, id: \.1) { action, icon, title, subtitle in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onPick(action)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Pulse.nutrition)
                                .frame(width: 36, height: 36)
                                .background(Pulse.nutrition.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Pulse.textPrimary)
                                Text(subtitle)
                                    .font(.caption2)
                                    .foregroundColor(Pulse.textTertiary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Pulse.textTertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Pulse.surfaceFallback)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .navigationTitle("Log food")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
