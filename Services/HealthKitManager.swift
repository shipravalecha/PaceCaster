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
        let (avgHR, hrCount) = try await averageHeartRate(for: workout)

        let run = RunWorkout(
            healthKitUUID: workout.uuid,
            startDate: workout.startDate,
            durationSeconds: workout.duration,
            distanceMeters: distanceMeters,
            averageHeartRate: avgHR,
            heartRateSampleCount: hrCount
        )

        if run.isSteadyState, let speed = run.averageSpeedMetersPerSecond, let hr = avgHR {
            run.efficiencyFactor = EfficiencyCalculator.computeEF(averageSpeedMetersPerSecond: speed, averageHeartRateBPM: hr)
        }
        return run
    }

    private func averageHeartRate(for workout: HKWorkout) async throws -> (Double?, Int) {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let hrSamples = (samples as? [HKQuantitySample]) ?? []
                guard !hrSamples.isEmpty else {
                    continuation.resume(returning: (nil, 0))
                    return
                }
                let unit = HKUnit.count().unitDivided(by: .minute())
                let total = hrSamples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
                continuation.resume(returning: (total / Double(hrSamples.count), hrSamples.count))
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
