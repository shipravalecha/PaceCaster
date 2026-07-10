//
//  DebugSeeder.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 7/9/26.
//

import Foundation
import SwiftData

#if DEBUG
enum DebugSeeder {

    /// Seeds ~12 weeks of realistic running data: mix of steady-state runs
    /// (with heart rate) and a few short/no-HR runs that should NOT count
    /// toward the Aerobic Baseline, so you can verify the filtering logic too.
    static func seed(into modelContext: ModelContext) {
        clear(modelContext: modelContext)

        let calendar = Calendar.current
        let now = Date()

        // Baseline pace/HR that we'll drift slightly over time to simulate improvement.
        var basePaceSecPerKm: Double = 6 * 60 + 30 // 6:30/km
        var baseHR: Double = 158

        var workouts: [RunWorkout] = []

        // 12 weeks of history, 3 runs/week, most recent last (so trend improves toward today)
        for week in stride(from: 11, through: 0, by: -1) {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -week, to: now)!

            // Slight improvement over time: pace gets faster, EF drifts up
            basePaceSecPerKm -= 1.5
            baseHR -= 0.3

            for dayOffset in [1, 3, 5] {
                guard let runDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
                guard runDate <= now else { continue }

                let isLongRun = dayOffset == 5
                let distanceKm = isLongRun ? Double.random(in: 8...12) : Double.random(in: 4...6)
                let jitterPace = basePaceSecPerKm + Double.random(in: -20...20)
                let durationSeconds = distanceKm * jitterPace
                let avgHR = baseHR + Double.random(in: -4...4)

                let workout = RunWorkout(
                    healthKitUUID: UUID(),
                    startDate: runDate,
                    durationSeconds: durationSeconds,
                    distanceMeters: distanceKm * 1000,
                    averageHeartRate: avgHR,
                    heartRateSampleCount: Int.random(in: 25...60) // well over the 10-sample minimum
                )

                if workout.isSteadyState,
                   let speed = workout.averageSpeedMetersPerSecond {
                    workout.efficiencyFactor = EfficiencyCalculator.computeEF(
                        averageSpeedMetersPerSecond: speed,
                        averageHeartRateBPM: avgHR
                    )
                }

                workouts.append(workout)
            }
        }

        // A short run (12 min) with HR data — duration too low, should be excluded
        // from steady-state despite having heart rate samples. Tests Req 4.1.
        let shortRun = RunWorkout(
            healthKitUUID: UUID(),
            startDate: calendar.date(byAdding: .day, value: -2, to: now)!,
            durationSeconds: 12 * 60,
            distanceMeters: 2000,
            averageHeartRate: 150,
            heartRateSampleCount: 15
        )
        workouts.append(shortRun)

        // A 25-minute run with NO heart rate data — long enough, but should be
        // excluded from EF computation due to missing HR. Tests Req 2.4 / 4.3.
        let noHRRun = RunWorkout(
            healthKitUUID: UUID(),
            startDate: calendar.date(byAdding: .day, value: -1, to: now)!,
            durationSeconds: 25 * 60,
            distanceMeters: 5000,
            averageHeartRate: nil,
            heartRateSampleCount: 0
        )
        workouts.append(noHRRun)

        for workout in workouts {
            modelContext.insert(workout)
        }

        try? modelContext.save()
    }

    /// Removes all seeded/real data — same effect as a Database Flush.
    static func clear(modelContext: ModelContext) {
        try? modelContext.delete(model: RunWorkout.self)
        try? modelContext.save()
    }
    
    /// Seeds a single run dated today with HR present but insufficient samples,
    /// specifically to test the red-flagged HR display path.
    static func seedFlaggedHRRun(into modelContext: ModelContext) {
        let flaggedRun = RunWorkout(
            healthKitUUID: UUID(),
            startDate: Date(),
            durationSeconds: 28 * 60,
            distanceMeters: 4800,
            averageHeartRate: 149,
            heartRateSampleCount: 6   // below the 10-sample minimum
        )
        // Deliberately NOT computing efficiencyFactor — this run should never
        // qualify as steady-state, so it shouldn't have an EF value at all.
        modelContext.insert(flaggedRun)
        try? modelContext.save()
    }
}
#endif
