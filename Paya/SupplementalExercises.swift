import Foundation

// MARK: - Supplemental Exercises
//
// free-exercise-db (the bundled 873-exercise dataset) was assembled years
// ago and is missing a handful of exercises that have since become
// standard, well-evidenced parts of modern strength programming — several
// of which this app's own program generator (ExercisePool.swift) already
// prescribes. Without an entry here, tapping "Form guide" on those
// exercises during a workout returned nothing: the library had no photo,
// no instructions, no muscle breakdown for something the app itself just
// told you to do.
//
// These entries have no bundled photos (this app doesn't have rights to
// source new exercise photography, and won't fabricate a URL) — the
// exercise library UI already degrades gracefully to a placeholder when
// `images` is empty, so instructions/muscles/equipment are still fully
// present, just without a photo.
enum SupplementalExercises {
    static let all: [Exercise] = [
        Exercise(
            id: "Paya_Nordic_Hamstring_Curl",
            name: "Nordic Hamstring Curl",
            force: "pull",
            level: "expert",
            mechanic: "isolation",
            equipment: "body only",
            primaryMuscles: ["hamstrings"],
            secondaryMuscles: ["glutes"],
            instructions: [
                "Kneel on a padded surface with a partner or anchor firmly holding your ankles down.",
                "Keeping your hips extended and body in a straight line from knees to shoulders, slowly lower your torso toward the floor by resisting with your hamstrings for as long as possible.",
                "Use your hands to catch yourself at the bottom if needed, then push back up to the start using your hamstrings and a small push from your hands.",
                "Start with partial-range reps and only progress toward full range as hamstring strength allows — this is one of the most eccentrically demanding hamstring exercises and causes significant soreness if progressed too quickly."
            ],
            category: "strength",
            images: nil
        ),
        Exercise(
            id: "Paya_Bulgarian_Split_Squat",
            name: "Bulgarian Split Squat",
            force: "push",
            level: "intermediate",
            mechanic: "compound",
            equipment: "dumbbell",
            primaryMuscles: ["quadriceps"],
            secondaryMuscles: ["glutes", "hamstrings"],
            instructions: [
                "Stand a couple of feet in front of a bench, holding a dumbbell in each hand.",
                "Place the top of one foot on the bench behind you, most of your weight on the front leg.",
                "Lower your back knee toward the floor by bending the front knee, keeping your torso upright.",
                "Push through the front heel to return to the start. Complete all reps on one side before switching legs."
            ],
            category: "strength",
            images: nil
        ),
        Exercise(
            id: "Paya_Chest_Supported_Row",
            name: "Chest-Supported Row",
            force: "pull",
            level: "intermediate",
            mechanic: "compound",
            equipment: "dumbbell",
            primaryMuscles: ["lats"],
            secondaryMuscles: ["shoulders", "biceps"],
            instructions: [
                "Set an adjustable bench to a 30-45° incline and lie face-down on it, chest supported, feet on the floor or bench for stability.",
                "Hold a dumbbell in each hand, arms hanging straight down.",
                "Row both dumbbells toward your hips, squeezing your shoulder blades together at the top.",
                "Lower with control back to a full stretch. The chest support removes lower-back involvement, isolating the back muscles more than a standard bent-over row."
            ],
            category: "strength",
            images: nil
        ),
        Exercise(
            id: "Paya_Copenhagen_Plank",
            name: "Copenhagen Plank",
            force: "static",
            level: "expert",
            mechanic: "isolation",
            equipment: "body only",
            primaryMuscles: ["adductors"],
            secondaryMuscles: ["abdominals"],
            instructions: [
                "Lie on your side with your top leg's shin or knee resting on a bench, and your bottom arm propped up on your elbow.",
                "Lift your hips off the floor so your body forms a straight line, supported by your top leg on the bench and bottom arm.",
                "Hold the position for time, keeping hips level. Start with the bottom knee bent (easier) before progressing to a straight bottom leg.",
                "This is the primary evidence-based exercise for adductor (groin) strain prevention in field-sport athletes — build up duration gradually."
            ],
            category: "strength",
            images: nil
        ),
        Exercise(
            id: "Paya_Suitcase_Carry",
            name: "Suitcase Carry",
            force: "static",
            level: "beginner",
            mechanic: "isolation",
            equipment: "dumbbell",
            primaryMuscles: ["abdominals"],
            secondaryMuscles: ["shoulders", "forearms"],
            instructions: [
                "Stand holding a single heavy dumbbell or kettlebell at your side, like carrying a suitcase.",
                "Brace your core and stand tall, resisting the urge to lean toward the loaded side.",
                "Walk for a set distance or time, keeping shoulders level and torso upright throughout.",
                "Switch sides and repeat. The unilateral load trains anti-lateral-flexion core strength — resisting side-bend, not producing it."
            ],
            category: "strength",
            images: nil
        ),
        Exercise(
            id: "Paya_Pike_Push_Up",
            name: "Pike Push-Up",
            force: "push",
            level: "intermediate",
            mechanic: "compound",
            equipment: "body only",
            primaryMuscles: ["shoulders"],
            secondaryMuscles: ["triceps", "chest"],
            instructions: [
                "Start in a downward-dog position: hips high, hands and feet on the floor, forming an inverted V.",
                "Bend your elbows to lower the top of your head toward the floor between your hands.",
                "Press back up to the start position, keeping hips high throughout.",
                "Elevating your feet on a bench increases the shoulder-dominant loading and moves the movement closer to a vertical press."
            ],
            category: "strength",
            images: nil
        ),
        Exercise(
            id: "Paya_Banded_Lateral_Walk",
            name: "Banded Lateral Walk",
            force: "static",
            level: "beginner",
            mechanic: "isolation",
            equipment: "bands",
            primaryMuscles: ["glutes"],
            secondaryMuscles: ["abductors"],
            instructions: [
                "Place a resistance band around your legs, just above the knees or around the ankles for more difficulty.",
                "Get into a quarter-squat position with knees slightly bent and feet hip-width apart, maintaining tension on the band.",
                "Step sideways with control, keeping the band taut and knees tracking over toes — don't let the knees cave inward.",
                "Take 8-12 steps in one direction, then repeat back the other way."
            ],
            category: "strength",
            images: nil
        ),
        Exercise(
            id: "Paya_Pec_Deck",
            name: "Pec Deck",
            force: "push",
            level: "beginner",
            mechanic: "isolation",
            equipment: "machine",
            primaryMuscles: ["chest"],
            secondaryMuscles: ["shoulders"],
            instructions: [
                "Sit in the machine with your back flat against the pad and grip the handles (or press your forearms against the arm pads, depending on the machine).",
                "Keep a slight bend in your elbows and bring your arms together in front of your chest in a hugging motion.",
                "Squeeze your chest at the point of full contraction, then return with control to a full stretch — the fixed path means you don't need to stabilize the weight, so the isolation stays on the chest rather than the shoulders or triceps.",
                "A good low-fatigue finisher after heavier pressing work, or a joint-friendly option on days a bench/cable fly feels rough on the shoulders."
            ],
            category: "strength",
            images: nil
        ),
        Exercise(
            id: "Paya_Reverse_EZ_Bar_Curl",
            name: "Reverse-Grip EZ Bar Curl",
            force: "pull",
            level: "intermediate",
            mechanic: "isolation",
            equipment: "barbell",
            primaryMuscles: ["forearms"],
            secondaryMuscles: ["biceps"],
            instructions: [
                "Grip an EZ curl bar with a pronated (palms-down, overhand) grip on the angled inner section of the bar.",
                "Stand tall with elbows tucked at your sides, arms extended.",
                "Curl the bar up toward your chest, keeping elbows fixed and wrists straight — don't let the wrists flex to compensate.",
                "Lower with control back to a full stretch. The reverse grip shifts emphasis onto the brachialis and forearms (similar to a hammer curl's effect) rather than the biceps directly — the EZ bar's angled grip is easier on the wrists in this position than a straight bar."
            ],
            category: "strength",
            images: nil
        ),
        Exercise(
            id: "Paya_Clamshell",
            name: "Clamshell",
            force: "static",
            level: "beginner",
            mechanic: "isolation",
            equipment: "body only",
            primaryMuscles: ["glutes"],
            secondaryMuscles: [],
            instructions: [
                "Lie on your side with hips and knees bent about 45°, feet stacked together.",
                "Keeping your feet touching, lift your top knee open like a clamshell, rotating at the hip.",
                "Pause briefly at the top, then lower with control. Keep your pelvis still — the movement comes from hip rotation, not from rocking your torso back.",
                "Add a resistance band around the knees once bodyweight reps stop feeling challenging."
            ],
            category: "strength",
            images: nil
        ),
        Exercise(
            id: "Paya_Seated_Row_Machine",
            name: "Seated Row Machine",
            force: "pull",
            level: "beginner",
            mechanic: "compound",
            equipment: "machine",
            primaryMuscles: ["middle back"],
            secondaryMuscles: ["lats", "biceps", "shoulders"],
            instructions: [
                "Sit at the machine with your chest against the pad, feet flat on the floor or foot plate.",
                "Grip the handles with a neutral or overhand grip, arms extended.",
                "Pull the handles toward your torso, squeezing your shoulder blades together at the end of the movement.",
                "Return with control to a full stretch. The chest pad removes lower-back involvement, making this a good option for isolating mid-back without spinal loading."
            ],
            category: "strength",
            images: nil
        ),
        Exercise(
            id: "Paya_Machine_Shoulder_Press",
            name: "Machine Shoulder Press",
            force: "push",
            level: "beginner",
            mechanic: "compound",
            equipment: "machine",
            primaryMuscles: ["shoulders"],
            secondaryMuscles: ["triceps"],
            instructions: [
                "Sit with your back flat against the pad. Adjust the seat so the handles start at about ear height.",
                "Grip the handles and press upward until your arms are nearly fully extended — avoid locking out the elbows.",
                "Lower with control back to the start position. The fixed path lets you load the shoulders heavily without needing to stabilize the weight overhead.",
                "A back-lean variant (slightly reclined pad angle) shifts emphasis toward the front delts and upper chest."
            ],
            category: "strength",
            images: nil
        ),
        Exercise(
            id: "Paya_Cable_Rope_Face_Pull",
            name: "Cable Rope Face Pull",
            force: "pull",
            level: "intermediate",
            mechanic: "compound",
            equipment: "cable",
            primaryMuscles: ["shoulders"],
            secondaryMuscles: ["middle back", "traps"],
            instructions: [
                "Set a cable pulley to upper-chest or face height and attach a rope handle.",
                "Grip the rope with a neutral grip, step back, and start with arms extended toward the pulley.",
                "Pull the rope toward your face, splitting the ends apart as you pull — external rotation at the shoulder so your hands finish beside your ears.",
                "Squeeze rear delts and mid-traps at the peak, then return with control. A key exercise for shoulder health and posture — targets the rear delts and external rotators that pressing movements neglect."
            ],
            category: "strength",
            images: nil
        ),
        Exercise(
            id: "Paya_Cable_Lateral_Raise",
            name: "Cable Lateral Raise",
            force: "pull",
            level: "intermediate",
            mechanic: "isolation",
            equipment: "cable",
            primaryMuscles: ["shoulders"],
            secondaryMuscles: [],
            instructions: [
                "Stand beside a low cable pulley, holding the handle in the far hand (cable crosses in front of or behind your body).",
                "With a slight bend in the elbow, raise your arm out to the side until it's roughly parallel with the floor.",
                "Lower with control. The cable provides constant tension throughout the range — unlike a dumbbell, which is hardest at the top and easy at the bottom.",
                "Great for building the lateral (side) delt head for shoulder width and a V-taper appearance."
            ],
            category: "strength",
            images: nil
        ),
        Exercise(
            id: "Paya_Cable_Upright_Row",
            name: "Cable Upright Row",
            force: "pull",
            level: "intermediate",
            mechanic: "compound",
            equipment: "cable",
            primaryMuscles: ["shoulders"],
            secondaryMuscles: ["traps", "biceps"],
            instructions: [
                "Stand facing a low cable pulley with a straight bar or rope attachment.",
                "Grip the bar slightly wider than shoulder width — a wider grip reduces internal rotation stress on the shoulder joint.",
                "Pull the bar upward along your body, leading with the elbows, until your upper arms are roughly parallel with the floor.",
                "Lower with control. Stop the pull before your elbows go above shoulder height to keep the shoulder in a safe range."
            ],
            category: "strength",
            images: nil
        ),
        Exercise(
            id: "Paya_Mid_Back_Machine",
            name: "Rear Delt / Mid-Back Machine",
            force: "pull",
            level: "beginner",
            mechanic: "isolation",
            equipment: "machine",
            primaryMuscles: ["middle back"],
            secondaryMuscles: ["shoulders"],
            instructions: [
                "Sit facing the machine pad (the reverse of a pec deck). Adjust the handles so they start in front of you at chest height.",
                "With a slight bend in the elbows, push the handles apart in a reverse fly motion, squeezing your shoulder blades together.",
                "Return with control to the starting position. The fixed path isolates the rear delts and mid-back without requiring stabilization.",
                "Also called the reverse pec deck — targets the same muscles as a cable face pull but with a more locked-in movement path."
            ],
            category: "strength",
            images: nil
        )
    ]
}
