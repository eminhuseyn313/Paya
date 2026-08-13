import SwiftUI
import SwiftData

struct DeloadCard: View {

    @Environment(\.modelContext) private var modelContext

    var onChanged: () -> Void

    @State private var suggestion: DeloadEngine.Suggestion? = nil
    @State private var refreshTick = 0

    var body: some View {
        Group {
            if DeloadEngine.isDeloadActive {
                activeBanner
            } else if let s = suggestion, s.isDue {
                dueBanner(s)
            }
        }
        .onAppear { evaluate() }
        .id(refreshTick)
    }

    private var activeBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "0891B2").opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(Color(hex: "0891B2"))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Deload week active")
                    .font(.subheadline.weight(.bold))
                Text("Loads −35% · \(DeloadEngine.deloadDaysRemaining) days left · easy on purpose")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                DeloadEngine.endDeloadEarly()
                refreshTick += 1
                onChanged()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Text("End")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Color(hex: "0891B2"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "0891B2").opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .payaCard(padding: 14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "0891B2").opacity(0.3), lineWidth: 1)
        )
    }

    private func dueBanner(_ s: DeloadEngine.Suggestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "battery.25")
                    .foregroundColor(Color(hex: "0891B2"))
                Text("Deload recommended")
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text("Week \(s.weeksTrained)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
            }
            Text(s.reason)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                DeloadEngine.startDeload()
                refreshTick += 1
                onChanged()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: {
                Text("Start deload week")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color(hex: "0891B2"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .payaCard(padding: 14)
    }

    private func evaluate() {
        suggestion = DeloadEngine.evaluate(context: modelContext)
    }
}//
//  DeloadCard.swift
//  Paya
//
//  Created by Emin Huseynzade on 14.07.26.
//

