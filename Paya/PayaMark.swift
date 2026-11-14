import SwiftUI

// MARK: - Paya brand mark
// The app-icon motif (open progress ring + heartbeat line) as a vector view,
// so the first screen matches the icon on the Home Screen.

struct PayaMark: View {
    var size: CGFloat = 88

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: size * 0.082)
            Circle()
                .trim(from: 0, to: 0.74)
                .stroke(
                    AngularGradient(
                        colors: [Color(red: 0.51, green: 0.55, blue: 0.97),
                                 Color(red: 0.13, green: 0.83, blue: 0.93),
                                 Color(red: 0.20, green: 0.83, blue: 0.60)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: size * 0.082, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
            PulseLine()
                .stroke(Color.white, style: StrokeStyle(lineWidth: size * 0.045, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.52, height: size * 0.40)
                .shadow(color: Color(red: 0.13, green: 0.83, blue: 0.93).opacity(0.7), radius: size * 0.03)
        }
        .frame(width: size * 0.9, height: size * 0.9)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private struct PulseLine: Shape {
        func path(in r: CGRect) -> Path {
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y) }
            var path = Path()
            path.move(to: p(0, 0.5))
            path.addLine(to: p(0.28, 0.5))
            path.addLine(to: p(0.38, 0.30))
            path.addLine(to: p(0.50, 0.90))
            path.addLine(to: p(0.64, 0.0))
            path.addLine(to: p(0.76, 0.62))
            path.addLine(to: p(0.84, 0.5))
            path.addLine(to: p(1, 0.5))
            return path
        }
    }
}
