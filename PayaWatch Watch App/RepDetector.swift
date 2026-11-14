import Foundation

// MARK: - RepDetector (pure logic, no framework dependencies)
//
// Finds sets and counts reps from wrist motion. Input: gravity-free user
// acceleration (g) at a fixed sample rate. Method (kept deliberately simple
// and explainable):
//   1. A set STARTS when smoothed motion energy rises above a threshold and
//      ENDS after a few seconds of stillness.
//   2. For a finished set, take the axis with the most variance and low-pass
//      it (~1.2 Hz) so only the rep-rate component remains — one rep is an
//      up/down cycle, which in raw acceleration has several peaks.
//   3. Find the rep period by autocorrelation, then count peaks spaced by
//      that period. Weak periodicity (walking, fidgeting) → no result.
// Result is a suggestion the user confirms — never logged silently.

struct RepDetector {

    struct Result: Equatable {
        let reps: Int
        let durationSeconds: Double
    }

    let sampleRate: Double
    var startThreshold = 0.10      // g, smoothed magnitude
    var endThreshold = 0.05
    var stillSecondsToEnd = 3.5
    var minSetSeconds = 4.0
    var maxSetSeconds = 150.0
    var minPeriod = 1.5            // s per rep
    var maxPeriod = 7.0
    var minPeriodicity = 0.30      // normalised autocorrelation required

    private var energy = 0.0
    private var quiet = 0
    private var setPeak = 0.0
    private var inSet = false
    private var pre: [[Double]] = []
    private var buf: [[Double]] = []

    init(sampleRate: Double = 25) { self.sampleRate = sampleRate }

    var isInSet: Bool { inSet }

    mutating func reset() {
        energy = 0; quiet = 0; setPeak = 0; inSet = false; pre = []; buf = []
    }

    /// Feed one sample. Returns a result when a set has just ended AND looked
    /// like a real repetitive set.
    mutating func feed(_ ax: Double, _ ay: Double, _ az: Double) -> Result? {
        let m = (ax * ax + ay * ay + az * az).squareRoot()
        energy = 0.9 * energy + 0.1 * m
        let sample = [ax, ay, az]

        if !inSet {
            pre.append(sample)
            if pre.count > Int(sampleRate) { pre.removeFirst() }
            if energy > startThreshold {
                inSet = true
                buf = pre
                quiet = 0
                setPeak = energy
            }
            return nil
        }

        buf.append(sample)
        setPeak = max(setPeak, energy)
        // "Still" = well below how hard this set was, and below an absolute floor.
        quiet = energy < max(endThreshold, 0.25 * setPeak) ? quiet + 1 : 0

        if Double(buf.count) / sampleRate > maxSetSeconds {   // not a set (e.g. a long walk)
            reset()
            return nil
        }
        if Double(quiet) / sampleRate >= stillSecondsToEnd {
            let trimmed = Array(buf.dropLast(quiet))
            reset()
            return analyse(trimmed)
        }
        return nil
    }

    // MARK: Analysis

    func analyse(_ samples: [[Double]]) -> Result? {
        let n = samples.count
        let duration = Double(n) / sampleRate
        guard duration >= minSetSeconds, n > 20 else { return nil }

        // Axis with the most variance.
        var best = 0
        var bestVar = -1.0
        for axis in 0..<3 {
            let xs = samples.map { $0[axis] }
            let mean = xs.reduce(0, +) / Double(n)
            let v = xs.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(n)
            if v > bestVar { bestVar = v; best = axis }
        }
        var x = samples.map { $0[best] }
        let mean = x.reduce(0, +) / Double(n)
        x = x.map { $0 - mean }

        // Double one-pole low-pass at ~1.2 Hz.
        let alpha = 1 - exp(-2 * Double.pi * 1.2 / sampleRate)
        for _ in 0..<2 {
            var y = x[0]
            for i in 0..<n { y += alpha * (x[i] - y); x[i] = y }
        }

        let energy0 = x.reduce(0) { $0 + $1 * $1 }
        guard energy0 > 1e-6 else { return nil }

        // Walking / jogging has a strong fast (step) component that a barbell
        // rep does not: reject when the high-frequency energy dominates.
        let raw = samples.map { $0[best] - mean }
        let highEnergy = zip(raw, x).reduce(0) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) }
        if highEnergy > 1.5 * energy0 { return nil }

        // Autocorrelation → rep period.
        let minLag = Int(minPeriod * sampleRate)
        let maxLag = min(Int(maxPeriod * sampleRate), n / 2)
        guard maxLag > minLag else { return nil }
        var bestLag = 0
        var bestCorr = 0.0
        for lag in minLag...maxLag {
            var c = 0.0
            for i in 0..<(n - lag) { c += x[i] * x[i + lag] }
            let norm = c / energy0
            if norm > bestCorr { bestCorr = norm; bestLag = lag }
        }
        guard bestLag > 0, bestCorr >= minPeriodicity else { return nil }

        // Count peaks spaced by ~the period.
        let peakAbs = x.map(abs).max() ?? 0
        let thr = 0.3 * peakAbs
        let minDist = Int(0.6 * Double(bestLag))
        var peaks: [Int] = []
        for i in 1..<(n - 1) where x[i] > thr && x[i] >= x[i - 1] && x[i] >= x[i + 1] {
            if let last = peaks.last, i - last < minDist {
                if x[i] > x[last] { peaks[peaks.count - 1] = i }
            } else {
                peaks.append(i)
            }
        }
        guard peaks.count >= 2 else { return nil }
        return Result(reps: peaks.count, durationSeconds: duration)
    }
}
