//
//  SplitCalculator.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 8/3/26.
//
import Foundation
import SwiftUI

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

enum SplitVerdict {
    case negative  // 2nd half faster — the good outcome
    case positive  // 2nd half slower — faded
    case even      // basically the same

    var label: String {
        switch self {
        case .negative: return "Negative Split"
        case .positive: return "Positive Split"
        case .even: return "Even Split"
        }
    }

    var color: Color {
        switch self {
        case .negative: return .green
        case .positive: return .orange
        case .even: return .blue
        }
    }

    var icon: String {
        switch self {
        case .negative: return "arrow.down.right.circle.fill"
        case .positive: return "arrow.up.right.circle.fill"
        case .even: return "equal.circle.fill"
        }
    }
}

struct HalfSplitResult {
    let firstHalfPaceSeconds: Double
    let secondHalfPaceSeconds: Double
    let verdict: SplitVerdict
    let differenceSeconds: Double // always positive; how far apart the two halves were
}

extension SplitCalculator {
    /// Compares pace in the first half of the run's distance vs. the second half.
    static func computeHalfSplit(
        timeline: [(elapsedSeconds: Double, cumulativeMeters: Double)]
    ) -> HalfSplitResult? {
        guard let last = timeline.max(by: { $0.cumulativeMeters < $1.cumulativeMeters }),
              last.cumulativeMeters > 0 else { return nil }

        let sorted = timeline.sorted { $0.elapsedSeconds < $1.elapsedSeconds }
        let totalDistance = last.cumulativeMeters
        let halfwayDistance = totalDistance / 2

        // Find the elapsed time at the halfway distance point via linear interpolation.
        var halfwayTime: Double?
        var prev: (elapsedSeconds: Double, cumulativeMeters: Double) = (0, 0)
        for point in sorted {
            if point.cumulativeMeters >= halfwayDistance {
                let distRange = point.cumulativeMeters - prev.cumulativeMeters
                let timeRange = point.elapsedSeconds - prev.elapsedSeconds
                let fraction = distRange > 0 ? (halfwayDistance - prev.cumulativeMeters) / distRange : 0
                halfwayTime = prev.elapsedSeconds + timeRange * fraction
                break
            }
            prev = point
        }

        guard let halfwayTime, let totalTime = sorted.last?.elapsedSeconds, totalTime > halfwayTime else {
            return nil
        }

        let firstHalfDuration = halfwayTime
        let secondHalfDuration = totalTime - halfwayTime
        guard firstHalfDuration > 0, secondHalfDuration > 0 else { return nil }

        // Pace = seconds per meter, scaled up; since both halves cover the same
        // distance (by definition), comparing raw durations is equivalent to
        // comparing pace, but we express it as pace-per-unit for display later.
        let firstHalfPace = firstHalfDuration / (halfwayDistance / 1609.344) // sec per mile, unit-adjusted at display time if needed
        let secondHalfPace = secondHalfDuration / (halfwayDistance / 1609.344)

        let diff = secondHalfPace - firstHalfPace
        let verdict: SplitVerdict
        if abs(diff) < 5 {
            verdict = .even
        } else if diff < 0 {
            verdict = .negative
        } else {
            verdict = .positive
        }

        return HalfSplitResult(
            firstHalfPaceSeconds: firstHalfPace,
            secondHalfPaceSeconds: secondHalfPace,
            verdict: verdict,
            differenceSeconds: abs(diff)
        )
    }
}
