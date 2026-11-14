import Foundation

/// Release feature switches. v1 ships WITHOUT features that need the user to
/// paste a third-party API key (App Review can't exercise them, and they send
/// data to external AI providers). Flip to true in v1.1 once a managed
/// server-side AI proxy with consent + rate limits exists.
enum FeatureFlags {
    static let externalAI = false
}
