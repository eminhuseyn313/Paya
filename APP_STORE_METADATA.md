# Paya — App Store Connect Metadata

Everything you need to fill in App Store Connect for submission.

---

## App Information

- **App Name:** Paya
- **Subtitle:** Training, nutrition & health
- **Bundle ID:** Paya.Paya
- **SKU:** paya-fitness-2026
- **Primary Language:** English (U.S.)
- **Category:** Health & Fitness
- **Secondary Category:** Lifestyle
- **Content Rights:** Does not contain third-party content that requires rights
- **Age Rating:** 4+ (no objectionable content)

---

## Pricing

- **Price:** Free (Freemium)
- **In-App Purchase:** "Paya Pro — Lifetime" — $14.99 (Non-Consumable)
- **Availability:** All territories

---

## Version Information

- **Marketing Version:** 1.0.0
- **Build Number:** 1

---

## App Description

**Description (4000 chars max):**

Paya is a personal fitness companion that tracks your training, nutrition, and health — all in one place, all on your device.

No subscriptions. No cloud accounts. No data harvesting. Just a focused tool that helps you get stronger, eat better, and understand your body.

TRAINING
• Log workouts with sets, reps, and weights — fully customizable A/B/C programs
• Smart rest timer with heart rate recovery tracking (Bluetooth HR monitors)
• Progressive overload tracking with precise weight increments (0.5kg/1.25lb)
• Warm-up builder based on your working weights
• Session history with volume, tonnage, and PR tracking

NUTRITION
• Meal logging with calories, protein, carbs, and fat
• Barcode scanner with OpenFoodFacts database
• AI-powered meal analysis — photograph your plate for instant estimates
• Macro targets that adjust for training vs rest days
• Supplement timing tracker

HEALTH & RECOVERY
• Apple HealthKit integration — sleep, steps, heart rate, weight
• Readiness scoring based on sleep, HRV, and training load
• Symptom tracking and correlation analysis
• Body measurements and progress photos
• Daily routines — UV-based sunscreen reminders, hydration, and more

AI COACHING (Pro)
• Personalized training recommendations
• Weekly health digest with actionable insights
• Nutrition suggestions based on your goals and logged data
• Powered by your own API key (Claude or Gemini) — your data, your key

PRIVACY FIRST
• All data stored locally on your device
• No accounts, no cloud sync, no analytics SDKs
• API keys stored in the iOS Keychain
• Your data never leaves your phone unless you explicitly use AI features

Paya Pro unlocks AI coaching, advanced analytics, unlimited history, daily routines, progress photos, and data export — all for a one-time $14.99 purchase. No subscription, ever.

---

**Keywords (100 chars max, comma-separated):**

```
fitness,workout,tracker,nutrition,calories,protein,health,gym,training,weightlifting,recovery,AI
```

---

**Promotional Text (170 chars, can be updated without review):**

```
Track training, nutrition & health — all on-device, no subscription. Upgrade once to Pro for AI coaching and advanced analytics.
```

---

**What's New (for v1.0.0):**

```
Welcome to Paya! Your personal fitness companion is here.

• Full workout tracking with smart rest timer and progressive overload
• Nutrition logging with barcode scanner and AI meal analysis
• HealthKit integration for sleep, steps, heart rate, and weight
• Readiness scoring and recovery insights
• Daily routine reminders with UV-based sunscreen alerts
• Optional AI coaching powered by Claude or Gemini
• One-time Pro upgrade — no subscriptions
```

---

## App Review Information

**Review Notes:**

```
Paya is a personal fitness and health tracking app. Here's what reviewers should know:

1. HEALTHKIT: The app reads sleep, steps, heart rate, active energy, and body weight from HealthKit to power readiness scoring and health insights. It writes body weight and workouts back. All HealthKit usage descriptions are in Info.plist.

2. AI FEATURES: AI coaching is optional and requires the user to provide their own API key (Anthropic Claude or Google Gemini) in Settings. The app does not include or bundle any API keys. Without an API key, the app works fully — AI features simply show "Set up API key in Settings" prompts.

3. IN-APP PURCHASE: One non-consumable IAP — "Paya Pro — Lifetime" at $14.99. Unlocks AI coaching, advanced analytics, unlimited history, daily routines, progress photos, and data export. The free tier includes full workout tracking, basic nutrition logging, and HealthKit sync.

4. BLUETOOTH: Used for connecting to Bluetooth Low Energy heart rate monitors (chest straps, arm bands). The app acts as a BLE central.

5. CAMERA: Used for barcode scanning (nutrition lookup via OpenFoodFacts) and meal photography (AI calorie estimation). Also used for progress photos.

6. LOCATION: Used only to fetch local weather/UV data from Open-Meteo (free, open-source API) for sunscreen reminders. Location is not stored or transmitted elsewhere.

7. DATA PRIVACY: All personal data is stored locally using SwiftData. No analytics SDKs, no crash reporting services, no advertising. API keys are stored in the iOS Keychain.

8. NETWORK CALLS: 
   - Open-Meteo (weather/UV) — no API key needed
   - OpenFoodFacts (barcode lookup) — no API key needed  
   - Anthropic API / Google Gemini — user-provided API key
   - GitHub raw content — exercise demonstration images

Test account: Not needed — the app has no login/account system.
```

**Contact:** eminhuseyn313@gmail.com

---

## App Privacy (Nutrition Labels)

Fill these in App Store Connect under "App Privacy":

### Data Used to Track You
**None** — Paya does not track users.

### Data Linked to You
**None** — no accounts, no user identification.

### Data Not Linked to You

| Data Type | Purpose |
|-----------|---------|
| Health & Fitness | App Functionality |
| Body (weight, height, measurements) | App Functionality |
| Photos (progress photos, meal camera) | App Functionality |
| Precise Location | App Functionality (weather/UV only) |
| Name (profile first name) | App Functionality |
| Usage Data (exercise selection patterns) | App Functionality |

---

## Screenshots Needed

Prepare screenshots for:
- **iPhone 6.9"** (iPhone 16 Pro Max) — required
- **iPhone 6.7"** (iPhone 15 Plus) — required  
- **iPhone 6.5"** (iPhone 11 Pro Max) — optional but recommended
- **iPad 13"** — if supporting iPad

**Recommended screenshot flow (5-8 screens):**
1. Dashboard / Home — readiness score + daily summary
2. Training session — active workout with rest timer
3. Nutrition tracking — meal logging with macros
4. Health overview — sleep, steps, HR charts
5. Progress — body weight chart + strength gains
6. AI coaching insight (Pro badge)
7. Paywall / Pro features overview

---

## URLs Required

| Field | URL | Status |
|-------|-----|--------|
| Privacy Policy | https://getpaya.app/privacy | ⚠️ Need to host |
| Terms of Service | https://getpaya.app/terms | ⚠️ Need to host |
| Support URL | mailto:eminhuseyn313@gmail.com | ✅ Ready |
| Marketing URL | https://getpaya.app | ⚠️ Optional |

**Quick hosting option:** Create a free GitHub Pages site at `yourusername.github.io/paya` with the privacy policy and terms text from LegalDocuments.swift.

---

## Pre-Submission Checklist

- [x] PrivacyInfo.xcprivacy created
- [x] StoreKit configuration created
- [x] PurchaseManager + PaywallView implemented
- [x] Privacy Policy + Terms of Service (in-app)
- [x] health-records entitlement removed (was unused)
- [x] FamilyControls wrapped in #if canImport
- [x] Legal links in Settings
- [x] Restore purchase in Settings
- [x] App review notes prepared
- [x] Privacy nutrition labels documented
- [ ] Host privacy policy + terms at public URLs
- [ ] Create App Store screenshots
- [ ] Register app in App Store Connect
- [ ] Create IAP "com.paya.pro.lifetime" in App Store Connect
- [ ] Upload build via Xcode (requires paid Apple Developer account)
- [ ] Fill in App Privacy in App Store Connect
- [ ] Submit for review
