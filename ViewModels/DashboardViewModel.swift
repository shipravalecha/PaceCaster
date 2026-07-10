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
        aerobicBaselineEF = EfficiencyCalculator.latestBaseline(allWorkouts)?.efficiencyFactor
        recomputeCast()
        isLoading = false
    }

    func selectTargetDistance(_ distance: TargetDistance) {
        targetDistance = distance
        recomputeCast()
    }

    private func recomputeCast() {
        guard let baseline = EfficiencyCalculator.aggregatedBaseline(from: allWorkouts),
              let distance = baseline.distanceMeters, distance > 0 else {
            predictionUnavailableMessage = "Complete a qualifying steady-state run to generate a prediction."
            predictedFinishTime = "--:--:--"
            splitPace = "--:--"
            return
        }
        predictionUnavailableMessage = nil

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
