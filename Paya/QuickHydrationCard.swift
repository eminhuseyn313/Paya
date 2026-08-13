import SwiftUI
import SwiftData

// MARK: - Quick Hydration Card
//
// Compact, dashboard-friendly water/drink card that solves the
// "water intake is a bad place to find" problem. Always visible
// on the Home tab — one tap to add water, expandable for drinks.
// Full drink management is still in DrinkManagementView.

struct QuickHydrationCard: View {

    var modelContext: ModelContext

    @State private var waterMl: Int = 0
    @State private var expanded: Bool = false
    @State private var selectedDrink: DrinkType = .water
    @State private var showDrinkSheet: Bool = false

    private var progress: Double {
        min(1.0, Double(waterMl) / Double(WaterStore.dailyTargetMl))
    }

    private var liters: String {
        String(format: "%.1fL", Double(waterMl) / 1000.0)
    }

    private var targetLiters: String {
        String(format: "%.1fL", Double(WaterStore.dailyTargetMl) / 1000.0)
    }

    var body: some View {
        VStack(spacing: 10) {
            // Header row — progress + quick-add
            HStack(spacing: 10) {
                // Icon + progress
                ZStack {
                    Circle()
                        .stroke(Color(hex: "0891B2").opacity(0.15), lineWidth: 3)
                        .frame(width: 38, height: 38)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color(hex: "0891B2"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 38, height: 38)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.4), value: progress)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "0891B2"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Hydration")
                        .font(.subheadline.weight(.semibold))
                    Text("\(liters) / \(targetLiters)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Quick-add buttons
                HStack(spacing: 6) {
                    quickAddButton(ml: 250, label: "+250ml")
                    quickAddButton(ml: 500, label: "+500ml")
                }

                // Expand for more drinks
                Button {
                    withAnimation(.spring(response: 0.3)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Circle())
                }
            }

            // Expanded: drink type picker + add
            if expanded {
                VStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(DrinkType.allCases) { type in
                                Button {
                                    withAnimation(.spring(response: 0.2)) { selectedDrink = type }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: type.icon)
                                            .font(.system(size: 10))
                                        Text(type.displayName)
                                            .font(.system(size: 11, weight: selectedDrink == type ? .bold : .medium))
                                    }
                                    .foregroundColor(selectedDrink == type ? .white : Color(hex: type.colorHex))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selectedDrink == type
                                                ? Color(hex: type.colorHex)
                                                : Color(hex: type.colorHex).opacity(0.1))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Amount buttons for selected drink
                    HStack(spacing: 6) {
                        let amounts = selectedDrink == .espresso ? [30, 60, 90] : [100, 250, 500]
                        let btnColor = Color(hex: selectedDrink.colorHex)
                        ForEach(amounts, id: \.self) { amount in
                            Button { add(amount) } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 10))
                                    Text("\(amount)ml")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(btnColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(btnColor.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }

                        NavigationLink {
                            DrinkManagementView()
                        } label: {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 36, height: 30)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .payaCard(padding: 12)
        .onAppear { waterMl = WaterStore.todayTotal(context: modelContext) }
    }

    private func quickAddButton(ml: Int, label: String) -> some View {
        Button { add(ml) } label: {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: "0891B2"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "0891B2").opacity(0.1))
                .clipShape(Capsule())
        }
    }

    private func add(_ ml: Int) {
        waterMl = WaterStore.addWater(ml, drinkType: selectedDrink, context: modelContext)
        WatchSessionManager.shared.pushWaterTotal(waterMl)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
