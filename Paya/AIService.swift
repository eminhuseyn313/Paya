import Foundation
import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - AI Service
// Unified interface for AI features. Routes to Apple Intelligence on supported
// devices (iOS 18.1+, iPhone 15 Pro and newer), falls back to Claude API otherwise.

@MainActor
@Observable
class AIService {

    static let shared = AIService()

    var lastError: String? = nil

    // MARK: - Capability check

    var isAppleIntelligenceAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            return model.availability == .available
        }
        #endif
        return false
    }

    var providerName: String {
        isAppleIntelligenceAvailable ? "Apple Intelligence" : "Claude"
    }

    var providerIcon: String {
        isAppleIntelligenceAvailable ? "apple.logo" : "sparkles"
    }

    // MARK: - Generate

    /// Routes to the best available AI provider.
    /// - Parameters:
    ///   - system: System prompt / personality
    ///   - userMessage: The user's question
    ///   - apiKey: Claude API key
    ///   - requiresReasoning: Set true for tasks that must correctly
    ///     synthesize several structured facts into a coherent, specific
    ///     recommendation (e.g. "these 3 lifts stalled, this muscle is
    ///     under-volume, a deload is due — write a coaching note that
    ///     references the actual numbers"). Apple's on-device
    ///     SystemLanguageModel (~3B params) is built and documented for
    ///     lightweight text transformation — summarizing, rewriting tone,
    ///     proofreading — not open-ended multi-fact reasoning, and visibly
    ///     produces vaguer or occasionally incorrect output on that class of
    ///     task. When true and a Claude key is configured, Claude is tried
    ///     first and on-device is only the fallback if no key exists —
    ///     inverting the normal on-device-first preference for the tasks
    ///     where correctness matters more than the (real) privacy/cost
    ///     benefit of staying on-device.
    /// - Returns: Generated text or nil on failure
    /// Whether the user has consented to sending data to external AI APIs.
    /// Checked before every external call. On-device Apple Intelligence
    /// bypasses this — data never leaves the device.
    var externalAIAllowed: Bool {
        UserDefaults.standard.bool(forKey: "hasConsentedToExternalAI")
    }

    func generate(
        system: String,
        userMessage: String,
        apiKey: String,
        requiresReasoning: Bool = false
    ) async -> String? {

        if requiresReasoning && !apiKey.isEmpty && externalAIAllowed {
            if let result = await generateWithClaude(system: system, userMessage: userMessage, apiKey: apiKey) {
                return result
            }
            // Claude failed (network, rate limit) — on-device is a better
            // fallback than nothing even for a reasoning-heavy task.
        }

        // Try Apple Intelligence first (on-device — no consent needed)
        if isAppleIntelligenceAvailable {
            if let result = await generateWithAppleIntelligence(
                system: system,
                userMessage: userMessage
            ) {
                return result
            }
        }

        // Fall back to Claude API — requires explicit consent
        guard externalAIAllowed else {
            lastError = "AI data sharing is not enabled. Turn on \"Allow External AI\" in Settings to use cloud-based AI features."
            return nil
        }

        guard !apiKey.isEmpty else {
            lastError = "AI is unavailable on this device. Add your Claude API key in Settings to use AI features, or update to a newer iPhone with Apple Intelligence."
            return nil
        }

        return await generateWithClaude(
            system: system,
            userMessage: userMessage,
            apiKey: apiKey
        )
    }

    // MARK: - Apple Intelligence

    private func generateWithAppleIntelligence(
        system: String,
        userMessage: String
    ) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession(instructions: system)
                let response = try await session.respond(to: userMessage)
                return response.content
            } catch {
                lastError = "Apple Intelligence error: \(error.localizedDescription)"
                return nil
            }
        }
        #endif
        return nil
    }

    // MARK: - Claude API

    private func generateWithClaude(
        system: String,
        userMessage: String,
        apiKey: String
    ) async -> String? {
        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1000,
            "system": system,
            "messages": [["role": "user", "content": userMessage]]
        ]

        guard let url = URL(string: "https://api.anthropic.com/v1/messages"),
              let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            lastError = "Couldn't build the request."
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let apiMessage = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                    .flatMap { $0["error"] as? [String: Any] }
                    .flatMap { $0["message"] as? String }
                switch http.statusCode {
                case 401:
                    lastError = "That Claude API key was rejected — check it in Settings."
                case 429:
                    lastError = "Claude API rate limit hit — try again in a moment."
                default:
                    lastError = apiMessage ?? "Claude API returned an error (\(http.statusCode))."
                }
                return nil
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let text = content.first?["text"] as? String else {
                lastError = "Got an unexpected response shape back from Claude."
                return nil
            }
            return text
        } catch {
            lastError = "Network error: \(error.localizedDescription)"
            return nil
        }
    }
}
