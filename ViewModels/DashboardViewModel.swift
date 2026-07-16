//
//  DashboardViewModel.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 7/9/26.
//

import Foundation
import Combine
import SwiftData

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var aerobicBaselineEF: Double?
    @Published var targetDistance: TargetDistance = .fiveK
    @Published var predictedFinishTime: String = "--:--:--"
    @Published var splitPace: String = "--:--"
    @Published var isLoading: Bool = false
    @Published var predictionUnavailableMessage: String?
    @Published var baselineDate: Date?
    @Published var latestRunDate: Date?
    @Published var latestRunPaceDisplay: String = "--"
    @Published var latestRunHRDisplay: String = "--"
    @Published var latestRunDistanceDisplay: String = "--"
    @Published var castBasisDisplay: String?
    @Published var recentRunNote: String?
    @Published var latestRunHRIsFlagged: Bool = false
    @Published var runScore: Int?
    @Published var runScoreLabel: String?
    @Published var aerobicTimePoints: Int?
    @Published var pacingControlPoints: Int?
    @Published var effortSpikePoints: Int?
    enum EFTrendDirection {
        case up, down, flat
    }

    @Published var efTrendDirection: EFTrendDirection?
    @Published var efTrendPercentDisplay: String?
    
    private var modelContext: ModelContext?
    private var allWorkouts: [RunWorkout] = []
    private let settings: AppSettings

    init(settings: AppSettings? = nil) {
        self.settings = settings ?? AppSettings.shared
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        reload()
    }

    func reload() {
        guard let modelContext else { return }
        isLoading = true
        let descriptor = FetchDescriptor<RunWorkout>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        allWorkouts = (try? modelContext.fetch(descriptor)) ?? []

        // Baseline: most recent QUALIFYING run
        let baseline = EfficiencyCalculator.latestBaseline(allWorkouts)
        aerobicBaselineEF = baseline?.efficiencyFactor
        baselineDate = baseline?.startDate
        
        if let currentEF = baseline?.efficiencyFactor,
           let previous = EfficiencyCalculator.previousBaseline(allWorkouts),
           let previousEF = previous.efficiencyFactor,
           previousEF > 0 {
            let percentChange = ((currentEF - previousEF) / previousEF) * 100
            efTrendPercentDisplay = String(format: "%.1f%%", abs(percentChange))
            if abs(percentChange) < 0.5 {
                efTrendDirection = .flat
            } else {
                efTrendDirection = percentChange > 0 ? .up : .down
            }
        } else {
            efTrendDirection = nil
            efTrendPercentDisplay = nil
        }

        // Stats row: most recent run OVERALL, regardless of qualification
        let mostRecent = allWorkouts.first
        latestRunDate = mostRecent?.startDate

        if let mostRecent {
            if let distance = mostRecent.distanceMeters {
                latestRunPaceDisplay = PredictionEngine.splitPace(
                    finishTimeSeconds: mostRecent.durationSeconds,
                    distanceMeters: distance,
                    unit: settings.measurementUnit
                )
                let unitDistance = settings.measurementUnit == .miles ? distance / 1609.344 : distance / 1000.0
                latestRunDistanceDisplay = String(format: "%.1f %@", unitDistance, settings.measurementUnit == .miles ? "mi" : "km")
            } else {
                latestRunPaceDisplay = "--"
                latestRunDistanceDisplay = "--"
            }
            latestRunHRDisplay = mostRecent.averageHeartRate.map { String(format: "%.0f bpm", $0) } ?? "--"
            if let hr = mostRecent.averageHeartRate {
                    latestRunHRDisplay = String(format: "%.0f bpm", hr)
                    latestRunHRIsFlagged = mostRecent.heartRateSampleCount < 10
            } else {
                    latestRunHRDisplay = "No data"
                    latestRunHRIsFlagged = false
            }
        } else {
            latestRunPaceDisplay = "--"
            latestRunDistanceDisplay = "--"
            latestRunHRDisplay = "--"
        }
        
        if let mostRecent, let score = mostRecent.runScore {
            runScore = score
            runScoreLabel = RunScoreLabel.forScore(score).rawValue
            aerobicTimePoints = mostRecent.aerobicTimePoints
            pacingControlPoints = mostRecent.pacingControlPoints
            effortSpikePoints = mostRecent.effortSpikePoints
        } else {
            runScore = nil
            runScoreLabel = nil
            aerobicTimePoints = nil
            pacingControlPoints = nil
            effortSpikePoints = nil
        }

        updateRecentRunNote(baseline: baseline, mostRecent: mostRecent)
        recomputeCast()
        isLoading = false
    }
    
    private func updateRecentRunNote(baseline: RunWorkout?, mostRecent: RunWorkout?) {
        guard let mostRecent else {
            recentRunNote = nil
            return
        }
        // If the most recent run IS the baseline run, it already qualified — nothing to explain.
        guard mostRecent.healthKitUUID != baseline?.healthKitUUID else {
            recentRunNote = nil
            return
        }

        if mostRecent.durationSeconds <= 1200 {
            recentRunNote = "Your last run was under 20 minutes, so it wasn't used to update your baseline."
        } else if mostRecent.averageHeartRate == nil || mostRecent.heartRateSampleCount < 10 {
            recentRunNote = "Your last run didn't have enough heart rate data to update your baseline."
        } else {
            recentRunNote = nil
        }
    }
    
    func selectTargetDistance(_ distance: TargetDistance) {
        targetDistance = distance
        recomputeCast()
    }
    
    private func updateRecentRunNote(baseline: RunWorkout?) {
        guard let mostRecent = allWorkouts.first else {
            recentRunNote = nil
            return
        }
        // If the most recent workout overall IS the baseline run, there's nothing to explain.
        guard mostRecent.healthKitUUID != baseline?.healthKitUUID else {
            recentRunNote = nil
            return
        }

        if mostRecent.durationSeconds <= 1200 {
            recentRunNote = "Your last run was under 20 minutes, so it wasn't used to update your baseline."
        } else if mostRecent.averageHeartRate == nil || mostRecent.heartRateSampleCount < 10 {
            recentRunNote = "Your last run didn't have enough heart rate data to update your baseline."
        } else {
            recentRunNote = nil
        }
    }

    private func recomputeCast() {
        guard let baseline = EfficiencyCalculator.aggregatedBaseline(from: allWorkouts),
              let distance = baseline.distanceMeters, distance > 0 else {
            predictionUnavailableMessage = "Complete a qualifying steady-state run to generate a prediction."
            predictedFinishTime = "--:--:--"
            splitPace = "--:--"
            castBasisDisplay = nil
            return
        }
        predictionUnavailableMessage = nil
        castBasisDisplay = "Based on your best runs from the last 30 days"

        guard let cast = PredictionEngine.predict(
            baselineDurationSeconds: baseline.durationSeconds,
            baselineDistanceMeters: distance,
            targetDistance: targetDistance
        ) else { return }

        predictedFinishTime = PredictionEngine.formatFinishTime(cast.finishTimeSeconds)
        splitPace = PredictionEngine.splitPace(
            finishTimeSeconds: cast.finishTimeSeconds,
            distanceMeters: targetDistance.meters,
            unit: settings.measurementUnit
        )
    }
}
