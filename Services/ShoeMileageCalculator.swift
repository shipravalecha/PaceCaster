//
//  ShoeMileageCalculator.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 8/28/26.
//

import Foundation

struct ShoeMileage {
    let shoe: Shoe
    let totalMeters: Double
    let runCount: Int

    var miles: Double { totalMeters / 1609.344 }
    var isNearingReplacement: Bool { miles >= 300 && miles < 400 }
    var isPastReplacement: Bool { miles >= 400 }
}

enum ShoeMileageCalculator {
    static func mileage(for shoe: Shoe, allRuns: [RunWorkout]) -> ShoeMileage {
        let runsForShoe = allRuns.filter { $0.shoeID == shoe.id }
        let total = runsForShoe.reduce(0.0) { $0 + ($1.distanceMeters ?? 0) }
        return ShoeMileage(shoe: shoe, totalMeters: total, runCount: runsForShoe.count)
    }
}
