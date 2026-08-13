import SwiftUI
import SwiftData

// MARK: - AZE Quick Add
// One-tap logging of Azerbaijani healthy staples with portion adjustment.

struct AzeQuickAddView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    var onAdd: (String, Double, Double) -> Void   // (name, protein, calories)

    @State private var selectedCategory: AzeFood.Category = .protein
    @State private var foodToPortion: AzeFood? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Category chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AzeFood.Category.allCases, id: \.self) { cat in
                            Button {
                                withAnimation(.spring(response: 0.25)) {
                                    selectedCategory = cat
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: cat.icon)
                                        .font(.caption)
                                    Text(cat.rawValue)
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundColor(selectedCategory == cat ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedCategory == cat
                                    ? Color(hex: "059669")
                                    : Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 10)

                Text("Tap the star to pin a food as a quick-add shortcut in search.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(AzeFoodsData.byCategory(selectedCategory)) { food in
                            AzeFoodRow(
                                food: food,
                                isFavorite: appState.profile.favoriteAzeFoodIds.contains(food.id),
                                onToggleFavorite: { toggleFavorite(food) },
                                onTap: { foodToPortion = food }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("AZE Healthy Foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $foodToPortion) { food in
                PortionSheet(food: food) { grams in
                    let n = food.nutrition(grams: grams)
                    onAdd(food.name, n.protein, n.calories)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                }
            }
        }
    }

    private func toggleFavorite(_ food: AzeFood) {
        if let idx = appState.profile.favoriteAzeFoodIds.firstIndex(of: food.id) {
            appState.profile.favoriteAzeFoodIds.remove(at: idx)
        } else {
            appState.profile.favoriteAzeFoodIds.append(food.id)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Food Row

struct AzeFoodRow: View {
    let food: AzeFood
    var isFavorite: Bool = false
    var onToggleFavorite: (() -> Void)? = nil
    let onTap: () -> Void

    var portionNutrition: (protein: Double, calories: Double, carbs: Double, fat: Double) {
        food.nutrition(grams: food.typicalPortionG)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(food.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        Text("\(food.nameAz) · \(food.portionLabel) (\(Int(food.typicalPortionG))g)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.0fg protein", portionNutrition.protein))
                            .font(.caption.weight(.bold))
                            .foregroundColor(Color(hex: "2563EB"))
                            .monospacedDigit()
                        Text(String(format: "%.0f kcal", portionNutrition.calories))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Color(hex: "059669"))
                }
            }
            .buttonStyle(.plain)

            if let onToggleFavorite {
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.subheadline)
                        .foregroundColor(isFavorite ? Color(hex: "B45309") : .secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .payaCard(padding: 12)
    }
}

// MARK: - Portion Sheet

struct PortionSheet: View {

    @Environment(\.dismiss) private var dismiss

    let food: AzeFood
    let onConfirm: (Double) -> Void

    @State private var grams: Double = 100

    var nutrition: (protein: Double, calories: Double, carbs: Double, fat: Double) {
        food.nutrition(grams: grams)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {

                VStack(spacing: 3) {
                    Text(food.name)
                        .font(.headline)
                    Text(food.nameAz)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 14)

                // Macro grid
                HStack(spacing: 8) {
                    MacroPill(label: "PROTEIN", value: nutrition.protein, unit: "g", colorHex: "2563EB")
                    MacroPill(label: "KCAL", value: nutrition.calories, unit: "", colorHex: "D97706")
                    MacroPill(label: "CARBS", value: nutrition.carbs, unit: "g", colorHex: "059669")
                    MacroPill(label: "FAT", value: nutrition.fat, unit: "g", colorHex: "8B5CF6")
                }
                .padding(.horizontal, 16)

                // Portion controls
                VStack(spacing: 10) {
                    Text("\(Int(grams))g")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Slider(value: $grams, in: 20...500, step: 10)
                        .tint(Color(hex: "059669"))
                        .padding(.horizontal, 20)

                    HStack(spacing: 8) {
                        PortionPresetButton(label: "½ portion", grams: food.typicalPortionG / 2, current: $grams)
                        PortionPresetButton(label: food.portionLabel, grams: food.typicalPortionG, current: $grams)
                        PortionPresetButton(label: "2× portion", grams: food.typicalPortionG * 2, current: $grams)
                    }
                }

                Button {
                    onConfirm(grams)
                    dismiss()
                } label: {
                    Text(String(format: "Add %.0fg protein · %.0f kcal", nutrition.protein, nutrition.calories))
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color(hex: "059669"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 16)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            grams = food.typicalPortionG
        }
    }
}

struct MacroPill: View {
    let label: String
    let value: Double
    let unit: String
    let colorHex: String

    var body: some View {
        VStack(spacing: 3) {
            Text(String(format: "%.0f%@", value, unit))
                .font(.subheadline.weight(.bold))
                .foregroundColor(Color(hex: colorHex))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(hex: colorHex).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct PortionPresetButton: View {
    let label: String
    let grams: Double
    @Binding var current: Double

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25)) {
                current = grams
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(abs(current - grams) < 1 ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(abs(current - grams) < 1
                    ? Color(hex: "059669")
                    : Color(.secondarySystemBackground))
                .clipShape(Capsule())
        }
    }
}//
//  AzeQuickAddView.swift
//  Paya
//
//  Created by Emin Huseynzade on 11.07.26.
//

