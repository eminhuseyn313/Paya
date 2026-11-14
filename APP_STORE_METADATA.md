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

Paya brings your training, nutrition and recovery into one calm place — and it starts working the moment you open it.

TRAIN
• Log sets, reps and weight with a fast, gym-friendly screen and a smart rest timer
• Customizable A/B/C programs, exercise library with muscle-map illustrations
• Progressive overload suggestions in real gym increments (2.5 / 5 kg)
• Volume, personal records and history at a glance
• Apple Watch companion: log sets from your wrist, live heart rate

EAT
• Log meals with calories, protein, carbs and fat
• Barcode scanner and food search
• Macro targets that adapt to training and rest days
• Water and supplement tracking

RECOVER
• Apple Health sleep, heart rate, HRV and steps feed a readiness score — with the reason shown
• Body weight and measurement trends, progress photos
• Optional symptom, soreness and medication-reminder tracking

YOURS
• Works without an account. Create one to back up and restore on a new phone
• Sign in with Apple supported
• No ads, no tracking, no analytics SDKs
• Delete your account and cloud data any time from Settings

Paya is a wellness and fitness tool, not a medical device, and does not provide medical advice.

Paya Pro is a one-time purchase that unlocks advanced analytics, unlimited history, progress photos and data export. No subscription.

---

**Keywords (100 chars max, comma-separated):**

```
fitness,workout,tracker,nutrition,calories,protein,health,gym,training,weightlifting,recovery,AI
```

---

**Promotional Text (170 chars, can be updated without review):**

```
Train, eat and recover with one app. Log workouts fast, track macros, and see a readiness score built from your Apple Watch data. One-time Pro upgrade, no subscription.
```

---

**What's New (for v1.0.0):**

```
Welcome to Paya!

• Fast workout logging with smart rest timer and progressive overload
• Nutrition logging with barcode scanner and macro targets
• Apple Health + Apple Watch readiness and recovery insights
• Sign in with Apple, cloud backup and restore
• One-time Pro upgrade — no subscriptions
```

---

## App Review Information

**Sign-in required:** Yes (optional account). The app is fully usable without an account via "Continue without an account"; an account enables cloud backup/restore.

**Demo account** (create it first — see docs/release-review/DEMO_ACCOUNT.md):
- Username: `review@<your-domain>`  ← replace
- Password: `<generated password>`  ← replace

**Review Notes:**

```
Paya is a fitness, nutrition and wellness tracker. It is not a medical device.

1. ACCOUNT: Use the demo account above, or tap "Continue without an account". Sign in with Apple is also offered. Delete Account is in Settings → Account (permanent; removes cloud data).

2. HEALTHKIT: Reads sleep, steps, heart rate, HRV, resting HR, respiratory rate, blood oxygen, wrist temperature and weight to compute a readiness score and trends. Writes body weight and workouts. Background delivery is used only for step-milestone notifications. The app works without Health access (manual logging).

3. IN-APP PURCHASE: One non-consumable, "Paya Pro — Lifetime". Free tier includes full workout and nutrition tracking. Use a sandbox account to test; "Restore Purchases" is in the paywall.

4. BLUETOOTH: Optional, for BLE heart-rate straps during workouts (central role).

5. CAMERA/PHOTOS: Barcode and nutrition-label scanning; progress photos stored on-device.

6. LOCATION: When-in-use only for local weather/UV/air-quality context. An optional, off-by-default "air quality alerts" setting uses Always location to notify when air quality is poor.

7. NETWORK: Supabase (account + backup), Open-Meteo (weather/air quality), OpenFoodFacts and USDA (food data), OpenStreetMap (place names), GitHub raw (exercise images). No analytics, advertising or tracking SDKs. External AI features are not included in this version.

8. HEALTH CLAIMS: Scores, forecasts and flare-risk figures are informational estimates and are labelled as not medical advice in onboarding, Settings and on the screens that show them.
```

**Contact:** eminhuseyn313@gmail.com

---

## App Privacy (Nutrition Labels)

Declare in App Store Connect → App Privacy. Paya does not track users. Everything below is **Linked to You** (it syncs to an account), used for **App Functionality** only, **not used for tracking**:

| Data Type (Apple category) | Notes |
|---|---|
| Contact Info → Email Address | account |
| Identifiers → User ID | account id |
| Health & Fitness → Health, Fitness | HealthKit-derived + logs |
| Body → (weight, height, measurements) under Health & Fitness/Sensitive Info | profile and trends |
| Sensitive Info → health conditions entered by the user | symptoms, medications |
| Photos or Videos | progress photos (on-device; declare if ever synced) |
| Location → Precise & Coarse | weather/air quality (sent to Open-Meteo, not stored) |
| User Content → Other User Content | notes, logs |
| Purchases → Purchase History | Pro status via StoreKit |

Audio is NOT collected in this version (voice logging is hidden).

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

Host the `website/` folder (see docs/release-review/HOSTING.md) and use:

| Field | URL |
|-------|-----|
| Privacy Policy | https://eminhuseyn313.github.io/Paya/privacy.html |
| Terms of Use | https://eminhuseyn313.github.io/Paya/terms.html |
| Support URL | https://eminhuseyn313.github.io/Paya/support.html |
| Marketing URL | https://eminhuseyn313.github.io/Paya/ (optional) |

The same URLs must be reachable from the in-app Settings → Privacy Policy / Terms rows (currently in-app text; keep it in sync with website/privacy.html).
