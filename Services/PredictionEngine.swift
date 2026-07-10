//
//  PredictionEngine.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 7/9/26.
//

import Foundation

enum TargetDistance: CaseIterable, Identifiable, Hashable {
    case fiveK, tenK, fifteenK, halfMarathon

    var id: Self { self }

    var meters: Double {
        switch self {
        case .fiveK: return 5000
        case .tenK: return 10000
        case .fifteenK: return 15000
        case .halfMarathon: return 21097.5
        }
    }

    var label: String {
        switch self {
        case .fiveK: return "5K"
        case .tenK: return "10K"
        case .fifteenK: return "15K"
        case .halfMarathon: return "Half"
        }
    }
}

struct Cast {
    let finishTimeSeconds: Double
    let targetDistance: TargetDistance
}

enum PredictionEngine {
    /// Riegel's Formula: T2 = T1 * (D2/D1)^1.06
    static func predict(baselineDurationSeconds: Double,
                         baselineDistanceMeters: Double,
                         targetDistance: TargetDistance) -> Cast? {
        guard baselineDurationSeconds > 0, baselineDistanceMeters > 0 else { return nil }
        let ratio = targetDistance.meters / baselineDistanceMeters
        let t2 = baselineDurationSeconds * pow(ratio, 1.06)
        return Cast(finishTimeSeconds: t2, targetDistance: targetDistance)
    }

    static func formatFinishTime(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    static func splitPace(finishTimeSeconds: Double, distanceMeters: Double, unit: MeasurementUnit) -> String {
        let unitDistance = unit == .miles ? distanceMeters / 1609.344 : distanceMeters / 1000.0
        guard unitDistance > 0 else { return "--:--" }
        let secondsPerUnit = finishTimeSeconds / unitDistance
        let m = Int(secondsPerUnit) / 60
        let s = Int(secondsPerUnit) % 60
        let suffix = unit == .miles ? "/mi" : "/km"
        return String(format: "%d:%02d %@", m, s, suffix)
    }
}
