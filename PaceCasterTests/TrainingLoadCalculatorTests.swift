//
//  TrainingLoadCalculatorTests.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 8/26/26.
//

import XCTest
@testable import PaceCaster
import SwiftData

@MainActor
final class TrainingLoadCalculatorTests: XCTestCase {

    private func makeRun(daysAgo: Int, miles: Double, referenceDate: Date) -> RunWorkout {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: referenceDate)!
        return RunWorkout(
            healthKitUUID: UUID(),
            startDate: date,
            durationSeconds: miles * 550,
            distanceMeters: miles * 1609.344,
            averageHeartRate: 150,
            heartRateSampleCount: 20
        )
    }

    func testInsufficientHistory_returnsNilRatio() {
        let now = Date()
        let runs = [makeRun(daysAgo: 1, miles: 3, referenceDate: now)] // only 1 day of history
        let result = TrainingLoadCalculator.compute(from: runs, referenceDate: now)
        XCTAssertNil(result.ratio)
    }

    func testHighSpike_flaggedAsHighRisk() {
        let now = Date()
        var runs: [RunWorkout] = []
        // 3 weeks of baseline ~3mi/week
        for week in [27, 20, 13] {
            runs.append(makeRun(daysAgo: week, miles: 3, referenceDate: now))
        }
        // Last 7 days: a big spike
        runs.append(makeRun(daysAgo: 3, miles: 10, referenceDate: now))
        runs.append(makeRun(daysAgo: 1, miles: 10, referenceDate: now))

        let result = TrainingLoadCalculator.compute(from: runs, referenceDate: now)
        XCTAssertNotNil(result.ratio)
        XCTAssertEqual(result.status, .high)
    }

    func testSteadyLoad_flaggedAsNormal() {
        let now = Date()
        var runs: [RunWorkout] = []
        for week in [27, 26, 25, 20, 19, 18, 13, 12, 11, 6, 5, 4] {
            runs.append(makeRun(daysAgo: week, miles: 3, referenceDate: now))
        }
        let result = TrainingLoadCalculator.compute(from: runs, referenceDate: now)
        XCTAssertNotNil(result.ratio)
        XCTAssertEqual(result.status, .normal)
    }
}
