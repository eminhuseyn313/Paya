import Foundation
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

// MARK: - Image Cache
// Two-tier memory+disk cache with off-thread decoding and target-size downsampling.
// Prevents main-thread stutter when scrolling through many image rows.

@MainActor
class ImageCache {

    static let shared = ImageCache()

    // Memory cache holds already-decoded UIImages ready to draw
    private let memoryCache = NSCache<NSString, UIImage>()

    // Dedupe concurrent requests for the same URL+size
    private var inflightTasks: [String: Task<UIImage?, Never>] = [:]

    private var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("ExerciseImages")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    init() {
        memoryCache.countLimit = 300
        memoryCache.totalCostLimit = 50 * 1024 * 1024   // 50 MB decoded images
    }

    // MARK: - Load

    /// Loads and returns a UIImage decoded at approximately `targetSize` points.
    /// `targetSize.width == 0` means "no downsampling; decode at full size."
    func load(from url: URL, targetSize: CGSize = .zero) async -> UIImage? {
        let cacheKey = "\(url.absoluteString)|\(Int(targetSize.width))x\(Int(targetSize.height))"
        let nsKey = cacheKey as NSString

        // 1. Memory cache — instant hit path
        if let cached = memoryCache.object(forKey: nsKey) {
            return cached
        }

        // 2. Dedupe inflight downloads
        if let existing = inflightTasks[cacheKey] {
            return await existing.value
        }

        // 3. Build a new inflight task
        let task = Task<UIImage?, Never> { [weak self] in
            guard let self = self else { return nil }

            let diskPath = self.diskPath(for: url)

            // Try disk cache
            if let image = await Self.loadFromDisk(
                path: diskPath,
                targetSize: targetSize
            ) {
                 self.storeInMemory(image, forKey: nsKey)
                return image
            }

            // Download
            guard let data = await Self.download(url: url) else {
                return nil
            }

            // Persist original bytes to disk cache
            try? data.write(to: diskPath)

            // Decode + downsample off-thread
            guard let image = await Self.decodeImage(
                from: data,
                targetSize: targetSize
            ) else {
                return nil
            }

            self.storeInMemory(image, forKey: nsKey)
            return image
        }

        inflightTasks[cacheKey] = task
        let result = await task.value
        inflightTasks[cacheKey] = nil
        return result
    }

    private func storeInMemory(_ image: UIImage, forKey key: NSString) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale) * 4
        memoryCache.setObject(image, forKey: key, cost: cost)
    }

    private func diskPath(for url: URL) -> URL {
        let filename = url.absoluteString
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return cacheDirectory.appendingPathComponent(filename)
    }

    // MARK: - Off-thread helpers (nonisolated statics)

    nonisolated static func download(url: URL) async -> Data? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        } catch {
            return nil
        }
    }

    nonisolated static func loadFromDisk(
        path: URL,
        targetSize: CGSize
    ) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard FileManager.default.fileExists(atPath: path.path) else { return nil }
            guard let data = try? Data(contentsOf: path) else { return nil }
            return decodeImageSync(data: data, targetSize: targetSize)
        }.value
    }

    nonisolated static func decodeImage(
        from data: Data,
        targetSize: CGSize
    ) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            decodeImageSync(data: data, targetSize: targetSize)
        }.value
    }

    /// Decodes with optional downsampling. Runs whatever thread caller is on;
    /// callers use it inside a detached Task.
    nonisolated static func decodeImageSync(
        data: Data,
        targetSize: CGSize
    ) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        var options: [CFString: Any] = [
            kCGImageSourceShouldCache: true,
            kCGImageSourceShouldCacheImmediately: true    // force-decode now, not on first draw
        ]

        // Downsample if a target size is provided
        if targetSize.width > 0 {
            // UITraitCollection.current.displayScale is the non-isolated,
            // non-deprecated replacement for UIScreen.main.scale — safe to
            // read from a background/nonisolated context, unlike UIScreen.
            let scale = UITraitCollection.current.displayScale
            let maxDimensionInPixels = max(targetSize.width, targetSize.height) * scale
            options[kCGImageSourceCreateThumbnailFromImageAlways] = true
            options[kCGImageSourceShouldCacheImmediately] = true
            options[kCGImageSourceCreateThumbnailWithTransform] = true
            options[kCGImageSourceThumbnailMaxPixelSize] = maxDimensionInPixels
        }

        let cgImage: CGImage?
        if targetSize.width > 0 {
            cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        } else {
            cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary)
        }

        guard let cg = cgImage else { return nil }
        return UIImage(cgImage: cg)
    }

    // MARK: - Clear (for debugging / Settings)

    func clearAll() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: cacheDirectory)
    }
}

// MARK: - CachedAsyncImage
// Fixed-frame image view that decodes off-thread at target size.
// No layout shift when image loads.

struct CachedAsyncImage: View {
    let url: URL?
    var contentMode: ContentMode = .fit
    var targetSize: CGSize = .zero        // pass nonzero for downsampled thumbnails
    // Bundled illustration (Assets.xcassets) for exercises the free-
    // exercise-db photo dataset never covered — takes priority over the
    // remote URL since there won't be one to fetch.
    var localAssetName: String? = nil

    @State private var loadedImage: UIImage? = nil

    var body: some View {
        ZStack {
            Pulse.surfaceElevatedFallback

            if let localAssetName {
                Image(localAssetName)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .padding(targetSize == .zero ? 0 : targetSize.width * 0.15)
            } else if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .task(id: url) {
            guard localAssetName == nil else { return }
            loadedImage = nil
            guard let url = url else { return }
            loadedImage = await ImageCache.shared.load(from: url, targetSize: targetSize)
        }
    }
}
