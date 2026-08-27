//
//  PredictionEngineTests.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 8/26/26.
//

import XCTest
@testable import PaceCaster

final class PredictionEngineTests: XCTestCase {

    func testRiegelFormula_doublingDistance() {
        // T2 = T1 * (D2/D1)^1.06 — a known reference case
        let cast = PredictionEngine.predict(
            baselineDurationSeconds: 1200, // 20 min for 5000m
            baselineDistanceMeters: 5000,
            targetDistance: .tenK
        )
        XCTAssertNotNil(cast)
        // 1200 * 2^1.06 ≈ 2501.9 seconds - verified independently
        XCTAssertEqual(cast!.finishTimeSeconds, 2501.9, accuracy: 1.0)
    }

    func testPredict_zeroBaselineDuration_returnsNil() {
        let cast = PredictionEngine.predict(baselineDurationSeconds: 0, baselineDistanceMeters: 5000, targetDistance: .fiveK)
        XCTAssertNil(cast)
    }

    func testPredict_zeroBaselineDistance_returnsNil() {
        let cast = PredictionEngine.predict(baselineDurationSeconds: 1200, baselineDistanceMeters: 0, targetDistance: .fiveK)
        XCTAssertNil(cast)
    }

    func testFormatFinishTime_roundsCorrectly() {
        XCTAssertEqual(PredictionEngine.formatFinishTime(3661), "01:01:01")
        XCTAssertEqual(PredictionEngine.formatFinishTime(59.6), "00:01:00")
    }

    func testSplitPace_miles() {
        // 3000s / (5000m / 1609.344) ≈ 965.66 sec/mi → 16:05/mi (truncated to whole seconds)
        let pace = PredictionEngine.splitPace(finishTimeSeconds: 3000, distanceMeters: 5000, unit: .miles)
        XCTAssertEqual(pace, "16:05 /mi")
    }

    func testSplitPace_kilometers() {
        let pace = PredictionEngine.splitPace(finishTimeSeconds: 1500, distanceMeters: 5000, unit: .kilometers)
        XCTAssertEqual(pace, "5:00 /km")
    }

    func testSplitPace_zeroDistance_returnsPlaceholder() {
        let pace = PredictionEngine.splitPace(finishTimeSeconds: 1500, distanceMeters: 0, unit: .miles)
        XCTAssertEqual(pace, "--:--")
    }

    func testTargetDistance_meterValues() {
        XCTAssertEqual(TargetDistance.fiveK.meters, 5000)
        XCTAssertEqual(TargetDistance.tenK.meters, 10000)
        XCTAssertEqual(TargetDistance.fifteenK.meters, 15000)
        XCTAssertEqual(TargetDistance.halfMarathon.meters, 21097.5)
    }
}
