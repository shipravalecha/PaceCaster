//
//  RunScoreRecalculator.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 8/24/26.
//

import Foundation
import SwiftData

@MainActor
enum RunScoreRecalculator {
    /// Recomputes and stores Run Score for every run whose stored score is
    /// missing or was computed against a different Max Heart Rate. This is the
    /// ONLY place heavy computation happens — everywhere else just reads the
    /// already-stored fields, which is fast.
    static func recalculateAll(modelContext: ModelContext, maxHeartRate: Int) {
        let descriptor = FetchDescriptor<RunWorkout>()
        let allRuns = (try? modelContext.fetch(descriptor)) ?? []

        for run in allRuns {
            guard run.scoreComputedForMaxHR != maxHeartRate else { continue } // already up to date, skip
            guard let result = RunScoreCalculator.compute(for: run, maxHeartRate: maxHeartRate) else { continue }

            run.runScore = result.totalScore
            run.aerobicTimePoints = result.aerobicTimePoints
            run.pacingControlPoints = result.pacingControlPoints
            run.effortSpikePoints = result.effortSpikePoints
            run.aerobicPercent = result.aerobicPercent
            run.tempoPercent = result.tempoPercent
            run.anaerobicPercent = result.anaerobicPercent
            run.effortSpikeCount = result.spikeCount
            run.scoreComputedForMaxHR = maxHeartRate
        }
        try? modelContext.save()

        MilestoneChecker.rebuildAllMilestones(modelContext: modelContext, notifyForRunUUID: nil)
    }
}
