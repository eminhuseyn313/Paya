# Paya Notification Center Design

## Goal

Create a modern, profile-specific in-app notification center that unifies Paya's existing local notifications (training reminders, pre-flare alerts, and milestones) with upcoming lifestyle prompts. The center is the durable in-app history and action surface; iOS notifications are an optional delivery channel.

## Scope: first release

- Add a bell button and unread badge to the Dashboard header.
- Add an inbox sheet with `Today` and `Earlier` sections, unread styling, empty state, mark-all-read, and per-item deletion.
- Persist notification records in SwiftData, scoped to `profileId`.
- Define notification categories: training, meal, supplement, hydration, recovery, weigh-in, milestone, flare-risk, and rest-timer.
- Let each record carry an optional action destination, so a tap can open the correct Paya tab or settings screen.
- Make the existing `NotificationManager` the single gateway for creating in-app records and (when permitted and enabled) scheduling/delivering iOS notifications.
- Convert existing training, flare-risk, and milestone delivery to use the gateway.
- Add settings controls for category enablement and quiet hours. Training reminder configuration remains compatible with the current setting.

## Out of scope

- Remote push notifications, server sync, social notifications, rich media, and Apple Watch notification actions.
- Automatic meal, hydration, or recovery notification scheduling until their user preferences and completion rules are implemented. The data model and category settings support them now.

## Architecture

### NotificationRecord

Add a SwiftData `NotificationRecord` model with a UUID, profile ID, category raw value, title, body, creation date, read date, optional action destination, optional payload ID, and a deduplication key. Records are the canonical inbox source; system notification requests are delivery side effects only.

### NotificationCenterStore

A focused SwiftData service creates records, prevents duplicate records by deduplication key, fetches a profile's recent records, and marks/deletes records. It does not schedule iOS notifications or navigate UI.

### NotificationManager

Extend the current singleton to accept a record payload and model context. It writes an inbox record first, then schedules or delivers an iOS local notification only when that category is enabled, authorization permits it, and quiet hours do not apply. Existing cancellation APIs remain category-specific.

### NotificationRouter

An observable app-level router stores the selected destination. Opening an inbox record marks it read and routes it to Home, Train, Nutrition, Health, Progress, or Settings. `ContentView` owns the selected tab binding and consumes the route.

## Data flow

1. A feature decides a meaningful event occurred (for example, a protein goal has been reached).
2. It calls the notification gateway with category, copy, a deduplication key, and optional action destination.
3. The gateway persists a `NotificationRecord`, then optionally schedules/delivers the local iOS alert.
4. The dashboard badge derives its unread count from SwiftData.
5. Tapping the bell opens the inbox; tapping a card marks it read and routes to the appropriate Paya experience.

## Initial rules to prevent notification fatigue

- One notification per category per profile within its rule window.
- Milestones retain their existing once-per-day protection.
- Training reminders repeat only on configured training days.
- Flare-risk remains at most once per day.
- Future nudges are emitted only when their related task has not been completed that day.
- Quiet hours suppress system delivery but retain the in-app record.

## UI

The bell sits next to Settings in `DashboardView`. An unread count appears as a compact red badge. The center is a sheet with a large `Notifications` title, a subtle unread count, an accessible `Mark all read` control, and cards grouped by calendar day. Cards have category-specific SF Symbols and color accents. Unread cards are visually raised; read cards are subdued. The empty state explains that Paya will surface progress, reminders, and recovery signals here.

## Errors and permission handling

- Notification authorization is requested only when a user enables an alert category; inbox records work without authorization.
- A denied iOS permission never prevents the in-app center from recording an event.
- Failed scheduling is non-fatal and does not discard an already-created record.
- Deleting or marking inbox records never cancels unrelated pending system alerts.

## Testing

- Unit-test category serialization, deduplication, quiet-hour decisions, routing decisions, and unread count behavior.
- Test NotificationCenterStore with an in-memory SwiftData container for profile isolation and read/delete behavior.
- Manually verify existing training, flare-risk, and milestone flows create exactly one inbox item and retain their system delivery behavior.
- Verify tabs/actions open the intended Paya surfaces and no notification is shown for another profile.
