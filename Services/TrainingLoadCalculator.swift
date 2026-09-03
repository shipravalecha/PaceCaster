//
//  TrainingLoadCalculator.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 8/4/26.
//

import SwiftUI

enum TrainingLoadStatus {
    case low, normal, elevated, high

    var label: String {
        switch self {
        case .low: return "Reduced Load"
        case .normal: return "Balanced"
        case .elevated: return "Elevated"
        case .high: return "High Risk"
        }
    }

    var color: Color {
        switch self {
        case .low: return .blue
        case .normal: return .green
        case .elevated: return .orange
        case .high: return .red
        }
    }
}

struct TrainingLoadResult {
    let ratio: Double?
    let status: TrainingLoadStatus
}

enum TrainingLoadCalculator {
    static func compute(from workouts: [RunWorkout], referenceDate: Date = Date()) -> TrainingLoadResult {
        let calendar = Calendar.current
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: referenceDate),
              let twentyEightDaysAgo = calendar.date(byAdding: .day, value: -28, to: referenceDate) else {
            return TrainingLoadResult(ratio: nil, status: .normal)
        }

        guard let earliestRun = workouts.map({ $0.startDate }).min(),
              let daysOfHistory = calendar.dateComponents([.day], from: earliestRun, to: referenceDate).day,
              daysOfHistory >= 21 else {
            return TrainingLoadResult(ratio: nil, status: .normal)
        }

        let acuteDistance = workouts
            .filter { $0.startDate >= sevenDaysAgo && $0.startDate <= referenceDate }
            .reduce(0.0) { $0 + ($1.distanceMeters ?? 0) }

        let chronicTotal = workouts
            .filter { $0.startDate >= twentyEightDaysAgo && $0.startDate <= referenceDate }
            .reduce(0.0) { $0 + ($1.distanceMeters ?? 0) }
        let chronicWeeklyAverage = chronicTotal / 4.0

        guard chronicWeeklyAverage > 0 else {
            return TrainingLoadResult(ratio: nil, status: .normal)
        }

        let ratio = acuteDistance / chronicWeeklyAverage
        let status: TrainingLoadStatus
        switch ratio {
        case ..<0.8: status = .low
        case 0.8..<1.3: status = .normal
        case 1.3..<1.5: status = .elevated
        default: status = .high
        }

        return TrainingLoadResult(ratio: ratio, status: status)
    }
}
