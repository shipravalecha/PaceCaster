//
//  HealthKitManager.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 7/9/26.
//

import Foundation
import HealthKit
import Combine

enum HealthKitError: Error {
    case notARunningWorkout
}

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    @Published var authorizationGranted = false

    private let workoutType = HKObjectType.workoutType()
    private let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
    private let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!

    private init() {}

    var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async throws {
        let readTypes: Set<HKObjectType> = [workoutType, heartRateType, distanceType]
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        authorizationGranted = true
    }

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        healthStore.authorizationStatus(for: type)
    }

    // MARK: - Scanning

    func scanLast90Days() async throws -> [RunWorkout] {
        let start = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        return try await fetchRunningWorkouts(since: start)
    }

    private func fetchRunningWorkouts(since startDate: Date) async throws -> [RunWorkout] {
        try await withCheckedThrowingContinuation { continuation in
            let runningPredicate = HKQuery.predicateForWorkouts(with: .running)
            let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
            let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [runningPredicate, datePredicate])

            let query = HKSampleQuery(sampleType: workoutType,
                                       predicate: compound,
                                       limit: HKObjectQueryNoLimit,
                                       sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { [weak self] _, samples, error in
                guard let self else { return }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                Task {
                    var results: [RunWorkout] = []
                    for workout in workouts {
                        if let parsed = try? await self.parse(workout: workout) {
                            results.append(parsed)
                        }
                    }
                    continuation.resume(returning: results)
                }
            }
            healthStore.execute(query)
        }
    }

    private func parse(workout: HKWorkout) async throws -> RunWorkout {
        guard workout.workoutActivityType == .running else {
            throw HealthKitError.notARunningWorkout
        }

        let distanceMeters = workout.totalDistance?.doubleValue(for: .meter())
        let hrSamples = try await heartRateSamples(for: workout)
        let distSamples = (try? await distanceSamples(for: workout)) ?? []
        let avgHR: Double? = hrSamples.isEmpty ? nil : hrSamples.reduce(0) { $0 + $1.bpm } / Double(hrSamples.count)

        let run = RunWorkout(
            healthKitUUID: workout.uuid,
            startDate: workout.startDate,
            durationSeconds: workout.duration,
            distanceMeters: distanceMeters,
            averageHeartRate: avgHR,
            heartRateSampleCount: hrSamples.count
        )

        if run.isSteadyState, let speed = run.averageSpeedMetersPerSecond, let hr = avgHR {
            run.efficiencyFactor = EfficiencyCalculator.computeEF(averageSpeedMetersPerSecond: speed, averageHeartRateBPM: hr)
        }

        let maxHR = await MainActor.run { AppSettings.shared.maxHeartRate }
        if let result = RunScoreCalculator.compute(heartRateSamples: hrSamples, distanceSamples: distSamples, maxHeartRate: maxHR) {
            run.runScore = result.totalScore
            run.aerobicTimePoints = result.aerobicTimePoints
            run.pacingControlPoints = result.pacingControlPoints
            run.effortSpikePoints = result.effortSpikePoints
            run.aerobicPercent = result.aerobicPercent
            run.effortSpikeCount = result.spikeCount
        }

        return run
    }
    
    private func heartRateSamples(for workout: HKWorkout) async throws -> [(date: Date, bpm: Double)] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit,
                                       sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let hrSamples = (samples as? [HKQuantitySample]) ?? []
                let unit = HKUnit.count().unitDivided(by: .minute())
                continuation.resume(returning: hrSamples.map { (date: $0.startDate, bpm: $0.quantity.doubleValue(for: unit)) })
            }
            healthStore.execute(query)
        }
    }

    private func distanceSamples(for workout: HKWorkout) async throws -> [(date: Date, meters: Double)] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
            let query = HKSampleQuery(sampleType: distanceType, predicate: predicate, limit: HKObjectQueryNoLimit,
                                       sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let distSamples = (samples as? [HKQuantitySample]) ?? []
                continuation.resume(returning: distSamples.map { (date: $0.startDate, meters: $0.quantity.doubleValue(for: .meter())) })
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Background sync (Req 3)

    func registerObserverQuery(onNewWorkout: @escaping (RunWorkout) -> Void) {
        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completionHandler, error in
            guard let self, error == nil else {
                completionHandler()
                return
            }
            Task {
                do {
                    let start = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
                    let recent = try await self.fetchRunningWorkouts(since: start)
                    if let latest = recent.first {
                        onNewWorkout(latest)
                    }
                } catch {
                    print("Background sync error, will retry on next notification: \(error)")
                }
                completionHandler() // signals completion within the system time budget
            }
        }
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { _, _ in }
    }
}
