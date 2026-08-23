//
//  RunScoreCalculator.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 7/15/26.
//

import Foundation

enum RunScoreLabel: String {
    case high = "High"
    case good = "Good"
    case fair = "Fair"
    case low = "Low"

    static func forScore(_ score: Int) -> RunScoreLabel {
        switch score {
        case 90...: return .high
        case 70..<90: return .good
        case 50..<70: return .fair
        default: return .low
        }
    }
}

struct RunScoreResult {
    let totalScore: Int
    let aerobicTimePoints: Int      // out of 50
    let pacingControlPoints: Int    // out of 30
    let effortSpikePoints: Int      // out of 20
    let aerobicPercent: Double
    let tempoPercent: Double
    let anaerobicPercent: Double
    let spikeCount: Int
}

enum RunScoreCalculator {

    /// heartRateSamples: raw HR samples, sorted ascending by date.
    /// distanceSamples: incremental distance samples (meters recorded at that instant), sorted ascending.
    static func compute(
        heartRateSamples: [(date: Date, bpm: Double)],
        distanceSamples: [(date: Date, endDate: Date, meters: Double)],
        maxHeartRate: Int
    ) -> RunScoreResult? {
        guard heartRateSamples.count >= 10 else { return nil }
        let maxHR = Double(maxHeartRate)
        guard maxHR > 0 else { return nil }
        let aerobicCeiling = maxHR * 0.80
        let anaerobicFloor = maxHR * 0.90

        var aerobicSeconds: Double = 0
        var tempoSeconds: Double = 0
        var anaerobicSeconds: Double = 0
        var totalSeconds: Double = 0
        var spikeCount = 0
        var wasAboveThreshold = false

        for i in 0..<(heartRateSamples.count - 1) {
            let current = heartRateSamples[i]
            let next = heartRateSamples[i + 1]
            let interval = next.date.timeIntervalSince(current.date)
            guard interval > 0 else { continue }
            totalSeconds += interval
            
            if current.bpm < aerobicCeiling {
                aerobicSeconds += interval
            } else if current.bpm < anaerobicFloor {
                tempoSeconds += interval
            } else {
                anaerobicSeconds += interval
            }
            
            let isAboveThreshold = current.bpm >= anaerobicFloor
            if isAboveThreshold && !wasAboveThreshold {
                spikeCount += 1
            }
            wasAboveThreshold = isAboveThreshold
        }

        guard totalSeconds > 0 else { return nil }
        let aerobicPercent = aerobicSeconds / totalSeconds
        let tempoPercent = tempoSeconds / totalSeconds
        let anaerobicPercent = anaerobicSeconds / totalSeconds

        // Full 50 points at 90%+ time spent aerobic
        let aerobicTimePoints = min(50, Int(((aerobicPercent / 0.9) * 50).rounded()))

        let pacingControlPoints = computePacingControl(
            heartRateSamples: heartRateSamples,
            distanceSamples: distanceSamples
        )

        // 0 spikes = full 20 points, each spike costs 4, floor at 0
        let effortSpikePoints = max(0, 20 - (spikeCount * 4))

        let total = aerobicTimePoints + pacingControlPoints + effortSpikePoints
        return RunScoreResult(
                totalScore: total,
                aerobicTimePoints: aerobicTimePoints,
                pacingControlPoints: pacingControlPoints,
                effortSpikePoints: effortSpikePoints,
                aerobicPercent: aerobicPercent * 100,
                tempoPercent: tempoPercent * 100,
                anaerobicPercent: anaerobicPercent * 100,
                spikeCount: spikeCount
            )
    }

    /// Buckets the run into 60-second windows, computes EF per bucket, and scores
    /// consistency (lower variability across buckets = better pacing discipline).
    private static func computePacingControl(
        heartRateSamples: [(date: Date, bpm: Double)],
        distanceSamples: [(date: Date, endDate: Date, meters: Double)]
    ) -> Int {
        guard let start = heartRateSamples.first?.date, let end = heartRateSamples.last?.date, end > start else {
            return 15
        }

        let bucketSize: TimeInterval = 60
        var bucketEFs: [Double] = []
        var bucketStart = start

        while bucketStart < end {
            let bucketEnd = bucketStart.addingTimeInterval(bucketSize)
            let hrInBucket = heartRateSamples.filter { $0.date >= bucketStart && $0.date < bucketEnd }

            // Prorate each distance sample across every bucket it overlaps,
            // instead of dumping its whole value into one bucket based on start time alone.
            var totalDist: Double = 0
            for sample in distanceSamples {
                let sampleDuration = sample.endDate.timeIntervalSince(sample.date)
                guard sampleDuration > 0 else { continue }
                let overlapStart = max(sample.date, bucketStart)
                let overlapEnd = min(sample.endDate, bucketEnd)
                let overlap = overlapEnd.timeIntervalSince(overlapStart)
                if overlap > 0 {
                    let fraction = overlap / sampleDuration
                    totalDist += sample.meters * fraction
                }
            }

            if !hrInBucket.isEmpty, totalDist > 0 {
                let avgHR = hrInBucket.reduce(0) { $0 + $1.bpm } / Double(hrInBucket.count)
                let speed = totalDist / bucketSize
                if avgHR > 0 {
                    bucketEFs.append((speed / avgHR) * 100)
                }
            }
            bucketStart = bucketEnd
        }

        guard bucketEFs.count >= 3 else { return 20 }

        let mean = bucketEFs.reduce(0, +) / Double(bucketEFs.count)
        guard mean > 0 else { return 15 }
        let variance = bucketEFs.reduce(0) { $0 + pow($1 - mean, 2) } / Double(bucketEFs.count)
        let coefficientOfVariation = sqrt(variance) / mean

        let points = max(0, 30 - Int(((coefficientOfVariation / 0.5) * 30).rounded()))
        return min(30, points)
    }
}
extension RunScoreCalculator {
    /// Always computes fresh from a run's raw timelines and the given Max Heart
    /// Rate — never trust a previously stored score, since it can go stale the
    /// moment Max Heart Rate changes.
    static func compute(for run: RunWorkout, maxHeartRate: Int) -> RunScoreResult? {
        let hrSamples = run.heartRateTimeline.map {
            (date: run.startDate.addingTimeInterval($0.elapsedSeconds), bpm: $0.bpm)
        }

        let distSamples = run.distanceTimeline.enumerated().map { index, point -> (date: Date, endDate: Date, meters: Double) in
            let date = run.startDate.addingTimeInterval(point.elapsedSeconds)
            // Distance samples in the score calculator represent an interval
            // (date...endDate) with an incremental meters value — approximate
            // each stored cumulative point as a short interval ending at the
            // next point (or a small fixed window for the last point).
            let nextElapsed = index + 1 < run.distanceTimeline.count
                ? run.distanceTimeline[index + 1].elapsedSeconds
                : point.elapsedSeconds + 1
            let endDate = run.startDate.addingTimeInterval(nextElapsed)
            let incrementalMeters = index > 0
                ? point.cumulativeMeters - run.distanceTimeline[index - 1].cumulativeMeters
                : point.cumulativeMeters
            return (date: date, endDate: endDate, meters: incrementalMeters)
        }

        return compute(heartRateSamples: hrSamples, distanceSamples: distSamples, maxHeartRate: maxHeartRate)
    }
}
