# Paya Notification Center Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a profile-specific, actionable in-app notification center that integrates Paya's existing training, flare-risk, and milestone alerts.

**Architecture:** SwiftData stores durable inbox records. `NotificationManager` remains the central local-notification gateway, while a lightweight app router maps notification actions to the current tab. The dashboard owns the bell and presents the inbox sheet.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, UserNotifications, Xcode project target `Paya`.

## Global Constraints

- Keep the current iOS local-notification behavior compatible with existing Training Reminders and Pre-flare Alerts settings.
- Scope every stored notification to its `profileId`.
- An inbox record must be created even when iOS notification permission is denied.
- Do not add dependencies, remote push services, or server sync.
- Avoid automatic new meal, hydration, recovery, weigh-in, supplement, and rest-timer scheduling in this release; expose their categories in the foundational model only.

---

### Task 1: Add durable notification domain models and store

**Files:**
- Create: `Paya/NotificationRecord.swift`
- Modify: `Paya/PayaApp.swift`

**Interfaces:**
- Produces: `NotificationCategory`, `NotificationDestination`, `NotificationRecord`, and `NotificationCenterStore`.
- Produces: `NotificationCenterStore.createIfNeeded(_:context:) -> NotificationRecord?`, `unreadCount(profileId:context:) -> Int`, `markRead(_:context:)`, `markAllRead(profileId:context:)`, and `delete(_:context:)`.
- Consumes: `ActiveProfile.id`, `ModelContext`, and the existing `PersonProfile` profile identifier convention.

- [ ] **Step 1: Build the Paya target before changing code**

Run: `xcodebuild -project Paya.xcodeproj -scheme Paya -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO`

Expected: the build establishes the baseline compiler state. If the local Xcode runtime is unavailable, record its exact failure and use source-level validation after each task.

- [ ] **Step 2: Create the notification domain model**

Create `Paya/NotificationRecord.swift` with:

```swift
enum NotificationCategory: String, Codable, CaseIterable, Identifiable {
    case training, meal, supplement, hydration, recovery, weighIn, milestone, flareRisk, restTimer
    var id: String { rawValue }
}

enum NotificationDestination: String, Codable {
    case home, train, nutrition, health, progress, settings
}

@Model
final class NotificationRecord {
    @Attribute(.unique) var id: UUID
    var profileId: UUID?
    var categoryRaw: String
    var title: String
    var message: String
    var createdAt: Date
    var readAt: Date?
    var destinationRaw: String?
    var deduplicationKey: String?
}
```

Add computed category/destination accessors and a `NotificationCenterStore` that deduplicates only non-empty keys for the same profile.

- [ ] **Step 3: Register the SwiftData model**

Add `NotificationRecord.self` to the model container list in `Paya/PayaApp.swift`.

- [ ] **Step 4: Build the Paya target after the model change**

Run: `xcodebuild -project Paya.xcodeproj -scheme Paya -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO`

Expected: the `Paya` scheme compiles with the new SwiftData entity.

### Task 2: Add the app notification router and reusable inbox UI

**Files:**
- Create: `Paya/NotificationCenterView.swift`
- Modify: `Paya/AppState.swift`
- Modify: `Paya/ContentView.swift`

**Interfaces:**
- Consumes: `NotificationRecord`, `NotificationCenterStore`, `NotificationDestination`, and `ModelContext` from Task 1.
- Produces: `NotificationRouter`, `NotificationCenterView`, `NotificationBellButton`, and `NotificationCard`.
- Produces: `NotificationRouter.destination: NotificationDestination?` and `NotificationRouter.consumeDestination() -> NotificationDestination?`.

- [ ] **Step 1: Add a router to AppState**

Add `NotificationRouter` as an `@Observable` class with a single optional destination, then add `let notificationRouter = NotificationRouter()` to `AppState`.

- [ ] **Step 2: Create the inbox view**

Create a SwiftUI sheet that:

```swift
struct NotificationCenterView: View {
    let profileId: UUID?
    let onOpen: (NotificationRecord) -> Void
}
```

Fetches `NotificationRecord` with `@Query`, filters to `profileId`, groups items into Today and Earlier, and provides `Mark all read` and swipe-to-delete actions through `NotificationCenterStore`.

- [ ] **Step 3: Create category presentation helpers**

Map each `NotificationCategory` to a focused SF Symbol and color: training/dumbbell blue, meal/fork orange, supplement/capsule purple, hydration/drop cyan, recovery/moon indigo, weigh-in/scale teal, milestone/trophy amber, flare-risk/flame red, and rest-timer/timer green.

- [ ] **Step 4: Route a tapped notification**

In `ContentView`, observe the router destination and map it to tab tags: home `0`, train `1`, nutrition `2`, health `3`, progress `4`. Settings opens `SettingsView` from a new state binding. Always mark the opened record read before routing.

- [ ] **Step 5: Build the Paya target**

Run: `xcodebuild -project Paya.xcodeproj -scheme Paya -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO`

Expected: the new UI and router compile without changing the five existing tab destinations.

### Task 3: Add the dashboard bell and unread badge

**Files:**
- Modify: `Paya/DashboardView.swift`

**Interfaces:**
- Consumes: `NotificationBellButton`, `NotificationCenterView`, `appState.notificationRouter`, and the active profile ID.

- [ ] **Step 1: Add dashboard sheet state**

Add `@State private var showNotifications = false` and place `NotificationCenterView` in a `.sheet` alongside the existing Dashboard sheets.

- [ ] **Step 2: Add bell to the header**

Place `NotificationBellButton` between the profile switcher and Settings buttons. The badge count must query only the current profile's unread `NotificationRecord` objects.

- [ ] **Step 3: Check interaction manually**

In the simulator, open Home, verify the bell has no badge with an empty store, and verify it opens the notification sheet.

- [ ] **Step 4: Build the Paya target**

Run: `xcodebuild -project Paya.xcodeproj -scheme Paya -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO`

Expected: Dashboard compiles and still presents settings, profile switcher, library, and weight-entry sheets.

### Task 4: Integrate the existing local-notification producers

**Files:**
- Modify: `Paya/NotificationManager.swift`
- Modify: `Paya/MilestoneEngine.swift`
- Modify: `Paya/DashboardView.swift`

**Interfaces:**
- Consumes: `NotificationCenterStore` and `NotificationRecord` from Task 1.
- Produces: `NotificationManager.recordAndDeliver(_:context:systemRequest:) async`.

- [ ] **Step 1: Add a gateway payload type**

Add a small payload type to `NotificationManager` containing category, title, body, deduplication key, destination, and optional system request identifier.

- [ ] **Step 2: Record training reminders when they are opened or generated**

Keep the recurring iOS requests intact. Add a matching in-app training record when the app determines a training reminder applies, using the day plus profile as its deduplication key and destination `.train`.

- [ ] **Step 3: Record pre-flare alerts**

Pass `modelContext` from `DashboardView.loadData()` into the pre-flare pathway. Create one flare-risk record per profile/day before scheduling its iOS notification, with destination `.health`.

- [ ] **Step 4: Record milestones**

Replace direct milestone delivery in `MilestoneEngine` with the gateway. Preserve existing per-day UserDefaults deduplication and add `.milestone` inbox records with destination `.progress`.

- [ ] **Step 5: Build and manually verify existing flows**

Run: `xcodebuild -project Paya.xcodeproj -scheme Paya -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO`

Expected: all existing notification producers compile and each can produce no more than one matching inbox record per deduplication window.

### Task 5: Extend Settings with notification-center controls

**Files:**
- Modify: `Paya/AppState.swift`
- Modify: `Paya/SettingsView.swift`

**Interfaces:**
- Consumes: `NotificationCategory` from Task 1 and existing UserProfile persistence.
- Produces: persisted `notificationCategoryEnabled: [String: Bool]`, `notificationsQuietHoursEnabled: Bool`, `quietHoursStart: Date`, and `quietHoursEnd: Date` user preferences.

- [ ] **Step 1: Add persisted profile preferences**

Extend `UserProfile` with default-on switches for the currently implemented categories (`training`, `milestone`, `flareRisk`) and default-off switches for not-yet-scheduled categories. Add quiet hours defaulting to 22:00–07:00.

- [ ] **Step 2: Add a settings navigation row**

Below the current Training Reminders and Pre-flare Alerts settings, add a `Notification preferences` row that presents a sheet. Keep the current toggles visually and behaviorally intact.

- [ ] **Step 3: Create preferences content in SettingsView**

Add category toggles grouped as Activity, Nutrition, Recovery, and Progress, plus quiet-hours toggle and start/end time pickers. Disable switches for categories that are not automatically scheduled, while showing that they will be available as Paya features are added.

- [ ] **Step 4: Make gateway delivery respect the preferences**

Only schedule/deliver system notifications when the category is enabled and the current time is outside quiet hours; still store the in-app record regardless.

- [ ] **Step 5: Build the Paya target and perform final smoke test**

Run: `xcodebuild -project Paya.xcodeproj -scheme Paya -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO`

Expected: Paya compiles and all notification-center settings persist after relaunch.
