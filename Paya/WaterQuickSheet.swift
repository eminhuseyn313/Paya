import SwiftUI
import SwiftData

// MARK: - Water Quick Sheet
//
// Compact, medium-detent sheet for fast water/drink logging.
// Replaces the full DrinkManagementView as the default tap action
// on the Water orb and chip. Full drink details (timeline, caffeine
// tracking, weekly chart) are still reachable via "All drinks →".

struct WaterQuickSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var waterMl: Int = 0
    @State private var selectedDrink: DrinkType = .water
    @State private var showFullSheet = false
    @State private var addedAnimation = false

    private var progress: Double {
        min(1.0, Double(waterMl) / Double(WaterStore.dailyTargetMl))
    }

    private var remaining: Int {
        max(0, WaterStore.dailyTargetMl - waterMl)
    }

    private var drinkColor: Color { Color(hex: selectedDrink.colorHex) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {

                // MARK: Progress ring + stats
                HStack(spacing: 20) {
                    // Compact ring
                    ZStack {
                        Circle()
                            .stroke(Pulse.hydration.opacity(0.12), lineWidth: 8)
                            .frame(width: 72, height: 72)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Pulse.hydration, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 72, height: 72)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.5), value: progress)
                        VStack(spacing: 0) {
                            Text(String(format: "%.1f", Double(waterMl) / 1000.0))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(Pulse.textPrimary)
                            Text("L")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Pulse.textTertiary)
                        }
                    }
                    .scaleEffect(addedAnimation ? 1.08 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.5), value: addedAnimation)

                    VStack(alignment: .leading, spacing: 6) {
                        if progress >= 1.0 {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Pulse.positive)
                                    .font(.system(size: 14))
                                Text("Target reached!")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Pulse.positive)
                            }
                        } else {
                            Text("\(remaining)ml to go")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Pulse.textSecondary)
                        }
                        Text("of \(String(format: "%.1fL", Double(WaterStore.dailyTargetMl) / 1000.0)) target")
                            .font(.system(size: 12))
                            .foregroundColor(Pulse.textTertiary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 4)

                // MARK: Quick-add water buttons
                HStack(spacing: 10) {
                    quickAddPill(ml: 150)
                    quickAddPill(ml: 250)
                    quickAddPill(ml: 500)
                }

                // MARK: Drink type selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("OTHER DRINKS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Pulse.textTertiary)
                        .tracking(1)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(DrinkType.allCases.filter { $0 != .water }) { type in
                                drinkChip(type)
                            }
                        }
                    }

                    // Amount presets for selected non-water drink
                    if selectedDrink != .water {
                        HStack(spacing: 8) {
                            let amounts = selectedDrink == .espresso ? [30, 60, 90] : [100, 250, 330]
                            ForEach(amounts, id: \.self) { amount in
                                Button { add(amount, drinkType: selectedDrink) } label: {
                                    Text("+\(amount)ml")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(drinkColor)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(drinkColor.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Spacer(minLength: 0)

                // MARK: Full details link
                Button {
                    showFullSheet = true
                } label: {
                    HStack {
                        Image(systemName: "list.bullet.below.rectangle")
                            .font(.system(size: 13))
                        Text("All drinks & details")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(Pulse.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Pulse.surfaceFallback)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(Pulse.canvasFallback.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationTitle("Water")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showFullSheet) {
                DrinkManagementView()
            }
        }
        .onAppear { waterMl = WaterStore.todayTotal(context: modelContext) }
    }

    // MARK: - Quick-add pill (water)

    private func quickAddPill(ml: Int) -> some View {
        Button {
            add(ml, drinkType: .water)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text("\(ml)ml")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Pulse.hydration)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Drink type chip

    private func drinkChip(_ type: DrinkType) -> some View {
        let isSelected = selectedDrink == type
        let color = Color(hex: type.colorHex)
        return Button {
            withAnimation(.spring(response: 0.25)) {
                selectedDrink = isSelected ? .water : type
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.system(size: 10))
                Text(type.displayName)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : color.opacity(0.1))
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add

    private func add(_ ml: Int, drinkType: DrinkType) {
        waterMl = WaterStore.addWater(ml, drinkType: drinkType, context: modelContext)
        WatchSessionManager.shared.pushWaterTotal(waterMl)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Bounce animation on ring
        addedAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            addedAnimation = false
        }
    }
}
