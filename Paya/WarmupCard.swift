import SwiftUI

// MARK: - Warm-up Card
// Expandable card that appears at the top of the Train view before exercises.

struct WarmupCard: View {

    var routine: WarmupRoutine
    var sessionColor: Color

    @State private var isExpanded: Bool = false
    @State private var completedMoves: Set<String> = []
    @State private var showFullSheet: Bool = false

    var progress: Double {
        guard !routine.moves.isEmpty else { return 0 }
        return Double(completedMoves.count) / Double(routine.moves.count)
    }

    var isComplete: Bool {
        completedMoves.count == routine.moves.count
    }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Header (always visible)
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 12) {

                    ZStack {
                        Circle()
                            .fill(sessionColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        if isComplete {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(Pulse.positive)
                        } else {
                            Image(systemName: "figure.flexibility")
                                .font(.title3)
                                .foregroundColor(sessionColor)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Warm-up")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Pulse.textPrimary)
                            Text("· \(routine.totalMinutes) min")
                                .font(.caption)
                                .foregroundColor(Pulse.textTertiary)
                        }
                        Text(isComplete
                             ? "Complete — ready to lift"
                             : (completedMoves.isEmpty
                                ? routine.subtitle
                                : "\(completedMoves.count) of \(routine.moves.count) done"))
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if isComplete {
                        Text("✓")
                            .font(.headline.weight(.bold))
                            .foregroundColor(Pulse.positive)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                }
                .padding(14)
            }
            .buttonStyle(PulsePress())

            // Progress bar
            if completedMoves.count > 0 && !isComplete {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(sessionColor.opacity(0.12))
                        Rectangle()
                            .fill(sessionColor)
                            .frame(width: geo.size.width * progress)
                            .animation(.spring(response: 0.4), value: progress)
                    }
                }
                .frame(height: 3)
            }

            // MARK: Expanded content
            if isExpanded {
                Divider()

                VStack(spacing: 10) {
                    ForEach(routine.moves) { move in
                        WarmupMoveRow(
                            move: move,
                            sessionColor: sessionColor,
                            isCompleted: completedMoves.contains(move.id),
                            onToggle: {
                                withAnimation(.spring(response: 0.3)) {
                                    if completedMoves.contains(move.id) {
                                        completedMoves.remove(move.id)
                                    } else {
                                        completedMoves.insert(move.id)
                                    }
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if completedMoves.count == routine.moves.count {
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                }
                            }
                        )
                    }

                    HStack(spacing: 10) {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                completedMoves.removeAll()
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            Label("Reset", systemImage: "arrow.uturn.backward")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Pulse.surfaceElevatedFallback)
                                .foregroundColor(Pulse.textTertiary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                completedMoves = Set(routine.moves.map { $0.id })
                            }
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } label: {
                            Label("Skip all", systemImage: "forward.fill")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(sessionColor.opacity(0.1))
                                .foregroundColor(sessionColor)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(14)
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isComplete ? Pulse.positive.opacity(0.4) : Color.clear,
                    lineWidth: 1.5
                )
        )
    }
}

// MARK: - Warmup Move Row

struct WarmupMoveRow: View {
    var move: WarmupMove
    var sessionColor: Color
    var isCompleted: Bool
    var onToggle: () -> Void

    @State private var showDetail: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {

                // Done toggle
                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .fill(isCompleted
                                ? sessionColor
                                : Pulse.surfaceElevatedFallback)
                            .frame(width: 32, height: 32)
                        Image(systemName: isCompleted ? "checkmark" : "circle")
                            .font(.caption.weight(.bold))
                            .foregroundColor(isCompleted ? .white : .secondary)
                    }
                }
                .buttonStyle(PulsePress())
                .accessibilityLabel(move.name)
                .accessibilityAddTraits(isCompleted ? .isSelected : [])
                .accessibilityValue(isCompleted ? "Done" : "Not done")

                // Tap to expand details
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showDetail.toggle()
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: move.icon)
                                .font(.caption)
                                .foregroundColor(sessionColor)
                            Text(move.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(isCompleted ? .secondary : .primary)
                                .strikethrough(isCompleted)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                        }
                        Text(move.duration)
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PulsePress())

                Image(systemName: showDetail ? "chevron.up" : "info.circle")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
            }

            if showDetail {
                VStack(alignment: .leading, spacing: 8) {
                    Divider().padding(.vertical, 4)

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "text.alignleft")
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                            .frame(width: 16)
                        Text(move.instructions)
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "target")
                            .font(.caption)
                            .foregroundColor(sessionColor)
                            .frame(width: 16)
                        Text(move.purpose)
                            .font(.caption)
                            .foregroundColor(sessionColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if move.isJointSensitive {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(Pulse.warning)
                                .frame(width: 16)
                            Text("Move slowly through pain-free range only")
                                .font(.caption2)
                                .foregroundColor(Pulse.warning)
                        }
                    }
                }
                .padding(.leading, 44)
                .padding(.top, 4)
            }
        }
        .padding(10)
        .background(Pulse.surfaceElevatedFallback.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
