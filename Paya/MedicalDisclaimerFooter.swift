import SwiftUI

/// One shared, consistent wellness disclaimer for every surface that offers
/// health-adjacent estimates (flare risk, AI answers, supplements, medications).
/// App Review 1.4.1 / 5.1.3 — informational only, never diagnostic.
struct MedicalDisclaimerFooter: View {
    enum Kind {
        case flare, ai, supplements, medication
        var text: String {
            switch self {
            case .flare:
                return "Flare-risk and forecast figures are statistical estimates from your own tracked data. They are not a diagnosis or a prediction of illness. Talk to your doctor about symptoms or treatment changes."
            case .ai:
                return "Answers are generated from your logged data and general knowledge. They are not medical advice and can be wrong. Check anything health-related with a qualified professional."
            case .supplements:
                return "General information only — not a recommendation to start, stop or change any supplement or medicine. Check with your doctor or pharmacist, especially if you take prescription medication."
            case .medication:
                return "Paya only helps you remember and log doses you have been prescribed. It does not give dosing advice. Never change or stop medication without your prescriber."
            }
        }
    }

    let kind: Kind

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle")
                .font(.pulse(size: 10))
            Text(kind.text)
                .font(.pulse(size: 10))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(Pulse.textTertiary)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
