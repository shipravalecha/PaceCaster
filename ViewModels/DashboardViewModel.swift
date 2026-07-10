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
    @Published var latestRunDate: Date?
    @Published var latestRunPaceDisplay: String = "--"
    @Published var latestRunHRDisplay: String = "--"
    @Published var latestRunDistanceDisplay: String = "--"
    @Published var castBasisDisplay: String?
    @Published var recentRunNote: String?

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
        let baseline = EfficiencyCalculator.latestBaseline(allWorkouts)
        aerobicBaselineEF = baseline?.efficiencyFactor
        
        if let latest = EfficiencyCalculator.latestBaseline(allWorkouts) {
            aerobicBaselineEF = latest.efficiencyFactor
            latestRunDate = latest.startDate
            latestRunHRDisplay = latest.averageHeartRate.map { String(format: "%.0f bpm", $0) } ?? "--"
            if let distance = latest.distanceMeters {
                latestRunPaceDisplay = PredictionEngine.splitPace(
                    finishTimeSeconds: latest.durationSeconds,
                    distanceMeters: distance,
                    unit: settings.measurementUnit
                )
                let unitDistance = settings.measurementUnit == .miles ? distance / 1609.344 : distance / 1000.0
                latestRunDistanceDisplay = String(format: "%.1f %@", unitDistance, settings.measurementUnit == .miles ? "mi" : "km")
            } else {
                latestRunPaceDisplay = "--"
                latestRunDistanceDisplay = "--"
            }
        } else {
            aerobicBaselineEF = nil
            latestRunDate = nil
            latestRunPaceDisplay = "--"
            latestRunHRDisplay = "--"
            latestRunDistanceDisplay = "--"
        }
        
        updateRecentRunNote(baseline: baseline)
        recomputeCast()
        isLoading = false
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
