//
//  ProductDetailSheet.swift
//  Paya
//
//  Created by Emin Huseynzade on 13.07.26.
//

import SwiftUI

// MARK: - Product Detail Sheet
// Rich detail for scanned/searched foods: portion slider, live macro preview.

struct ProductDetailSheet: View {

    @Environment(\.dismiss) private var dismiss

    let product: FoodDatabaseService.FoodProduct
    let onAdd: (String, Double, Double) -> Void   // (name, protein, calories)

    @State private var grams: Double = 100

    var nutrition: (protein: Double, calories: Double) {
        product.nutritionFor(grams: grams)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {

                VStack(spacing: 4) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.title)
                        .foregroundColor(Pulse.hydration)
                    Text(product.name)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.top, 14)
                .padding(.horizontal, 20)

                // Macro preview for the current portion
                HStack(spacing: 8) {
                    MacroPill(
                        label: "PROTEIN",
                        value: nutrition.protein,
                        unit: "g",
                        colorHex: "2563EB"
                    )
                    MacroPill(
                        label: "KCAL",
                        value: nutrition.calories,
                        unit: "",
                        colorHex: "D97706"
                    )
                }
                .padding(.horizontal, 16)

                // Per-100g reference line
                let ref = product.nutritionFor(grams: 100)
                Text(String(format: "Per 100g: %.1fg protein · %.0f kcal", ref.protein, ref.calories))
                    .font(.caption2)
                    .foregroundColor(Pulse.textTertiary)

                // Portion controls
                VStack(spacing: 10) {
                    Text("\(Int(grams))g")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Slider(value: $grams, in: 10...500, step: 5)
                        .tint(Pulse.hydration)
                        .padding(.horizontal, 20)

                    HStack(spacing: 8) {
                        GramPresetButton(label: "50g", grams: 50, current: $grams)
                        GramPresetButton(label: "100g", grams: 100, current: $grams)
                        GramPresetButton(label: "150g", grams: 150, current: $grams)
                        GramPresetButton(label: "250g", grams: 250, current: $grams)
                    }
                }

                Button {
                    onAdd(product.name, nutrition.protein, nutrition.calories)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                } label: {
                    Text(String(format: "Add %.0fg protein · %.0f kcal", nutrition.protein, nutrition.calories))
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Pulse.hydration)
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
    }
}

struct GramPresetButton: View {
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
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(abs(current - grams) < 1
                    ? Pulse.hydration
                    : Color(.secondarySystemBackground))
                .clipShape(Capsule())
        }
    }
}
