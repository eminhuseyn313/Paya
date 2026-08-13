import Foundation
import Vision
import UIKit

// MARK: - Parsed Nutrition Label
// Best-effort extraction from a photographed nutrition facts panel. On-device
// only (Vision text recognition) — no network call, no API cost.

struct ParsedNutritionLabel: Identifiable {
    let id = UUID()
    var calories: Double?
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var servingSize: String?
    var rawText: String

    var hasAnyValue: Bool {
        calories != nil || proteinG != nil || carbsG != nil || fatG != nil
    }
}

enum NutritionLabelParser {

    /// Runs on-device OCR over a photographed label and extracts macro values.
    static func parse(image: UIImage) async -> ParsedNutritionLabel? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observations = request.results else { return nil }

        // Vision orders observations top-to-bottom, left-to-right by default,
        // which matches how nutrition labels are laid out.
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        let fullText = lines.joined(separator: "\n")
        let normalized = fullText.lowercased()

        var result = ParsedNutritionLabel(rawText: fullText)
        result.calories = firstNumber(after: "calories", in: normalized, maxGapChars: 12)
        result.proteinG = firstGramValue(after: "protein", in: normalized)
        result.carbsG = firstGramValue(after: "total carbohydrate", in: normalized)
            ?? firstGramValue(after: "carbohydrate", in: normalized)
            ?? firstGramValue(after: "carbs", in: normalized)
        result.fatG = firstGramValue(after: "total fat", in: normalized)
            ?? firstGramValue(after: "fat", in: normalized)
        result.servingSize = servingSize(in: lines)

        return result.hasAnyValue ? result : nil
    }

    // MARK: - Extraction helpers

    private static func firstNumber(after keyword: String, in text: String, maxGapChars: Int) -> Double? {
        guard let range = text.range(of: keyword) else { return nil }
        let tail = text[range.upperBound...]
        let window = tail.prefix(maxGapChars + 10)
        return firstDouble(in: String(window))
    }

    private static func firstGramValue(after keyword: String, in text: String) -> Double? {
        guard let range = text.range(of: keyword) else { return nil }
        let tail = text[range.upperBound...]
        // Look within a short window for "<number> g" (allow a colon/space in between).
        let window = String(tail.prefix(20))
        guard let match = window.range(of: #"\d+(\.\d+)?\s*g\b"#, options: .regularExpression) else {
            return firstDouble(in: window)
        }
        return firstDouble(in: String(window[match]))
    }

    private static func firstDouble(in text: String) -> Double? {
        guard let match = text.range(of: #"\d+(\.\d+)?"#, options: .regularExpression) else { return nil }
        return Double(text[match])
    }

    private static func servingSize(in lines: [String]) -> String? {
        lines.first { $0.lowercased().contains("serving size") }
    }
}
