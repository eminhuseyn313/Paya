import SwiftUI
import SwiftData

// MARK: - Session Reflection Card

struct SessionReflectionCard: View {

    var session: TrainingSession

    @State private var showReflectionSheet: Bool = false

    var hasReflection: Bool {
        session.reflectedAt != nil
    }

    var body: some View {
        Button {
            showReflectionSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: hasReflection
                          ? "text.bubble.fill"
                          : "text.bubble")
                        .foregroundColor(Pulse.ai)
                    Text(hasReflection ? "Your reflection" : "Add reflection")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Pulse.textPrimary)
                    Spacer()
                    Image(systemName: hasReflection ? "pencil" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                }

                if hasReflection {
                    if let rpe = session.subjectiveRPE {
                        HStack(spacing: 8) {
                            RPEBadge(rpe: rpe)
                            if let energy = session.energyAfter {
                                EnergyBadge(energy: energy)
                            }
                            Spacer()
                        }
                    }

                    if !session.reflectionTags.isEmpty {
                        FlowLayout(spacing: 4) {
                            ForEach(Array(Set(session.reflectionTags)).sorted(), id: \.self) { tagId in
                                Text(displayLabel(for: tagId))
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Pulse.ai.opacity(0.12))
                                    .foregroundColor(Pulse.ai)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    if let notes = session.reflectionNotes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Text("How did this session feel? Tap to add.")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                }
            }
            .payaCard(padding: 14)
        }
        .buttonStyle(PulsePress())
        .sheet(isPresented: $showReflectionSheet) {
            ReflectionSheet(session: session)
        }
    }

    func displayLabel(for id: String) -> String {
        switch id {
        case "in_the_zone":       return "In the zone"
        case "great_pump":        return "Great pump"
        case "strong_today":      return "Strong today"
        case "trained_through":   return "Pushed through"
        case "low_energy":        return "Low energy"
        case "distracted":        return "Distracted"
        case "form_breaking":     return "Form breaking"
        case "ac_clicked":        return "AC joint clicked"   // legacy id, kept for old logged sessions
        case "shoulder_pain":     return "Shoulder pain"
        case "wrist_pain":        return "Wrist pain"
        case "elbow_flare":       return "Elbow flare"
        case "back_tight":        return "Back tight/stiff"
        case "joint_clicked":     return "Joint clicked/caught"
        case "joint_swelling":    return "Joint swelling"
        case "reduced_rom":       return "Reduced range of motion"
        case "hip_pain":          return "Hip pain"
        case "morning_stiffness": return "Morning stiffness lingered"
        case "joint_pain":        return "Joint pain"
        case "fatigue_crash":     return "Fatigue crash"
        case "skin_flare":        return "Skin flare"
        case "widespread_pain":   return "Widespread pain"
        case "brain_fog":         return "Brain fog"
        case "tender_points":     return "Tender points sore"
        case "pem_crash":         return "Post-exertional crash"
        case "fatigue_spike":     return "Fatigue spike"
        case "joint_stiffness":   return "Joint stiffness"
        default:                  return id
        }
    }
}

// MARK: - RPE Badge

struct RPEBadge: View {
    var rpe: Int

    var color: Color {
        switch rpe {
        case 1...3:  return Pulse.positive
        case 4...6:  return Pulse.warning
        case 7...8:  return Color(hex: "C2410C")
        default:     return Pulse.critical
        }
    }

    var label: String {
        switch rpe {
        case 1...2:  return "Very easy"
        case 3...4:  return "Easy"
        case 5...6:  return "Moderate"
        case 7...8:  return "Hard"
        case 9:      return "Very hard"
        case 10:     return "Max"
        default:     return ""
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Text("RPE \(rpe)")
                .font(.caption.weight(.bold))
            Text(label)
                .font(.caption)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color)
        .clipShape(Capsule())
    }
}

// MARK: - Energy Badge

struct EnergyBadge: View {
    var energy: Int

    var icon: String {
        switch energy {
        case 1: return "battery.25"
        case 2: return "battery.50"
        default: return "battery.100"
        }
    }

    var label: String {
        switch energy {
        case 1: return "Drained"
        case 2: return "OK"
        default: return "Energized"
        }
    }

    var color: Color {
        switch energy {
        case 1: return Pulse.critical
        case 2: return Pulse.warning
        default: return Pulse.positive
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(label)
                .font(.caption.weight(.semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}//
//  SessionReflectionCard.swift
//  Paya
//
//  Created by Emin Huseynzade on 05.07.26.
//

