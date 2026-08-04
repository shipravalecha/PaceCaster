//
//  SplitCalculator.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 8/3/26.
//
import Foundation

struct Split: Identifiable {
    let id: Int
    let label: String
    let splitSeconds: Double
    let splitDistanceMeters: Double
    let avgHeartRate: Double?
    let isPartial: Bool
}


enum SplitCalculator {
    static func computeSplits(
        timeline: [(elapsedSeconds: Double, cumulativeMeters: Double)],
        heartRateTimeline: [(elapsedSeconds: Double, bpm: Double)],
        unit: MeasurementUnit
    ) -> [Split] {
        guard !timeline.isEmpty else { return [] }
        let sorted = timeline.sorted { $0.elapsedSeconds < $1.elapsedSeconds }
        let unitMeters = unit == .miles ? 1609.344 : 1000.0

        var splits: [Split] = []
        var nextThreshold = unitMeters
        var lastSplitTime: Double = 0
        var splitIndex = 1
        var prevPoint: (elapsedSeconds: Double, cumulativeMeters: Double) = (0, 0)

        func avgHR(from start: Double, to end: Double) -> Double? {
            let inRange = heartRateTimeline.filter { $0.elapsedSeconds >= start && $0.elapsedSeconds < end }
            guard !inRange.isEmpty else { return nil }
            return inRange.reduce(0) { $0 + $1.bpm } / Double(inRange.count)
        }

        for point in sorted {
            while point.cumulativeMeters >= nextThreshold {
                let distRange = point.cumulativeMeters - prevPoint.cumulativeMeters
                let timeRange = point.elapsedSeconds - prevPoint.elapsedSeconds
                let fraction = distRange > 0 ? (nextThreshold - prevPoint.cumulativeMeters) / distRange : 0
                let crossingTime = prevPoint.elapsedSeconds + timeRange * fraction

                let splitDuration = crossingTime - lastSplitTime
                let label = unit == .miles ? "Mile \(splitIndex)" : "Km \(splitIndex)"
                splits.append(Split(
                    id: splitIndex, label: label, splitSeconds: splitDuration,
                    splitDistanceMeters: unitMeters,
                    avgHeartRate: avgHR(from: lastSplitTime, to: crossingTime), isPartial: false
                ))

                lastSplitTime = crossingTime
                splitIndex += 1
                nextThreshold += unitMeters
            }
            prevPoint = point
        }

        guard let lastPoint = sorted.last else { return splits }
        let remainingDistance = lastPoint.cumulativeMeters - (nextThreshold - unitMeters)
        if remainingDistance > 10 {
            let splitDuration = lastPoint.elapsedSeconds - lastSplitTime
            let unitAbbrev = unit == .miles ? "mi" : "km"
            let label = String(format: "%.2f %@ (partial)", remainingDistance / unitMeters, unitAbbrev)
            splits.append(Split(
                id: splitIndex, label: label, splitSeconds: splitDuration,
                splitDistanceMeters: remainingDistance,
                avgHeartRate: avgHR(from: lastSplitTime, to: lastPoint.elapsedSeconds), isPartial: true
            ))
        }

        return splits
    }

    static func formatPace(seconds: Double, distanceMeters: Double, unit: MeasurementUnit) -> String {
        guard seconds.isFinite, seconds > 0, distanceMeters > 0 else { return "--" }
        let unitMeters = unit == .miles ? 1609.344 : 1000.0
        let paceSecondsPerUnit = seconds / (distanceMeters / unitMeters)
        let m = Int(paceSecondsPerUnit) / 60
        let s = Int(paceSecondsPerUnit) % 60
        return String(format: "%d'%02d\"", m, s)
    }

    static func formatDuration(seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
