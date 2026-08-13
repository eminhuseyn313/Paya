import Foundation
import SwiftUI

// MARK: - Dynamic Warm-up Builder
// Assembles a warm-up from the day's actual muscle groups instead of
// hardcoded A/B/C routines.

enum DynamicWarmup {

    // MARK: - Body regions

    enum Region: String, CaseIterable {
        case shoulders, chest, back, arms, quads, posterior, core, calves
    }

    /// Maps a muscleGroup string (from ExerciseDefinition / CustomSessionExercise)
    /// to regions. Matching is substring-based and case-insensitive.
    static func regions(forMuscleGroup group: String) -> Set<Region> {
        let g = group.lowercased()
        var result: Set<Region> = []
        if g.contains("delt") || g.contains("shoulder") || g.contains("cuff") { result.insert(.shoulders) }
        if g.contains("chest") || g.contains("pec") { result.insert(.chest) }
        if g.contains("back") || g.contains("lat") || g.contains("trap") { result.insert(.back) }
        if g.contains("bicep") || g.contains("tricep") || g.contains("arm") || g.contains("forearm") { result.insert(.arms) }
        if g.contains("quad") || g.contains("leg") { result.insert(.quads) }
        if g.contains("hamstring") || g.contains("glute") || g.contains("posterior") || g.contains("hinge") { result.insert(.posterior) }
        if g.contains("core") || g.contains("ab") { result.insert(.core) }
        if g.contains("calv") || g.contains("calf") { result.insert(.calves) }
        return result
    }

    // MARK: - Move pool

    static let generalMoves: [WarmupMove] = [
        WarmupMove(
            id: "dyn_pulse",
            name: "Light Cardio — Bike or Row",
            duration: "2 min easy pace",
            durationSeconds: 120,
            instructions: "Easy pace, nasal breathing. Goal is warmth, not fatigue.",
            purpose: "Raises core temperature and heart rate",
            icon: "figure.indoor.cycle",
            isJointSensitive: false
        ),
        WarmupMove(
            id: "dyn_worlds_greatest",
            name: "World's Greatest Stretch",
            duration: "4 reps each side",
            durationSeconds: 0,
            instructions: "Deep lunge, hand inside front foot, rotate torso and reach up. Slow.",
            purpose: "Opens hips, hamstrings, and thoracic spine in one move",
            icon: "figure.flexibility",
            isJointSensitive: false
        )
    ]

    static let regionMoves: [Region: [WarmupMove]] = [
        .shoulders: [
            WarmupMove(
                id: "dyn_arm_circles",
                name: "Arm Circles — Small to Large",
                duration: "30s each direction",
                durationSeconds: 60,
                instructions: "Start small, grow the circle. Never force range.",
                purpose: "Blood flow to delts and rotator cuff",
                icon: "arrow.triangle.2.circlepath",
                isJointSensitive: true
            ),
            WarmupMove(
                id: "dyn_band_pull_apart",
                name: "Band Pull-Aparts",
                duration: "15 reps",
                durationSeconds: 0,
                instructions: "Arms straight at chest height, pull apart, squeeze shoulder blades.",
                purpose: "Rear delt + scapular activation — AC joint protection",
                icon: "arrow.left.and.right",
                isJointSensitive: false
            ),
            WarmupMove(
                id: "dyn_external_rotation",
                name: "Band External Rotations",
                duration: "12 reps each arm",
                durationSeconds: 0,
                instructions: "Elbow pinned at side, rotate forearm outward against light band.",
                purpose: "Rotator cuff priming before any pressing",
                icon: "rotate.right",
                isJointSensitive: true
            )
        ],
        .chest: [
            WarmupMove(
                id: "dyn_scap_pushup",
                name: "Scapular Push-Ups",
                duration: "10 reps",
                durationSeconds: 0,
                instructions: "Plank position, arms straight. Only shoulder blades move — pinch and spread.",
                purpose: "Wakes up serratus and scapular control for pressing",
                icon: "figure.strengthtraining.functional",
                isJointSensitive: true
            )
        ],
        .back: [
            WarmupMove(
                id: "dyn_scap_pull",
                name: "Scapular Pulls (hang or band)",
                duration: "10 reps",
                durationSeconds: 0,
                instructions: "Dead hang or band overhead. Depress and retract shoulder blades without bending elbows.",
                purpose: "Lat and scapular engagement before pulling",
                icon: "figure.climbing",
                isJointSensitive: false
            ),
            WarmupMove(
                id: "dyn_cat_cow",
                name: "Cat-Cow",
                duration: "8 slow reps",
                durationSeconds: 0,
                instructions: "On all fours, alternate arching and rounding the spine with breath.",
                purpose: "Spinal mobility before rows and hinges",
                icon: "figure.core.training",
                isJointSensitive: false
            )
        ],
        .quads: [
            WarmupMove(
                id: "dyn_bw_squat",
                name: "Bodyweight Squats",
                duration: "12 reps",
                durationSeconds: 0,
                instructions: "Full depth, slow tempo, arms forward for balance.",
                purpose: "Knee and hip prep for loaded squatting",
                icon: "figure.cross.training",
                isJointSensitive: false
            ),
            WarmupMove(
                id: "dyn_hip_opener",
                name: "90/90 Hip Switches",
                duration: "6 each side",
                durationSeconds: 0,
                instructions: "Seated, both knees at 90°. Rotate knees side to side keeping torso tall.",
                purpose: "Hip internal/external rotation for squat depth",
                icon: "figure.flexibility",
                isJointSensitive: false
            )
        ],
        .posterior: [
            WarmupMove(
                id: "dyn_glute_bridge",
                name: "Glute Bridges",
                duration: "12 reps, 1s squeeze",
                durationSeconds: 0,
                instructions: "On back, feet flat. Drive hips up, squeeze glutes hard at top.",
                purpose: "Glute activation before hinging",
                icon: "figure.core.training",
                isJointSensitive: false
            ),
            WarmupMove(
                id: "dyn_leg_swing",
                name: "Leg Swings",
                duration: "10 each leg",
                durationSeconds: 0,
                instructions: "Hold support, swing leg front-to-back with control. Growing range.",
                purpose: "Dynamic hamstring prep",
                icon: "figure.walk",
                isJointSensitive: false
            )
        ],
        .core: [
            WarmupMove(
                id: "dyn_dead_bug",
                name: "Dead Bugs",
                duration: "6 each side",
                durationSeconds: 0,
                instructions: "On back, opposite arm and leg extend slowly. Lower back stays glued down.",
                purpose: "Core bracing pattern",
                icon: "figure.core.training",
                isJointSensitive: false
            )
        ],
        .calves: [
            WarmupMove(
                id: "dyn_ankle_circles",
                name: "Ankle Circles + Calf Raises",
                duration: "10 each",
                durationSeconds: 0,
                instructions: "Circles both directions, then slow bodyweight calf raises.",
                purpose: "Ankle mobility and calf blood flow",
                icon: "figure.walk",
                isJointSensitive: false
            )
        ],
        .arms: []   // arms warm up via pressing/pulling primers; no dedicated moves
    ]

    // MARK: - Build

    /// Assembles a routine for the day's exercises. Cap ~7 moves to keep it under 8 minutes.
    static func routine(
        dayName: String,
        exercises: [ExerciseDefinition]
    ) -> WarmupRoutine {
        var regions: Set<Region> = []
        for ex in exercises {
            regions.formUnion(Self.regions(forMuscleGroup: ex.muscleGroup))
        }

        var moves: [WarmupMove] = generalMoves

        // Priority order keeps the most injury-relevant prep first
        let priority: [Region] = [.shoulders, .quads, .posterior, .back, .chest, .core, .calves]
        for region in priority where regions.contains(region) {
            moves.append(contentsOf: regionMoves[region] ?? [])
            if moves.count >= 7 { break }
        }

        if moves.count > 7 {
            moves = Array(moves.prefix(7))
        }

        let estMinutes = max(5, min(8, moves.count + 1))

        return WarmupRoutine(
            id: "dyn_\(dayName)",
            sessionType: .a,   // legacy field, unused by dynamic path
            totalMinutes: estMinutes,
            title: "\(dayName) Warm-up",
            subtitle: regions.isEmpty
                ? "General preparation"
                : "Primes: " + priority.filter { regions.contains($0) }
                    .map { $0.rawValue.capitalized }.joined(separator: ", "),
            moves: moves
        )
    }
}//
//  DynamicWarmup.swift
//  Paya
//
//  Created by Emin Huseynzade on 13.07.26.
//

