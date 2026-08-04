//
//  RunWorkout.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 7/9/26.
//

import Foundation
import SwiftData

@Model
final class RunWorkout {
    @Attribute(.unique) var healthKitUUID: UUID
    var startDate: Date
    var durationSeconds: Double
    var distanceMeters: Double?
    var averageHeartRate: Double?
    var heartRateSampleCount: Int
    var efficiencyFactor: Double?
    var runScore: Int?
    var aerobicTimePoints: Int?
    var pacingControlPoints: Int?
    var effortSpikePoints: Int?
    var aerobicPercent: Double?
    var tempoPercent: Double?
    var anaerobicPercent: Double?
    var effortSpikeCount: Int?
    var distanceTimelineData: Data?
    var heartRateTimelineData: Data?

    init(healthKitUUID: UUID,
         startDate: Date,
         durationSeconds: Double,
         distanceMeters: Double? = nil,
         averageHeartRate: Double? = nil,
         heartRateSampleCount: Int = 0,
         efficiencyFactor: Double? = nil) {
        self.healthKitUUID = healthKitUUID
        self.startDate = startDate
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.averageHeartRate = averageHeartRate
        self.heartRateSampleCount = heartRateSampleCount
        self.efficiencyFactor = efficiencyFactor
    }

    /// Req 4.1 / 4.3: duration > 20 min AND at least 10 HR samples
    var isSteadyState: Bool {
        durationSeconds > 1200 && heartRateSampleCount >= 10 && averageHeartRate != nil && distanceMeters != nil
    }

    var averageSpeedMetersPerSecond: Double? {
        guard let distanceMeters else { return nil }
        return distanceMeters / durationSeconds
    }
    
    var distanceTimeline: [(elapsedSeconds: Double, cumulativeMeters: Double)] {
        get {
            guard let data = distanceTimelineData,
                  let raw = try? JSONDecoder().decode([[Double]].self, from: data) else { return [] }
            return raw.compactMap { pair in
                guard pair.count == 2 else { return nil }
                return (pair[0], pair[1])
            }
        }
        set {
            let raw = newValue.map { [$0.elapsedSeconds, $0.cumulativeMeters] }
            distanceTimelineData = try? JSONEncoder().encode(raw)
        }
    }
    
    var heartRateTimeline: [(elapsedSeconds: Double, bpm: Double)] {
        get {
            guard let data = heartRateTimelineData,
                  let raw = try? JSONDecoder().decode([[Double]].self, from: data) else { return [] }
            return raw.compactMap { pair in
                guard pair.count == 2 else { return nil }
                return (pair[0], pair[1])
            }
        }
        set {
            let raw = newValue.map { [$0.elapsedSeconds, $0.bpm] }
            heartRateTimelineData = try? JSONEncoder().encode(raw)
        }
    }
}
