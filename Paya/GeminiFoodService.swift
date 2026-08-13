import Foundation

// MARK: - Gemini Food Service
//
// Free-form food description → estimated protein/calories, via Google's
// Gemini API (generous free tier — gemini-2.0-flash — so this doesn't need
// the paid Claude path the rest of the app's AI features fall back to).
//
// Voice input specifically uses Gemini's audio transcription (see
// transcribe(audioData:apiKey:) below), NOT Apple's on-device
// SFSpeechRecognizer — that framework has a fixed, Apple-controlled list of
// supported languages that excludes Azerbaijani (and others), so no app-side
// fix can make it recognize speech in those languages. Gemini has no such
// restriction.

enum GeminiFoodService {

    struct Estimate {
        let foodName: String
        let proteinG: Double
        let calories: Double
        let confidence: String
        let fatG: Double?
        let carbsG: Double?
        let fiberG: Double?
        let sugarG: Double?
        let sodiumMg: Double?
        let magnesiumMg: Double?
        let zincMg: Double?
        let ironMg: Double?
        let calciumMg: Double?
        let vitaminDMcg: Double?
        let potassiumMg: Double?
        let vitaminCMg: Double?

        func scaled(by fraction: Double) -> Estimate {
            Estimate(
                foodName: foodName,
                proteinG: proteinG * fraction,
                calories: calories * fraction,
                confidence: confidence,
                fatG: fatG.map { $0 * fraction },
                carbsG: carbsG.map { $0 * fraction },
                fiberG: fiberG.map { $0 * fraction },
                sugarG: sugarG.map { $0 * fraction },
                sodiumMg: sodiumMg.map { $0 * fraction },
                magnesiumMg: magnesiumMg.map { $0 * fraction },
                zincMg: zincMg.map { $0 * fraction },
                ironMg: ironMg.map { $0 * fraction },
                calciumMg: calciumMg.map { $0 * fraction },
                vitaminDMcg: vitaminDMcg.map { $0 * fraction },
                potassiumMg: potassiumMg.map { $0 * fraction },
                vitaminCMg: vitaminCMg.map { $0 * fraction }
            )
        }
    }

    enum ServiceError: LocalizedError {
        case noAPIKey
        case noConsent
        case requestFailed(String)
        case unparseable

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "Add a free Gemini API key in Settings to use this."
            case .noConsent: return "Enable \"Allow External AI\" in Settings before using cloud-based food estimation."
            case .requestFailed(let detail): return "Gemini request failed: \(detail)"
            case .unparseable: return "Couldn't read a food estimate from the response — try rephrasing."
            }
        }
    }

    /// Guard: user must consent before any data leaves the device.
    private static func requireConsent() throws {
        guard UserDefaults.standard.bool(forKey: "hasConsentedToExternalAI") else {
            throw ServiceError.noConsent
        }
    }

    // Google periodically retires dated model snapshots from the free tier;
    // "-latest" aliases keep resolving to whatever the current free-tier
    // model is instead of silently losing quota when a dated snapshot ages
    // out.
    private static let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent"

    static func estimate(description: String, apiKey: String) async throws -> Estimate {
        try requireConsent()
        guard !apiKey.isEmpty else { throw ServiceError.noAPIKey }
        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.unparseable
        }

        let system = """
        You are a nutrition estimation assistant. Given a free-text food description \
        (which may be informal, spoken, or missing exact quantities), estimate its \
        nutrition content. The description may be in ANY language, not just English — \
        including regional/local dishes (e.g. Azerbaijani, Turkish, Central Asian, or \
        any other regional cuisine). Use your knowledge of that cuisine's typical \
        ingredients and preparation to estimate accurately; do not default to a generic \
        Western-food guess just because the name is unfamiliar or non-English. Return \
        foodName in the same language/script the user described it in (transliterate \
        only if needed for readability), not translated to English. \
        Use standard nutrition-database values and common portion-size assumptions when \
        the description is vague (state that assumption in the confidence field). \
        Estimate all macronutrients and micronutrients listed below where you can do so \
        with reasonable confidence — omit (null) any you can't estimate reliably rather \
        than guessing. Respond with ONLY a JSON object, no other text, in exactly this shape: \
        {"foodName": "short name", "proteinG": number, "calories": number, \
        "fatG": number or null, "carbsG": number or null, "fiberG": number or null, \
        "sugarG": number or null, "sodiumMg": number or null, \
        "magnesiumMg": number or null, "zincMg": number or null, "ironMg": number or null, \
        "calciumMg": number or null, "vitaminDMcg": number or null, "potassiumMg": number or null, \
        "vitaminCMg": number or null, \
        "confidence": "one short sentence noting any assumption made"}
        """

        guard let url = URL(string: "\(endpoint)?key=\(apiKey)") else {
            throw ServiceError.requestFailed("bad URL")
        }

        let body: [String: Any] = [
            "contents": [
                ["role": "user", "parts": [["text": description]]]
            ],
            "systemInstruction": ["parts": [["text": system]]],
            "generationConfig": ["temperature": 0.2, "responseMimeType": "application/json"]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ServiceError.requestFailed(error.localizedDescription)
        }

        try Self.checkResponse(response, data: data)
        return try parseEstimate(from: data)
    }

    /// Same estimate, from a photo of the plate instead of a typed
    /// description — barcode/label scanning only works for packaged food;
    /// this covers home cooking, restaurant plates, anything with no label
    /// at all. Gemini's multimodal input takes the image inline as base64,
    /// same endpoint as the text path.
    static func estimateFromImage(_ imageData: Data, apiKey: String, userComment: String? = nil) async throws -> Estimate {
        try requireConsent()
        guard !apiKey.isEmpty else { throw ServiceError.noAPIKey }

        let system = """
        You are a nutrition estimation assistant. Given a photo of a plate or \
        container of food, identify what's on it — including regional/local dishes from \
        any cuisine, not only common Western foods — and estimate its total nutrition \
        content. Use your knowledge of that cuisine's typical ingredients and \
        preparation rather than defaulting to a generic guess if the dish looks \
        unfamiliar. Use standard nutrition-database values \
        and reasonable portion-size assumptions from what's visible (state \
        that assumption in the confidence field). If multiple items are on \
        the plate, estimate the combined total. Estimate all macronutrients and \
        micronutrients listed below where you can do so with reasonable confidence — \
        omit (null) any you can't estimate reliably rather than guessing. \
        Respond with ONLY a JSON object, no other text, in exactly this shape: \
        {"foodName": "short name", "proteinG": number, "calories": number, \
        "fatG": number or null, "carbsG": number or null, "fiberG": number or null, \
        "sugarG": number or null, "sodiumMg": number or null, \
        "magnesiumMg": number or null, "zincMg": number or null, "ironMg": number or null, \
        "calciumMg": number or null, "vitaminDMcg": number or null, "potassiumMg": number or null, \
        "vitaminCMg": number or null, \
        "confidence": "one short sentence noting any assumption made"}
        """

        guard let url = URL(string: "\(endpoint)?key=\(apiKey)") else {
            throw ServiceError.requestFailed("bad URL")
        }

        let base64Image = imageData.base64EncodedString()
        var parts: [[String: Any]] = [
            ["inline_data": ["mime_type": "image/jpeg", "data": base64Image]]
        ]
        if let comment = userComment, !comment.isEmpty {
            parts.append(["text": "User note: \(comment)"])
        }
        let body: [String: Any] = [
            "contents": [
                ["role": "user", "parts": parts]
            ],
            "systemInstruction": ["parts": [["text": system]]],
            "generationConfig": ["temperature": 0.2, "responseMimeType": "application/json"]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ServiceError.requestFailed(error.localizedDescription)
        }

        try Self.checkResponse(response, data: data)
        return try parseEstimate(from: data)
    }

    /// Transcribes a short recorded audio clip in whatever language was
    /// spoken — including languages Apple's on-device SFSpeechRecognizer
    /// doesn't support at all (Azerbaijani among them). Returns plain text,
    /// which the caller drops into the same description field a typed
    /// entry would use, so the rest of the food-estimate flow is unchanged.
    static func transcribe(audioData: Data, apiKey: String) async throws -> String {
        try requireConsent()
        guard !apiKey.isEmpty else { throw ServiceError.noAPIKey }

        let system = """
        Transcribe the spoken audio exactly, in whatever language is spoken — do not \
        translate it. Respond with ONLY the transcribed text, nothing else: no quotes, \
        no commentary, no language labels.
        """

        guard let url = URL(string: "\(endpoint)?key=\(apiKey)") else {
            throw ServiceError.requestFailed("bad URL")
        }

        let base64Audio = audioData.base64EncodedString()
        let body: [String: Any] = [
            "contents": [
                ["role": "user", "parts": [
                    ["inline_data": ["mime_type": "audio/mp4", "data": base64Audio]]
                ]]
            ],
            "systemInstruction": ["parts": [["text": system]]],
            "generationConfig": ["temperature": 0.0]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ServiceError.requestFailed(error.localizedDescription)
        }

        try Self.checkResponse(response, data: data)

        guard
            let top = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = top["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else {
            throw ServiceError.unparseable
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let serverDetail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["error"] as? [String: Any] }
                .flatMap { $0["message"] as? String }

            if status == 400 || status == 403 {
                throw ServiceError.requestFailed("invalid API key (HTTP \(status))" + (serverDetail.map { " — \($0)" } ?? ""))
            }
            if status == 429 {
                throw ServiceError.requestFailed("rate limited (HTTP 429)" + (serverDetail.map { " — \($0)" } ?? " — try again shortly"))
            }
            throw ServiceError.requestFailed("HTTP \(status)" + (serverDetail.map { " — \($0)" } ?? ""))
        }
    }

    private static func parseEstimate(from data: Data) throws -> Estimate {
        guard
            let top = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = top["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String,
            let textData = text.data(using: .utf8),
            let parsed = try? JSONSerialization.jsonObject(with: textData) as? [String: Any],
            let foodName = parsed["foodName"] as? String,
            let protein = parsed["proteinG"] as? Double,
            let calories = parsed["calories"] as? Double
        else {
            throw ServiceError.unparseable
        }

        return Estimate(
            foodName: foodName,
            proteinG: protein,
            calories: calories,
            confidence: parsed["confidence"] as? String ?? "",
            fatG: parsed["fatG"] as? Double,
            carbsG: parsed["carbsG"] as? Double,
            fiberG: parsed["fiberG"] as? Double,
            sugarG: parsed["sugarG"] as? Double,
            sodiumMg: parsed["sodiumMg"] as? Double,
            magnesiumMg: parsed["magnesiumMg"] as? Double,
            zincMg: parsed["zincMg"] as? Double,
            ironMg: parsed["ironMg"] as? Double,
            calciumMg: parsed["calciumMg"] as? Double,
            vitaminDMcg: parsed["vitaminDMcg"] as? Double,
            potassiumMg: parsed["potassiumMg"] as? Double,
            vitaminCMg: parsed["vitaminCMg"] as? Double
        )
    }
}
