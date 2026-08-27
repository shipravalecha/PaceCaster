//
//  EfficiencyCalculatorTests.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 8/26/26.
//
import XCTest
@testable import PaceCaster

final class EfficiencyCalculatorTests: XCTestCase {
    
    func testComputeEF_knownValues() {
        // EF = (speed / HR) * 100
        let ef = EfficiencyCalculator.computeEF(averageSpeedMetersPerSecond: 3.0, averageHeartRateBPM: 150)
        XCTAssertNotNil(ef)
        XCTAssertEqual(ef!, 2.0, accuracy: 0.0001)
    }

    func testComputeEF_zeroHeartRate_returnsNil() {
        let ef = EfficiencyCalculator.computeEF(averageSpeedMetersPerSecond: 3.0, averageHeartRateBPM: 0)
        XCTAssertNil(ef)
    }

    func testRoundTrip_recomputeMatchesOriginal() {
        // FOR ALL EF values, recomputing from stored speed/HR should reproduce EF exactly.
        let speed = 3.35
        let hr = 152.0
        let ef = EfficiencyCalculator.computeEF(averageSpeedMetersPerSecond: speed, averageHeartRateBPM: hr)!
        let recomputed = (speed / hr) * 100
        XCTAssertEqual(ef, recomputed, accuracy: 0.0001)
    }
}
