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
    var effortSpikeCount: Int?

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
}
