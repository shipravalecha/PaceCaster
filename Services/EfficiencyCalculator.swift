//
//  EfficiencyCalculator.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 7/9/26.
//

import Foundation

enum EfficiencyCalculator {
    /// EF = (avg speed m/s / avg HR bpm) * 100
    static func computeEF(averageSpeedMetersPerSecond: Double, averageHeartRateBPM: Double) -> Double? {
        guard averageHeartRateBPM > 0 else { return nil }
        return (averageSpeedMetersPerSecond / averageHeartRateBPM) * 100
    }

    /// Req 6.2 / 4.4: most recent EF, shown on dashboard as Aerobic_Baseline
    static func latestBaseline(_ workouts: [RunWorkout]) -> RunWorkout? {
        workouts.filter { $0.isSteadyState }.sorted { $0.startDate > $1.startDate }.first
    }

    /// Req 5.2: aggregated baseline = median of top-3 qualifying runs (by EF) in last 30 days
    static func aggregatedBaseline(from workouts: [RunWorkout], referenceDate: Date = Date()) -> RunWorkout? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: referenceDate) ?? referenceDate
        let qualifying = workouts
            .filter { $0.isSteadyState && $0.startDate >= cutoff && $0.efficiencyFactor != nil }
            .sorted { ($0.efficiencyFactor ?? 0) > ($1.efficiencyFactor ?? 0) }

        let top3 = Array(qualifying.prefix(3))
        guard !top3.isEmpty else { return nil }

        let sortedByEF = top3.sorted { ($0.efficiencyFactor ?? 0) < ($1.efficiencyFactor ?? 0) }
        return sortedByEF[sortedByEF.count / 2]
    }
    
    /// Second-most-recent qualifying run, used to compute trend vs the current baseline.
    static func previousBaseline(_ workouts: [RunWorkout]) -> RunWorkout? {
        let qualifying = workouts.filter { $0.isSteadyState }.sorted { $0.startDate > $1.startDate }
        guard qualifying.count >= 2 else { return nil }
        return qualifying[1]
    }
}
