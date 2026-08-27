//
//  RunScoreCalculatorTests.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 8/26/26.
//

import XCTest
@testable import PaceCaster

final class RunScoreCalculatorTests: XCTestCase {

    func testSteadyRun_scoresHighAerobicAndPacing() {
        let start = Date()
        var hrSamples: [(date: Date, bpm: Double)] = []
        var distSamples: [(date: Date, endDate: Date, meters: Double)] = []

        for i in 0..<30 {
            let t = start.addingTimeInterval(Double(i) * 60)
            hrSamples.append((date: t, bpm: 140)) // steady, well below 90% of 200 max
            distSamples.append((date: t, endDate: t.addingTimeInterval(60), meters: 200))
        }

        let result = RunScoreCalculator.compute(heartRateSamples: hrSamples, distanceSamples: distSamples, maxHeartRate: 200)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.effortSpikePoints, 20) // zero spikes
        XCTAssertGreaterThan(result!.aerobicTimePoints, 40) // mostly aerobic (140/200 = 70%, below 80% ceiling)
    }

    func testSingleSustainedSpike_countsAsOneSpike() {
        let start = Date()
        var hrSamples: [(date: Date, bpm: Double)] = []
        for i in 0..<20 {
            let t = start.addingTimeInterval(Double(i) * 30)
            // First 5 samples below anaerobic floor, rest sustained above it — one continuous spike.
            hrSamples.append((date: t, bpm: i < 5 ? 140 : 190)) // 190/200 = 95%, above 90% floor
        }
        let distSamples = hrSamples.map { (date: $0.date, endDate: $0.date.addingTimeInterval(30), meters: 100.0) }

        let result = RunScoreCalculator.compute(heartRateSamples: hrSamples, distanceSamples: distSamples, maxHeartRate: 200)
        XCTAssertEqual(result?.spikeCount, 1)
    }

    func testMultipleSeparateSpikes_countedIndividually() {
        let start = Date()
        // Pattern: low, high, low, high, low — two separate spikes.
        let pattern: [Double] = [140, 140, 190, 190, 140, 140, 190, 190, 140, 140]
        var hrSamples: [(date: Date, bpm: Double)] = []
        for (i, bpm) in pattern.enumerated() {
            hrSamples.append((date: start.addingTimeInterval(Double(i) * 30), bpm: bpm))
        }
        let distSamples = hrSamples.map { (date: $0.date, endDate: $0.date.addingTimeInterval(30), meters: 100.0) }

        let result = RunScoreCalculator.compute(heartRateSamples: hrSamples, distanceSamples: distSamples, maxHeartRate: 200)
        XCTAssertEqual(result?.spikeCount, 2)
    }

    func testTooFewSamples_returnsNil() {
        let hrSamples: [(date: Date, bpm: Double)] = [(date: Date(), bpm: 140)]
        let result = RunScoreCalculator.compute(heartRateSamples: hrSamples, distanceSamples: [], maxHeartRate: 200)
        XCTAssertNil(result)
    }

    func testZeroMaxHeartRate_returnsNil() {
        let hrSamples = (0..<15).map { (date: Date().addingTimeInterval(Double($0) * 10), bpm: 140.0) }
        let result = RunScoreCalculator.compute(heartRateSamples: hrSamples, distanceSamples: [], maxHeartRate: 0)
        XCTAssertNil(result)
    }

    func testZonePercentages_sumToOneHundred() {
        let start = Date()
        var hrSamples: [(date: Date, bpm: Double)] = []
        let bpmPattern: [Double] = [130, 150, 170, 190, 145, 165, 185, 135, 155, 175, 195, 140, 160, 180, 150]
        for (i, bpm) in bpmPattern.enumerated() {
            hrSamples.append((date: start.addingTimeInterval(Double(i) * 60), bpm: bpm))
        }
        let distSamples = hrSamples.map { (date: $0.date, endDate: $0.date.addingTimeInterval(60), meters: 200.0) }

        let result = RunScoreCalculator.compute(heartRateSamples: hrSamples, distanceSamples: distSamples, maxHeartRate: 200)
        XCTAssertNotNil(result)
        let sum = result!.aerobicPercent + result!.tempoPercent + result!.anaerobicPercent
        XCTAssertEqual(sum, 100.0, accuracy: 0.5)
    }
}
