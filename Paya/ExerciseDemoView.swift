import SwiftUI
import AVKit
import Combine

// MARK: - Exercise Demo View
// Primary visual: a looping cross-fade through the matched library
// exercise's real form photos (from the 873-exercise database). Falls back
// to a video URL if one is ever set, then to a clean placeholder.

struct ExerciseDemoView: View {

    var exerciseName: String
    var urlString: String? = nil
    var muscleGroup: String
    var sessionColor: Color
    var height: CGFloat = 220

    @State private var player: AVPlayer? = nil
    @State private var matched: Exercise? = nil
    @State private var frameIndex: Int = 0
    @State private var loadFailed = false
    @State private var isLoading = true

    private let frameTimer = Timer.publish(every: 1.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(sessionColor.opacity(0.08))
                .frame(height: height)

            if let player, !loadFailed {
                VideoPlayer(player: player)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .disabled(true)
                    .allowsHitTesting(false)
            } else if let matched, let assetName = matched.localIllustrationAssetName {
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: height)
                    .padding(28)
            } else if let matched, !matched.imageURLs.isEmpty {
                imageLoop(matched.imageURLs)
            } else if isLoading {
                VStack(spacing: 10) {
                    ProgressView()
                        .tint(sessionColor)
                    Text("Loading demo…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                FallbackIllustration(
                    muscleGroup: muscleGroup,
                    sessionColor: sessionColor
                )
            }
        }
        .frame(height: height)
        .onAppear { setup() }
        .onDisappear { teardown() }
        .onReceive(frameTimer) { _ in
            guard let matched, matched.imageURLs.count > 1 else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                frameIndex = (frameIndex + 1) % matched.imageURLs.count
            }
        }
    }

    // MARK: - Image loop

    @ViewBuilder
    private func imageLoop(_ urls: [URL]) -> some View {
        AsyncImage(url: urls[frameIndex % urls.count]) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .id(frameIndex)
                    .transition(.opacity)
            case .empty:
                ProgressView().tint(sessionColor)
            case .failure:
                FallbackIllustration(muscleGroup: muscleGroup, sessionColor: sessionColor)
            @unknown default:
                FallbackIllustration(muscleGroup: muscleGroup, sessionColor: sessionColor)
            }
        }
    }

    // MARK: Setup

    private func setup() {
        // Legacy path: a real video URL, if one is ever supplied.
        if let urlString, let url = URL(string: urlString) {
            setupPlayer(url: url)
            return
        }

        // Primary path: match against the bundled exercise library for real photos.
        Task {
            ExerciseDatabase.shared.loadIfNeeded()
            for _ in 0..<20 where !ExerciseDatabase.shared.isLoaded {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            await MainActor.run {
                matched = ExerciseLibraryMatcher.match(name: exerciseName)
                isLoading = false
                loadFailed = matched == nil
            }
        }
    }

    private func setupPlayer(url: URL) {
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.isMuted = true
        newPlayer.actionAtItemEnd = .none

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            newPlayer.seek(to: .zero)
            newPlayer.play()
        }

        Task {
            do {
                let status = try await asset.load(.isPlayable)
                await MainActor.run {
                    if status {
                        player = newPlayer
                        newPlayer.play()
                        isLoading = false
                    } else {
                        loadFailed = true
                        isLoading = false
                        setup2FallbackToLibrary()
                    }
                }
            } catch {
                await MainActor.run {
                    loadFailed = true
                    isLoading = false
                    setup2FallbackToLibrary()
                }
            }
        }
    }

    /// If a supplied video URL fails, still try the library match rather than giving up.
    private func setup2FallbackToLibrary() {
        Task {
            ExerciseDatabase.shared.loadIfNeeded()
            for _ in 0..<20 where !ExerciseDatabase.shared.isLoaded {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            await MainActor.run {
                matched = ExerciseLibraryMatcher.match(name: exerciseName)
                loadFailed = matched == nil
            }
        }
    }

    private func teardown() {
        player?.pause()
        player = nil
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Fallback Illustration

struct FallbackIllustration: View {
    var muscleGroup: String
    var sessionColor: Color

    var icon: String {
        switch muscleGroup.lowercased() {
        case let g where g.contains("chest"): return "figure.strengthtraining.functional"
        case let g where g.contains("back"): return "figure.rower"
        case let g where g.contains("leg") || g.contains("ham"): return "figure.strengthtraining.traditional"
        case let g where g.contains("shoulder") || g.contains("delt"): return "figure.arms.open"
        case let g where g.contains("bicep") || g.contains("tricep") || g.contains("arm"): return "figure.boxing"
        case let g where g.contains("calf"): return "figure.run"
        default: return "dumbbell.fill"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(sessionColor.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundColor(sessionColor)
            }

            VStack(spacing: 3) {
                Text(muscleGroup)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Text("No form photos matched yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
