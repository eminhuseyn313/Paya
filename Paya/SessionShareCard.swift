import SwiftUI

// MARK: - Session Share Card
// Low-effort version of the social-accountability gap flagged in the
// report: a shareable image export instead of a full social graph, so we
// can see if there's demand before building anything heavier.

struct SessionShareCard: View {
    var session: TrainingSession
    var profileName: String
    var profileColor: Color

    private var sessionType: SessionType? {
        SessionType(rawValue: session.sessionType)
    }

    private var totalVolume: Double {
        session.exercises.reduce(0.0) { total, ex in
            total + ex.sets
                .filter { $0.isCompleted }
                .reduce(0.0) { $0 + ($1.weightKg * Double($1.reps)) }
        }
    }

    private var totalSets: Int {
        session.exercises.reduce(0) { total, ex in
            total + ex.sets.filter { $0.isCompleted }.count
        }
    }

    private var exerciseCount: Int {
        session.exercises.filter { !$0.sets.filter { $0.isCompleted }.isEmpty }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(profileColor)
                            .frame(width: 10, height: 10)
                        Text("Paya")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Spacer()
                    Text(session.date.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 6) {
                    Text(sessionType?.focus ?? "Training Session")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(profileColor.opacity(0.95))
                    Text(sessionType?.displayName ?? "Session")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 0) {
                    statBlock(value: "\(session.durationMinutes)", unit: "min")
                    Spacer()
                    statBlock(value: "\(totalSets)", unit: "sets")
                    Spacer()
                    statBlock(value: "\(Int(totalVolume))", unit: "kg moved")
                }

                if let rpe = session.subjectiveRPE {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                            .foregroundColor(profileColor)
                        Text("RPE \(rpe)/10 · \(exerciseCount) exercises")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    Text("\(exerciseCount) exercises")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(28)
        }
        .frame(width: 360, height: 460)
        .background(
            LinearGradient(
                colors: [Color(hex: "0B0D12"), profileColor.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    @ViewBuilder
    private func statBlock(value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            Text(unit)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
        }
    }
}

// MARK: - Renderer

enum SessionShareRenderer {
    @MainActor
    static func render(session: TrainingSession, profileName: String, profileColor: Color) -> UIImage? {
        let card = SessionShareCard(session: session, profileName: profileName, profileColor: profileColor)
        let renderer = ImageRenderer(content: card)
        renderer.scale = UITraitCollection.current.displayScale
        return renderer.uiImage
    }
}
