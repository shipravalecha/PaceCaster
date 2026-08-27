//
//  SplitCalculatorTests.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 8/26/26.
//
import XCTest
@testable import PaceCaster

@MainActor
final class SplitCalculatorTests: XCTestCase {

    func testComputeSplits_exactlyTwoMiles() {
        let totalMeters = 1609.344 * 2
        var timeline: [(elapsedSeconds: Double, cumulativeMeters: Double)] = []
        for i in 0...20 {
            let fraction = Double(i) / 20.0
            timeline.append((elapsedSeconds: fraction * 1000, cumulativeMeters: fraction * totalMeters))
        }

        let splits = SplitCalculator.computeSplits(timeline: timeline, heartRateTimeline: [], unit: .miles)
        let fullSplits = splits.filter { !$0.isPartial }
        XCTAssertEqual(fullSplits.count, 2)
    }
    
    func testComputeSplits_withPartial() {
        let totalMeters = 1609.344 * 2.5
        var timeline: [(elapsedSeconds: Double, cumulativeMeters: Double)] = []
        for i in 0...25 {
            let fraction = Double(i) / 25.0
            timeline.append((elapsedSeconds: fraction * 1200, cumulativeMeters: fraction * totalMeters))
        }

        let splits = SplitCalculator.computeSplits(timeline: timeline, heartRateTimeline: [], unit: .miles)
        XCTAssertEqual(splits.filter { !$0.isPartial }.count, 2)
        XCTAssertEqual(splits.filter { $0.isPartial }.count, 1)
    }

    func testComputeSplits_emptyTimeline_returnsEmpty() {
        let splits = SplitCalculator.computeSplits(timeline: [], heartRateTimeline: [], unit: .miles)
        XCTAssertTrue(splits.isEmpty)
    }

    func testComputeHalfSplit_negativeSplit() {
        let timeline: [(elapsedSeconds: Double, cumulativeMeters: Double)] = [
            (0, 0), (600, 1000), (1100, 2000) // first 1000m took 600s, second 1000m took 500s
        ]
        let result = SplitCalculator.computeHalfSplit(timeline: timeline)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.verdict, .negative)
    }

    func testComputeHalfSplit_positiveSplit() {
        let timeline: [(elapsedSeconds: Double, cumulativeMeters: Double)] = [
            (0, 0), (500, 1000), (1100, 2000) // first half faster, second half slower
        ]
        let result = SplitCalculator.computeHalfSplit(timeline: timeline)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.verdict, .positive)
    }

    func testComputeHalfSplit_evenSplit() {
        let timeline: [(elapsedSeconds: Double, cumulativeMeters: Double)] = [
            (0, 0), (600, 1000), (1200, 2000) // identical pace both halves
        ]
        let result = SplitCalculator.computeHalfSplit(timeline: timeline)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.verdict, .even)
    }
}
