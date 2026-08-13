import SwiftUI

// MARK: - Body Heatmap

struct BodyHeatmapCard: View {
    let session: TrainingSession

    private var activationByMuscle: [String: MuscleActivationEngine.MuscleActivation] {
        MuscleActivationEngine.analyze(session: session, maxHR: LiveHRManager.shared.maxHR)
    }

    private var regionColors: [BodyRegion: Color] {
        var result: [BodyRegion: Color] = [:]
        for (muscle, activation) in activationByMuscle {
            for region in MuscleActivationEngine.regions(for: muscle) {
                result[region] = Color(hex: activation.zone.colorHex)
            }
        }
        return result
    }

    private var hasAnyHRData: Bool {
        activationByMuscle.values.contains { !$0.isVolumeBased }
    }

    var body: some View {
        if !activationByMuscle.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.arms.open")
                        .foregroundColor(Color(hex: "DC2626"))
                    Text("Muscle Map")
                        .font(.subheadline.weight(.semibold))
                    CardInfoButton(
                        title: "Muscle Map",
                        explanation: "Regions with a heart-rate reading are colored by that muscle group's average %HRmax that session (the Effort Map, painted onto the body). Regions without a strap connected fall back to relative training load for that session instead of staying blank. Gray regions weren't tracked at all."
                    )
                    Spacer()
                }

                HStack(spacing: 24) {
                    Spacer()
                    VStack(spacing: 4) {
                        BodyFigureView(isFront: true, regionColors: regionColors)
                        Text("Front").font(.caption2).foregroundColor(.secondary)
                    }
                    VStack(spacing: 4) {
                        BodyFigureView(isFront: false, regionColors: regionColors)
                        Text("Back").font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                }

                HStack(spacing: 10) {
                    legendDot(.light)
                    legendDot(.moderate)
                    legendDot(.vigorous)
                    legendDot(.nearMax)
                }

                if !hasAnyHRData {
                    Text("No heart-rate monitor connected this session — colors reflect relative training load, not measured effort.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .payaCard(padding: 14)
        }
    }

    private func legendDot(_ zone: SessionIntensityEngine.IntensityZone) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: zone.colorHex))
                .frame(width: 6, height: 6)
            Text(zone.rawValue)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Realistic Anatomical Body Figure

struct BodyFigureView: View {
    let isFront: Bool
    let regionColors: [BodyRegion: Color]

    private let w: CGFloat = 160
    private let h: CGFloat = 340

    var body: some View {
        ZStack {
            Image(isFront ? "anatomy_front" : "anatomy_back")
                .resizable()
                .aspectRatio(contentMode: .fit)

            Canvas { ctx, size in
                let sx = size.width / 400.0
                let sy = size.height / 850.0

                func s(_ path: Path) -> Path {
                    path.applying(CGAffineTransform(scaleX: sx, y: sy))
                }

                func ov(_ path: Path, _ region: BodyRegion) {
                    guard let color = regionColors[region] else { return }
                    ctx.fill(s(path), with: .color(color.opacity(0.45)))
                }

                if isFront {
                    ov(fTrapL, .frontDelts); ov(fTrapR, .frontDelts)
                    ov(fDeltL, .frontDelts); ov(fDeltR, .frontDelts)
                    ov(fPecL, .chest); ov(fPecR, .chest)
                    ov(fBicL, .biceps); ov(fBicR, .biceps)
                    ov(fAbsU, .abs); ov(fAbsM, .abs); ov(fAbsLo, .abs)
                    ov(fOblL, .abs); ov(fOblR, .abs)
                    ov(fQuadL, .quads); ov(fQuadR, .quads)
                    ov(fVLL, .quads); ov(fVLR, .quads)
                } else {
                    ov(bTrap, .back)
                    ov(bDeltL, .rearDelts); ov(bDeltR, .rearDelts)
                    ov(bLatL, .back); ov(bLatR, .back)
                    ov(bTriL, .triceps); ov(bTriR, .triceps)
                    ov(bGluteL, .glutes); ov(bGluteR, .glutes)
                    ov(bHamL, .hamstrings); ov(bHamR, .hamstrings)
                    ov(bCalfL, .calves); ov(bCalfR, .calves)
                }
            }
        }
        .frame(width: w, height: h)
    }

    // MARK: - Front overlay regions (400x850 coordinate space matching SVG)

    private var fTrapL: Path {
        var p = Path()
        p.move(to: CGPoint(x: 182, y: 100))
        p.addCurve(to: CGPoint(x: 138, y: 112), control1: CGPoint(x: 175, y: 97), control2: CGPoint(x: 155, y: 102))
        p.addLine(to: CGPoint(x: 150, y: 124))
        p.addCurve(to: CGPoint(x: 185, y: 107), control1: CGPoint(x: 162, y: 116), control2: CGPoint(x: 175, y: 110))
        p.closeSubpath(); return p
    }
    private var fTrapR: Path {
        var p = Path()
        p.move(to: CGPoint(x: 218, y: 100))
        p.addCurve(to: CGPoint(x: 262, y: 112), control1: CGPoint(x: 225, y: 97), control2: CGPoint(x: 245, y: 102))
        p.addLine(to: CGPoint(x: 250, y: 124))
        p.addCurve(to: CGPoint(x: 215, y: 107), control1: CGPoint(x: 238, y: 116), control2: CGPoint(x: 225, y: 110))
        p.closeSubpath(); return p
    }
    private var fDeltL: Path {
        var p = Path()
        p.move(to: CGPoint(x: 150, y: 112))
        p.addCurve(to: CGPoint(x: 115, y: 118), control1: CGPoint(x: 138, y: 106), control2: CGPoint(x: 122, y: 108))
        p.addCurve(to: CGPoint(x: 112, y: 168), control1: CGPoint(x: 108, y: 130), control2: CGPoint(x: 106, y: 148))
        p.addCurve(to: CGPoint(x: 138, y: 135), control1: CGPoint(x: 118, y: 160), control2: CGPoint(x: 128, y: 146))
        p.addCurve(to: CGPoint(x: 150, y: 112), control1: CGPoint(x: 146, y: 126), control2: CGPoint(x: 153, y: 120))
        p.closeSubpath(); return p
    }
    private var fDeltR: Path {
        var p = Path()
        p.move(to: CGPoint(x: 250, y: 112))
        p.addCurve(to: CGPoint(x: 285, y: 118), control1: CGPoint(x: 262, y: 106), control2: CGPoint(x: 278, y: 108))
        p.addCurve(to: CGPoint(x: 288, y: 168), control1: CGPoint(x: 292, y: 130), control2: CGPoint(x: 294, y: 148))
        p.addCurve(to: CGPoint(x: 262, y: 135), control1: CGPoint(x: 282, y: 160), control2: CGPoint(x: 272, y: 146))
        p.addCurve(to: CGPoint(x: 250, y: 112), control1: CGPoint(x: 254, y: 126), control2: CGPoint(x: 247, y: 120))
        p.closeSubpath(); return p
    }
    private var fPecL: Path {
        var p = Path()
        p.move(to: CGPoint(x: 152, y: 118))
        p.addCurve(to: CGPoint(x: 198, y: 116), control1: CGPoint(x: 162, y: 113), control2: CGPoint(x: 184, y: 110))
        p.addCurve(to: CGPoint(x: 190, y: 158), control1: CGPoint(x: 198, y: 128), control2: CGPoint(x: 196, y: 144))
        p.addCurve(to: CGPoint(x: 146, y: 148), control1: CGPoint(x: 178, y: 162), control2: CGPoint(x: 158, y: 158))
        p.addCurve(to: CGPoint(x: 140, y: 120), control1: CGPoint(x: 138, y: 140), control2: CGPoint(x: 136, y: 130))
        p.closeSubpath(); return p
    }
    private var fPecR: Path {
        var p = Path()
        p.move(to: CGPoint(x: 248, y: 118))
        p.addCurve(to: CGPoint(x: 202, y: 116), control1: CGPoint(x: 238, y: 113), control2: CGPoint(x: 216, y: 110))
        p.addCurve(to: CGPoint(x: 210, y: 158), control1: CGPoint(x: 202, y: 128), control2: CGPoint(x: 204, y: 144))
        p.addCurve(to: CGPoint(x: 254, y: 148), control1: CGPoint(x: 222, y: 162), control2: CGPoint(x: 242, y: 158))
        p.addCurve(to: CGPoint(x: 260, y: 120), control1: CGPoint(x: 262, y: 140), control2: CGPoint(x: 264, y: 130))
        p.closeSubpath(); return p
    }
    private var fBicL: Path {
        var p = Path()
        p.move(to: CGPoint(x: 115, y: 168))
        p.addCurve(to: CGPoint(x: 102, y: 192), control1: CGPoint(x: 112, y: 172), control2: CGPoint(x: 106, y: 180))
        p.addCurve(to: CGPoint(x: 102, y: 245), control1: CGPoint(x: 98, y: 208), control2: CGPoint(x: 98, y: 228))
        p.addCurve(to: CGPoint(x: 118, y: 242), control1: CGPoint(x: 107, y: 250), control2: CGPoint(x: 114, y: 248))
        p.addCurve(to: CGPoint(x: 128, y: 192), control1: CGPoint(x: 126, y: 226), control2: CGPoint(x: 128, y: 208))
        p.addCurve(to: CGPoint(x: 115, y: 168), control1: CGPoint(x: 128, y: 178), control2: CGPoint(x: 122, y: 170))
        p.closeSubpath(); return p
    }
    private var fBicR: Path {
        var p = Path()
        p.move(to: CGPoint(x: 285, y: 168))
        p.addCurve(to: CGPoint(x: 298, y: 192), control1: CGPoint(x: 288, y: 172), control2: CGPoint(x: 294, y: 180))
        p.addCurve(to: CGPoint(x: 298, y: 245), control1: CGPoint(x: 302, y: 208), control2: CGPoint(x: 302, y: 228))
        p.addCurve(to: CGPoint(x: 282, y: 242), control1: CGPoint(x: 293, y: 250), control2: CGPoint(x: 286, y: 248))
        p.addCurve(to: CGPoint(x: 272, y: 192), control1: CGPoint(x: 274, y: 226), control2: CGPoint(x: 272, y: 208))
        p.addCurve(to: CGPoint(x: 285, y: 168), control1: CGPoint(x: 272, y: 178), control2: CGPoint(x: 278, y: 170))
        p.closeSubpath(); return p
    }
    private var fAbsU: Path {
        var p = Path()
        p.addRoundedRect(in: CGRect(x: 188, y: 158, width: 24, height: 28), cornerSize: CGSize(width: 4, height: 4))
        return p
    }
    private var fAbsM: Path {
        var p = Path()
        p.addRoundedRect(in: CGRect(x: 188, y: 186, width: 24, height: 27), cornerSize: CGSize(width: 4, height: 4))
        return p
    }
    private var fAbsLo: Path {
        var p = Path()
        p.addRoundedRect(in: CGRect(x: 188, y: 213, width: 24, height: 38), cornerSize: CGSize(width: 4, height: 4))
        return p
    }
    private var fOblL: Path {
        var p = Path()
        p.move(to: CGPoint(x: 186, y: 162))
        p.addCurve(to: CGPoint(x: 155, y: 178), control1: CGPoint(x: 180, y: 164), control2: CGPoint(x: 168, y: 170))
        p.addCurve(to: CGPoint(x: 152, y: 235), control1: CGPoint(x: 152, y: 195), control2: CGPoint(x: 150, y: 215))
        p.addCurve(to: CGPoint(x: 185, y: 255), control1: CGPoint(x: 158, y: 248), control2: CGPoint(x: 170, y: 255))
        p.addLine(to: CGPoint(x: 186, y: 162))
        p.closeSubpath(); return p
    }
    private var fOblR: Path {
        var p = Path()
        p.move(to: CGPoint(x: 214, y: 162))
        p.addCurve(to: CGPoint(x: 245, y: 178), control1: CGPoint(x: 220, y: 164), control2: CGPoint(x: 232, y: 170))
        p.addCurve(to: CGPoint(x: 248, y: 235), control1: CGPoint(x: 248, y: 195), control2: CGPoint(x: 250, y: 215))
        p.addCurve(to: CGPoint(x: 215, y: 255), control1: CGPoint(x: 242, y: 248), control2: CGPoint(x: 230, y: 255))
        p.addLine(to: CGPoint(x: 214, y: 162))
        p.closeSubpath(); return p
    }
    private var fQuadL: Path {
        var p = Path()
        p.move(to: CGPoint(x: 175, y: 278))
        p.addCurve(to: CGPoint(x: 163, y: 325), control1: CGPoint(x: 170, y: 285), control2: CGPoint(x: 166, y: 300))
        p.addCurve(to: CGPoint(x: 160, y: 415), control1: CGPoint(x: 160, y: 355), control2: CGPoint(x: 158, y: 385))
        p.addCurve(to: CGPoint(x: 176, y: 425), control1: CGPoint(x: 162, y: 425), control2: CGPoint(x: 168, y: 430))
        p.addCurve(to: CGPoint(x: 184, y: 370), control1: CGPoint(x: 180, y: 415), control2: CGPoint(x: 183, y: 395))
        p.addCurve(to: CGPoint(x: 175, y: 278), control1: CGPoint(x: 185, y: 340), control2: CGPoint(x: 182, y: 286))
        p.closeSubpath(); return p
    }
    private var fQuadR: Path {
        var p = Path()
        p.move(to: CGPoint(x: 225, y: 278))
        p.addCurve(to: CGPoint(x: 237, y: 325), control1: CGPoint(x: 230, y: 285), control2: CGPoint(x: 234, y: 300))
        p.addCurve(to: CGPoint(x: 240, y: 415), control1: CGPoint(x: 240, y: 355), control2: CGPoint(x: 242, y: 385))
        p.addCurve(to: CGPoint(x: 224, y: 425), control1: CGPoint(x: 238, y: 425), control2: CGPoint(x: 232, y: 430))
        p.addCurve(to: CGPoint(x: 216, y: 370), control1: CGPoint(x: 220, y: 415), control2: CGPoint(x: 217, y: 395))
        p.addCurve(to: CGPoint(x: 225, y: 278), control1: CGPoint(x: 215, y: 340), control2: CGPoint(x: 218, y: 286))
        p.closeSubpath(); return p
    }
    private var fVLL: Path {
        var p = Path()
        p.move(to: CGPoint(x: 166, y: 274))
        p.addCurve(to: CGPoint(x: 148, y: 322), control1: CGPoint(x: 160, y: 282), control2: CGPoint(x: 153, y: 298))
        p.addCurve(to: CGPoint(x: 146, y: 410), control1: CGPoint(x: 144, y: 350), control2: CGPoint(x: 142, y: 380))
        p.addCurve(to: CGPoint(x: 160, y: 415), control1: CGPoint(x: 150, y: 420), control2: CGPoint(x: 156, y: 423))
        p.addCurve(to: CGPoint(x: 163, y: 325), control1: CGPoint(x: 158, y: 385), control2: CGPoint(x: 160, y: 355))
        p.addCurve(to: CGPoint(x: 175, y: 278), control1: CGPoint(x: 166, y: 300), control2: CGPoint(x: 170, y: 285))
        p.addCurve(to: CGPoint(x: 166, y: 274), control1: CGPoint(x: 170, y: 274), control2: CGPoint(x: 168, y: 272))
        p.closeSubpath(); return p
    }
    private var fVLR: Path {
        var p = Path()
        p.move(to: CGPoint(x: 234, y: 274))
        p.addCurve(to: CGPoint(x: 252, y: 322), control1: CGPoint(x: 240, y: 282), control2: CGPoint(x: 247, y: 298))
        p.addCurve(to: CGPoint(x: 254, y: 410), control1: CGPoint(x: 256, y: 350), control2: CGPoint(x: 258, y: 380))
        p.addCurve(to: CGPoint(x: 240, y: 415), control1: CGPoint(x: 250, y: 420), control2: CGPoint(x: 244, y: 423))
        p.addCurve(to: CGPoint(x: 237, y: 325), control1: CGPoint(x: 242, y: 385), control2: CGPoint(x: 240, y: 355))
        p.addCurve(to: CGPoint(x: 225, y: 278), control1: CGPoint(x: 234, y: 300), control2: CGPoint(x: 230, y: 285))
        p.addCurve(to: CGPoint(x: 234, y: 274), control1: CGPoint(x: 230, y: 274), control2: CGPoint(x: 232, y: 272))
        p.closeSubpath(); return p
    }

    // MARK: - Back overlay regions (400x850 coordinate space matching SVG)

    private var bTrap: Path {
        var p = Path()
        p.move(to: CGPoint(x: 200, y: 85))
        p.addCurve(to: CGPoint(x: 138, y: 112), control1: CGPoint(x: 185, y: 90), control2: CGPoint(x: 155, y: 100))
        p.addCurve(to: CGPoint(x: 165, y: 124), control1: CGPoint(x: 145, y: 118), control2: CGPoint(x: 155, y: 122))
        p.addCurve(to: CGPoint(x: 200, y: 155), control1: CGPoint(x: 175, y: 130), control2: CGPoint(x: 190, y: 142))
        p.addCurve(to: CGPoint(x: 235, y: 124), control1: CGPoint(x: 210, y: 142), control2: CGPoint(x: 225, y: 130))
        p.addCurve(to: CGPoint(x: 262, y: 112), control1: CGPoint(x: 245, y: 122), control2: CGPoint(x: 255, y: 118))
        p.addCurve(to: CGPoint(x: 200, y: 85), control1: CGPoint(x: 245, y: 100), control2: CGPoint(x: 215, y: 90))
        p.closeSubpath(); return p
    }
    private var bDeltL: Path {
        var p = Path()
        p.move(to: CGPoint(x: 148, y: 112))
        p.addCurve(to: CGPoint(x: 113, y: 118), control1: CGPoint(x: 136, y: 106), control2: CGPoint(x: 120, y: 108))
        p.addCurve(to: CGPoint(x: 110, y: 168), control1: CGPoint(x: 106, y: 130), control2: CGPoint(x: 104, y: 148))
        p.addCurve(to: CGPoint(x: 136, y: 135), control1: CGPoint(x: 116, y: 160), control2: CGPoint(x: 126, y: 146))
        p.addCurve(to: CGPoint(x: 148, y: 112), control1: CGPoint(x: 144, y: 126), control2: CGPoint(x: 151, y: 120))
        p.closeSubpath(); return p
    }
    private var bDeltR: Path {
        var p = Path()
        p.move(to: CGPoint(x: 252, y: 112))
        p.addCurve(to: CGPoint(x: 287, y: 118), control1: CGPoint(x: 264, y: 106), control2: CGPoint(x: 280, y: 108))
        p.addCurve(to: CGPoint(x: 290, y: 168), control1: CGPoint(x: 294, y: 130), control2: CGPoint(x: 296, y: 148))
        p.addCurve(to: CGPoint(x: 264, y: 135), control1: CGPoint(x: 284, y: 160), control2: CGPoint(x: 274, y: 146))
        p.addCurve(to: CGPoint(x: 252, y: 112), control1: CGPoint(x: 256, y: 126), control2: CGPoint(x: 249, y: 120))
        p.closeSubpath(); return p
    }
    private var bLatL: Path {
        var p = Path()
        p.move(to: CGPoint(x: 172, y: 148))
        p.addCurve(to: CGPoint(x: 158, y: 182), control1: CGPoint(x: 168, y: 155), control2: CGPoint(x: 162, y: 168))
        p.addCurve(to: CGPoint(x: 152, y: 235), control1: CGPoint(x: 154, y: 200), control2: CGPoint(x: 150, y: 218))
        p.addCurve(to: CGPoint(x: 188, y: 262), control1: CGPoint(x: 158, y: 248), control2: CGPoint(x: 172, y: 260))
        p.addCurve(to: CGPoint(x: 200, y: 158), control1: CGPoint(x: 192, y: 230), control2: CGPoint(x: 196, y: 190))
        p.addCurve(to: CGPoint(x: 172, y: 148), control1: CGPoint(x: 192, y: 150), control2: CGPoint(x: 180, y: 145))
        p.closeSubpath(); return p
    }
    private var bLatR: Path {
        var p = Path()
        p.move(to: CGPoint(x: 228, y: 148))
        p.addCurve(to: CGPoint(x: 242, y: 182), control1: CGPoint(x: 232, y: 155), control2: CGPoint(x: 238, y: 168))
        p.addCurve(to: CGPoint(x: 248, y: 235), control1: CGPoint(x: 246, y: 200), control2: CGPoint(x: 250, y: 218))
        p.addCurve(to: CGPoint(x: 212, y: 262), control1: CGPoint(x: 242, y: 248), control2: CGPoint(x: 228, y: 260))
        p.addCurve(to: CGPoint(x: 200, y: 158), control1: CGPoint(x: 208, y: 230), control2: CGPoint(x: 204, y: 190))
        p.addCurve(to: CGPoint(x: 228, y: 148), control1: CGPoint(x: 208, y: 150), control2: CGPoint(x: 220, y: 145))
        p.closeSubpath(); return p
    }
    private var bTriL: Path {
        var p = Path()
        p.move(to: CGPoint(x: 113, y: 168))
        p.addCurve(to: CGPoint(x: 102, y: 192), control1: CGPoint(x: 110, y: 172), control2: CGPoint(x: 104, y: 180))
        p.addCurve(to: CGPoint(x: 102, y: 245), control1: CGPoint(x: 100, y: 208), control2: CGPoint(x: 98, y: 228))
        p.addCurve(to: CGPoint(x: 118, y: 242), control1: CGPoint(x: 107, y: 250), control2: CGPoint(x: 114, y: 248))
        p.addCurve(to: CGPoint(x: 126, y: 190), control1: CGPoint(x: 124, y: 226), control2: CGPoint(x: 126, y: 206))
        p.addCurve(to: CGPoint(x: 113, y: 168), control1: CGPoint(x: 126, y: 178), control2: CGPoint(x: 122, y: 170))
        p.closeSubpath(); return p
    }
    private var bTriR: Path {
        var p = Path()
        p.move(to: CGPoint(x: 287, y: 168))
        p.addCurve(to: CGPoint(x: 298, y: 192), control1: CGPoint(x: 290, y: 172), control2: CGPoint(x: 296, y: 180))
        p.addCurve(to: CGPoint(x: 298, y: 245), control1: CGPoint(x: 300, y: 208), control2: CGPoint(x: 302, y: 228))
        p.addCurve(to: CGPoint(x: 282, y: 242), control1: CGPoint(x: 293, y: 250), control2: CGPoint(x: 286, y: 248))
        p.addCurve(to: CGPoint(x: 274, y: 190), control1: CGPoint(x: 276, y: 226), control2: CGPoint(x: 274, y: 206))
        p.addCurve(to: CGPoint(x: 287, y: 168), control1: CGPoint(x: 274, y: 178), control2: CGPoint(x: 278, y: 170))
        p.closeSubpath(); return p
    }
    private var bGluteL: Path {
        var p = Path()
        p.move(to: CGPoint(x: 178, y: 285))
        p.addCurve(to: CGPoint(x: 148, y: 310), control1: CGPoint(x: 170, y: 290), control2: CGPoint(x: 155, y: 298))
        p.addCurve(to: CGPoint(x: 145, y: 360), control1: CGPoint(x: 142, y: 325), control2: CGPoint(x: 140, y: 345))
        p.addCurve(to: CGPoint(x: 178, y: 372), control1: CGPoint(x: 152, y: 370), control2: CGPoint(x: 165, y: 375))
        p.addCurve(to: CGPoint(x: 198, y: 345), control1: CGPoint(x: 188, y: 368), control2: CGPoint(x: 195, y: 358))
        p.addCurve(to: CGPoint(x: 200, y: 300), control1: CGPoint(x: 200, y: 332), control2: CGPoint(x: 200, y: 315))
        p.addCurve(to: CGPoint(x: 178, y: 285), control1: CGPoint(x: 195, y: 292), control2: CGPoint(x: 188, y: 288))
        p.closeSubpath(); return p
    }
    private var bGluteR: Path {
        var p = Path()
        p.move(to: CGPoint(x: 222, y: 285))
        p.addCurve(to: CGPoint(x: 252, y: 310), control1: CGPoint(x: 230, y: 290), control2: CGPoint(x: 245, y: 298))
        p.addCurve(to: CGPoint(x: 255, y: 360), control1: CGPoint(x: 258, y: 325), control2: CGPoint(x: 260, y: 345))
        p.addCurve(to: CGPoint(x: 222, y: 372), control1: CGPoint(x: 248, y: 370), control2: CGPoint(x: 235, y: 375))
        p.addCurve(to: CGPoint(x: 202, y: 345), control1: CGPoint(x: 212, y: 368), control2: CGPoint(x: 205, y: 358))
        p.addCurve(to: CGPoint(x: 200, y: 300), control1: CGPoint(x: 200, y: 332), control2: CGPoint(x: 200, y: 315))
        p.addCurve(to: CGPoint(x: 222, y: 285), control1: CGPoint(x: 205, y: 292), control2: CGPoint(x: 212, y: 288))
        p.closeSubpath(); return p
    }
    private var bHamL: Path {
        var p = Path()
        p.move(to: CGPoint(x: 155, y: 372))
        p.addCurve(to: CGPoint(x: 142, y: 410), control1: CGPoint(x: 150, y: 378), control2: CGPoint(x: 145, y: 390))
        p.addCurve(to: CGPoint(x: 140, y: 495), control1: CGPoint(x: 138, y: 435), control2: CGPoint(x: 136, y: 465))
        p.addCurve(to: CGPoint(x: 184, y: 498), control1: CGPoint(x: 144, y: 510), control2: CGPoint(x: 180, y: 512))
        p.addCurve(to: CGPoint(x: 186, y: 415), control1: CGPoint(x: 188, y: 470), control2: CGPoint(x: 188, y: 440))
        p.addCurve(to: CGPoint(x: 175, y: 375), control1: CGPoint(x: 184, y: 395), control2: CGPoint(x: 180, y: 382))
        p.addCurve(to: CGPoint(x: 155, y: 372), control1: CGPoint(x: 170, y: 374), control2: CGPoint(x: 160, y: 372))
        p.closeSubpath(); return p
    }
    private var bHamR: Path {
        var p = Path()
        p.move(to: CGPoint(x: 245, y: 372))
        p.addCurve(to: CGPoint(x: 258, y: 410), control1: CGPoint(x: 250, y: 378), control2: CGPoint(x: 255, y: 390))
        p.addCurve(to: CGPoint(x: 260, y: 495), control1: CGPoint(x: 262, y: 435), control2: CGPoint(x: 264, y: 465))
        p.addCurve(to: CGPoint(x: 216, y: 498), control1: CGPoint(x: 256, y: 510), control2: CGPoint(x: 220, y: 512))
        p.addCurve(to: CGPoint(x: 214, y: 415), control1: CGPoint(x: 212, y: 470), control2: CGPoint(x: 212, y: 440))
        p.addCurve(to: CGPoint(x: 225, y: 375), control1: CGPoint(x: 216, y: 395), control2: CGPoint(x: 220, y: 382))
        p.addCurve(to: CGPoint(x: 245, y: 372), control1: CGPoint(x: 230, y: 374), control2: CGPoint(x: 240, y: 372))
        p.closeSubpath(); return p
    }
    private var bCalfL: Path {
        var p = Path()
        p.move(to: CGPoint(x: 152, y: 525))
        p.addCurve(to: CGPoint(x: 142, y: 572), control1: CGPoint(x: 148, y: 535), control2: CGPoint(x: 144, y: 552))
        p.addCurve(to: CGPoint(x: 146, y: 635), control1: CGPoint(x: 140, y: 595), control2: CGPoint(x: 142, y: 618))
        p.addCurve(to: CGPoint(x: 162, y: 640), control1: CGPoint(x: 150, y: 642), control2: CGPoint(x: 156, y: 644))
        p.addCurve(to: CGPoint(x: 168, y: 588), control1: CGPoint(x: 166, y: 630), control2: CGPoint(x: 168, y: 610))
        p.addCurve(to: CGPoint(x: 164, y: 532), control1: CGPoint(x: 168, y: 565), control2: CGPoint(x: 166, y: 545))
        p.addCurve(to: CGPoint(x: 152, y: 525), control1: CGPoint(x: 162, y: 528), control2: CGPoint(x: 158, y: 524))
        p.closeSubpath(); return p
    }
    private var bCalfR: Path {
        var p = Path()
        p.move(to: CGPoint(x: 248, y: 525))
        p.addCurve(to: CGPoint(x: 258, y: 572), control1: CGPoint(x: 252, y: 535), control2: CGPoint(x: 256, y: 552))
        p.addCurve(to: CGPoint(x: 254, y: 635), control1: CGPoint(x: 260, y: 595), control2: CGPoint(x: 258, y: 618))
        p.addCurve(to: CGPoint(x: 238, y: 640), control1: CGPoint(x: 250, y: 642), control2: CGPoint(x: 244, y: 644))
        p.addCurve(to: CGPoint(x: 232, y: 588), control1: CGPoint(x: 234, y: 630), control2: CGPoint(x: 232, y: 610))
        p.addCurve(to: CGPoint(x: 236, y: 532), control1: CGPoint(x: 232, y: 565), control2: CGPoint(x: 234, y: 545))
        p.addCurve(to: CGPoint(x: 248, y: 525), control1: CGPoint(x: 238, y: 528), control2: CGPoint(x: 242, y: 524))
        p.closeSubpath(); return p
    }


}
