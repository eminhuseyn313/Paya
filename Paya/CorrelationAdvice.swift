import Foundation

enum CorrelationAdvice {

    struct Advice {
        let headline: String
        let actionTip: String
        let category: Category
    }

    enum Category {
        case sleep, training, nutrition, recovery, environment, general
    }

    static func generate(for insight: CorrelationEngine.Insight) -> Advice {
        let a = insight.metricA.id
        let b = insight.metricB.id
        let positive = insight.r > 0
        let strong = abs(insight.r) >= 0.5

        if let specific = specificAdvice(a: a, b: b, positive: positive, strong: strong) {
            return specific
        }
        if let specific = specificAdvice(a: b, b: a, positive: positive, strong: strong) {
            return specific
        }
        return genericAdvice(insight: insight, positive: positive, strong: strong)
    }

    private static func specificAdvice(a: String, b: String, positive: Bool, strong: Bool) -> Advice? {
        switch (a, b) {
        case ("sleep", "energy"):
            return positive
                ? Advice(headline: "Your sleep directly fuels next-day energy", actionTip: "Prioritize 7-9h sleep — your data shows it consistently boosts how you feel.", category: .sleep)
                : Advice(headline: "Unusual: more sleep but less energy", actionTip: "Check sleep quality — long but fragmented sleep can leave you more tired.", category: .sleep)

        case ("deepSleep", "energy"):
            return positive
                ? Advice(headline: "Deep sleep is your energy multiplier", actionTip: "Cool room (18-19°C), no caffeine after 2pm, consistent bedtime — these boost deep sleep the most.", category: .sleep)
                : nil

        case ("sleep", "soreness"):
            return !positive
                ? Advice(headline: "Better sleep = less soreness next day", actionTip: "Your recovery visibly improves with more sleep. On heavy training days, aim for 8+ hours.", category: .recovery)
                : nil

        case ("hrv", "volume"):
            return positive
                ? Advice(headline: "Higher HRV = better training capacity", actionTip: "Track your HRV before training — high-HRV days are when to push volume. Low-HRV days: lighter work.", category: .training)
                : nil

        case ("hrv", "energy"):
            return positive
                ? Advice(headline: "HRV predicts your energy levels", actionTip: "Morning HRV is a reliable readiness signal. Schedule demanding work on high-HRV days.", category: .recovery)
                : nil

        case ("restingHR", "soreness"):
            return positive
                ? Advice(headline: "Elevated resting HR signals incomplete recovery", actionTip: "When resting HR is up, your body is still recovering. Consider a lighter session or active rest.", category: .recovery)
                : nil

        case ("restingHR", "energy"):
            return !positive
                ? Advice(headline: "Lower resting HR = more energy", actionTip: "Consistent cardio and good sleep drive resting HR down over time. Your data confirms the payoff.", category: .recovery)
                : nil

        case ("water", "energy"):
            return positive
                ? Advice(headline: "Hydration boosts your energy", actionTip: "Your energy visibly drops on low-water days. Try front-loading water — 500ml within the first hour of waking.", category: .nutrition)
                : nil

        case ("water", "soreness"):
            return !positive
                ? Advice(headline: "More water = less muscle soreness", actionTip: "Dehydration slows waste clearance from muscles. Keep water intake consistent, especially on training days.", category: .nutrition)
                : nil

        case ("steps", "sleep"):
            return positive
                ? Advice(headline: "Active days lead to better sleep", actionTip: "Daily movement (even walking) improves sleep quality. Aim for most activity before evening.", category: .sleep)
                : !positive
                ? Advice(headline: "Very active days may cost you sleep", actionTip: "Intense late-day activity can delay sleep onset. Try finishing hard exercise 3+ hours before bed.", category: .sleep)
                : nil

        case ("volume", "soreness"):
            return positive
                ? Advice(headline: "Training volume drives next-day soreness", actionTip: "Normal — but if soreness stays above 3/5 for 3+ days, you may be accumulating too much fatigue. Consider a deload.", category: .training)
                : nil

        case ("daylight", "sleep"):
            return positive
                ? Advice(headline: "Daylight exposure improves your sleep", actionTip: "Morning sunlight (10-30 min) sets your circadian rhythm. Your data shows a real effect.", category: .environment)
                : nil

        case ("daylight", "energy"):
            return positive
                ? Advice(headline: "Sunlight exposure lifts your energy", actionTip: "Get outside in the morning — bright light suppresses melatonin and boosts alertness.", category: .environment)
                : nil

        case ("noise", "sleep"):
            return !positive
                ? Advice(headline: "Noise is hurting your sleep", actionTip: "Consider earplugs or a white noise machine — your sleep quality drops measurably on noisy nights.", category: .environment)
                : nil

        case ("meals", "energy"):
            return positive
                ? Advice(headline: "Regular meals keep your energy steady", actionTip: "Skipping meals correlates with energy dips in your data. Even a small meal beats nothing.", category: .nutrition)
                : nil

        case ("supplementAdherence", "energy"):
            return positive
                ? Advice(headline: "Supplements correlate with better energy", actionTip: "Your supplement routine appears to make a measurable difference. Keep the consistency up.", category: .nutrition)
                : nil

        case ("timeOutdoor", "energy"):
            return positive
                ? Advice(headline: "Time outdoors boosts your energy", actionTip: "Nature exposure and fresh air have a real effect on your data. Even 20 minutes helps.", category: .environment)
                : nil

        case ("jointPain", "volume"):
            return positive
                ? Advice(headline: "Training volume aggravates joint pain", actionTip: "Consider reducing volume on exercises that load the affected joint, or swap to a joint-friendlier variation.", category: .training)
                : nil

        case ("pressure", "jointPain"):
            return positive
                ? Advice(headline: "Barometric pressure affects your joints", actionTip: "Low-pressure days (storms) may worsen joint symptoms. Plan lighter sessions when weather shifts.", category: .environment)
                : nil

        default:
            return nil
        }
    }

    private static func genericAdvice(insight: CorrelationEngine.Insight, positive: Bool, strong: Bool) -> Advice {
        let aLabel = insight.metricA.label.lowercased()
        let bLabel = insight.metricB.label.lowercased()

        let headline: String
        let tip: String

        if positive {
            headline = "When your \(aLabel) is higher, \(bLabel) tends to be higher too"
            tip = strong
                ? "This is a strong pattern in your data. Consider whether one drives the other, or if both respond to the same underlying factor."
                : "A moderate link — worth watching over the next few weeks to see if it holds."
        } else {
            headline = "Higher \(aLabel) tends to come with lower \(bLabel)"
            tip = strong
                ? "Strong inverse pattern — when one goes up, the other reliably goes down. Think about which direction serves your goals."
                : "A moderate inverse link. Track whether this trade-off is something you can optimize around."
        }

        return Advice(headline: headline, actionTip: tip, category: .general)
    }
}
