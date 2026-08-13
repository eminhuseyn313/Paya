# Paya — App Store Metadata

Use this when filling out App Store Connect.

---

## App Name
Paya — Fitness Tracker

## Subtitle (30 chars max)
Train Smart. Recover Smarter.

## Category
Primary: Health & Fitness
Secondary: Lifestyle

## Price
Free (with In-App Purchase: Paya Pro — Lifetime $14.99)

## Privacy Policy URL
https://eminhuseyn313.github.io/Paya/privacy

## Terms of Service URL
https://eminhuseyn313.github.io/Paya/terms

## Support URL
mailto:eminhuseyn313@gmail.com

---

## Description (4000 chars max)

Paya is a science-backed fitness companion that brings together workout tracking, nutrition logging, health analytics, and AI coaching — all in one app.

Unlike subscription-heavy competitors, Paya offers a generous free tier and a one-time Pro upgrade. No monthly fees, ever.

TRAIN WITH PURPOSE
• Log workouts with exercise library (250+ exercises with demo images)
• Track sets, reps, weight, RPE, and rest times
• Science-based program generation (PPL, Upper/Lower, Full Body)
• Progressive overload tracking and plateau detection
• Estimated 1RM calculations (Epley, Brzycki formulas)
• ACWR (acute:chronic workload ratio) monitoring
• Volume alerts for overtraining or detraining
• Live heart rate via Bluetooth HR monitors

EAT WITH CLARITY
• AI-powered food estimation — type, speak, or photograph a meal
• Barcode scanning via OpenFoodFacts
• Full macro + micronutrient tracking (14 nutrients)
• Personalized calorie targets based on your goal and activity
• Meal templates for quick logging
• Supports any cuisine and language

RECOVER WITH DATA
• Apple Health integration (sleep, steps, heart rate, HRV)
• Readiness score based on HRV, RHR, and sleep quality
• Sleep debt tracking with recovery recommendations
• Soreness mapping by muscle group
• Morning check-in for daily wellness tracking
• Symptom and flare-day logging for chronic conditions

UNDERSTAND YOUR BODY
• Correlation engine linking sleep, nutrition, and performance
• Body recomposition tracking (weight + strength trends)
• Progress photos with timeline view
• Weekly AI-powered coaching digest
• Personal health narrative and trend analysis
• Blood pressure, medication, and supplement tracking

APPLE WATCH
• Readiness glance with circular score ring
• Live workout tracking with heart rate
• Water logging
• Guided breathwork (4s-in/6s-out with HRV measurement)
• Quick morning check-in from your wrist

PRIVACY FIRST
• All data stored locally on your device
• No analytics, no ads, no tracking
• API keys stored in iOS Keychain
• Optional AI features require your own API key
• Explicit consent required before any data leaves your device

PAYA PRO (one-time $14.99)
• AI coaching and weekly digest
• Advanced analytics and correlations
• Unlimited history
• Progress photos
• Data export

Built for people who take training seriously but don't want to pay $30/month for it.

---

## Keywords (100 chars max, comma-separated)

fitness,workout,tracker,nutrition,calories,protein,health,gym,strength,training,recovery,AI,coaching

---

## Promotional Text (170 chars, can be updated without review)

Science-backed workout tracking, AI nutrition analysis, and recovery insights — no subscription required. One-time Pro upgrade, your data stays on your device.

---

## App Store Review Notes

Paste this in the "Notes for Review" field in App Store Connect:

```
DEMO ACCOUNT / SETUP
No login required — Paya stores everything locally on-device.
Launch the app → complete the 8-step onboarding (takes ~60 seconds with any values).

TESTING IN-APP PURCHASE
The app uses StoreKit 2 for a non-consumable "Paya Pro — Lifetime" ($14.99).
Product ID: com.paya.pro.lifetime
In sandbox, you can test purchase and restore using a sandbox Apple ID.

AI FEATURES
AI coaching features require the user's own API key (Anthropic Claude or Google Gemini).
The app does NOT provide or bundle any API keys.
Users must also enable "Allow External AI" in Settings → AI Data Sharing before data is sent externally.
Apple Intelligence (on-device) works without any API key or consent toggle.

HEALTH DATA
The app reads HealthKit data (steps, heart rate, sleep, weight) to provide recovery scoring and training recommendations.
The app writes completed workouts and body weight entries back to HealthKit.
HealthKit data is never shared with third parties (except when the user explicitly uses AI features with consent enabled).

PROMO CODES
The app includes a promo code system for press/review access.
Codes are stored as SHA-256 hashes — no plaintext codes exist in the binary.
This is separate from App Store promo codes.

HEALTH DISCLAIMER
A health disclaimer is shown during onboarding (final step) and in Settings.
The app is a fitness tracker, not a medical device (per Guideline 5.3.3).

BLUETOOTH
The app connects to Bluetooth heart rate monitors during workouts.
Background Bluetooth is declared for live HR during active sessions only.

LOCATION
Location is used only to fetch weather/UV data from Open-Meteo (open-source, no tracking).
The app does not store location history.
```

---

## Screenshot Requirements

You need screenshots for these device sizes:
1. **iPhone 16 Pro Max** (6.9") — 1320 × 2868 px — REQUIRED
2. **iPhone 16 Pro** (6.3") — 1206 × 2622 px — or use 6.9" scaled
3. **iPad Pro 13"** (if supporting iPad) — 2064 × 2752 px

Recommended screenshot sequence (5-8 screenshots):
1. Dashboard / Readiness score — "Your morning at a glance"
2. Workout logging — "Track every set with science"
3. Nutrition / food photo — "Snap a photo, get the macros"
4. Analytics / correlations — "See what moves the needle"
5. Apple Watch — "Recovery insights on your wrist"
6. Progress photos / body recomp — "Track real progress"
7. AI coaching digest — "Coaching that knows your data"
8. Paywall — "One price. Forever."

---

## Age Rating Questionnaire

- Unrestricted Web Access: No
- Gambling / Contests: No
- Medical/Treatment Information: No (fitness tracking only)
- Profanity or Crude Humor: No
- Alcohol, Tobacco, or Drug Use: No
- Simulated Gambling: No
- Horror/Fear Themes: No
- Sexual Content: No (body photos are user's own progress photos)
- Graphic Violence: No

**Result: 4+ rating**

---

## App Privacy (Nutrition Labels)

In App Store Connect → App Privacy:

**Data Linked to You: None** (all data is on-device)

**Data Used to Track You: None**

**Data types collected:**
- Health & Fitness → used for App Functionality → not linked to identity
- Fitness → used for App Functionality → not linked to identity
- Body → used for App Functionality → not linked to identity  
- Photos → used for App Functionality → not linked to identity
- Precise Location → used for App Functionality → not linked to identity
- Name → used for App Functionality → not linked to identity

All "Not Linked to You" because there's no account system / no server / no way to tie data to an identity.
