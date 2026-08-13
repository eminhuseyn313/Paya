import Foundation

// MARK: - Lifestyle Reminder Settings
// Eye care, morning light, and hydration reminders used to run on schedules
// baked directly into LifestyleReminderScheduler — there was no page where
// a user could actually change them (a 10pm-to-6am sleeper got a "morning
// light" ping at 8:30 regardless). These are the real, user-editable knobs
// behind each reminder, persisted directly (same UserDefaults pattern as
// AppState.isFlareDay) so they don't require threading through the profile
// sync path.

enum LifestyleReminderSettings {

    static var hydrationTargetMl: Int {
        get { UserDefaults.standard.object(forKey: "hydration_target_ml") as? Int ?? 2500 }
        set { UserDefaults.standard.set(newValue, forKey: "hydration_target_ml") }
    }

    static var hydrationCheckHour: Int {
        get { UserDefaults.standard.object(forKey: "hydration_check_hour") as? Int ?? 15 }
        set { UserDefaults.standard.set(newValue, forKey: "hydration_check_hour") }
    }

    static var morningLightHour: Int {
        get { UserDefaults.standard.object(forKey: "morning_light_hour") as? Int ?? 8 }
        set { UserDefaults.standard.set(newValue, forKey: "morning_light_hour") }
    }

    static var morningLightMinute: Int {
        get { UserDefaults.standard.object(forKey: "morning_light_minute") as? Int ?? 30 }
        set { UserDefaults.standard.set(newValue, forKey: "morning_light_minute") }
    }

    /// The waking-hours window eye-care reminders are spread across — four
    /// evenly-spaced slots, alternating lubricating-drop and 20-20-20
    /// reminders, rather than four fixed clock times that assume a 10am-7pm
    /// day for everyone.
    static var eyeCareStartHour: Int {
        get { UserDefaults.standard.object(forKey: "eyecare_start_hour") as? Int ?? 10 }
        set { UserDefaults.standard.set(newValue, forKey: "eyecare_start_hour") }
    }

    static var eyeCareEndHour: Int {
        get { UserDefaults.standard.object(forKey: "eyecare_end_hour") as? Int ?? 19 }
        set { UserDefaults.standard.set(newValue, forKey: "eyecare_end_hour") }
    }

    static var outdoorTargetMinutes: Int {
        get { UserDefaults.standard.object(forKey: "outdoor_target_minutes") as? Int ?? 30 }
        set { UserDefaults.standard.set(newValue, forKey: "outdoor_target_minutes") }
    }
}
