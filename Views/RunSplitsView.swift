//
//  RunSplitsView.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 8/3/26.
//

import SwiftUI

struct RunSplitsView: View {
    let run: RunWorkout
    @EnvironmentObject private var settings: AppSettings
    @State private var showSplitInfo = false

    private var splits: [Split] {
        SplitCalculator.computeSplits(
            timeline: run.distanceTimeline,
            heartRateTimeline: run.heartRateTimeline,
            unit: settings.measurementUnit
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
            
                if splits.isEmpty {
                    Text("Split data isn't available for this run. Try syncing again to rebuild it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    splitsTable
                }
                if let halfSplit {
                    halfSplitCard(halfSplit)
                }
            }
            .padding()
        }
        .navigationTitle("Splits")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(run.startDate.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let distance = run.distanceMeters {
                let unitDistance = settings.measurementUnit == .miles ? distance / 1609.344 : distance / 1000.0
                Text(String(format: "%.2f %@", unitDistance, settings.measurementUnit == .miles ? "mi" : "km"))
                    .font(.title2.weight(.bold))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var splitsTable: some View {
        VStack(spacing: 0) {
            tableHeader
            Divider()
            ForEach(splits) { split in
                splitRow(split)
                if split.id != splits.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var tableHeader: some View {
        HStack {
            Text("").frame(width: 20, alignment: .leading)
            Text("Time").frame(maxWidth: .infinity, alignment: .leading)
            Text("Pace").frame(maxWidth: .infinity, alignment: .leading)
            Text("Heart Rate").frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.bottom, 8)
    }

    private func splitRow(_ split: Split) -> some View {
        HStack {
            Text("\(split.id)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .leading)

            Text(SplitCalculator.formatDuration(seconds: split.splitSeconds))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(SplitCalculator.formatPace(seconds: split.splitSeconds, distanceMeters: split.splitDistanceMeters, unit: settings.measurementUnit))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if let hr = split.avgHeartRate {
                    (Text("\(Int(hr))").font(.subheadline.weight(.bold)) + Text(" BPM").font(.caption2))
                } else {
                    Text("--")
                        .font(.subheadline)
                }
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }
    
    private var halfSplit: HalfSplitResult? {
        SplitCalculator.computeHalfSplit(timeline: run.distanceTimeline)
    }
    
    private func halfSplitCard(_ result: HalfSplitResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: result.verdict.icon)
                        .foregroundStyle(result.verdict.color)
                    Text(result.verdict.label)
                        .font(.headline)
                        .foregroundStyle(result.verdict.color)
                }
                Spacer()
                Button {
                    showSplitInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 10) {
                halfRow(label: "1st Half", paceSeconds: result.firstHalfPaceSeconds,
                        isFaster: result.firstHalfPaceSeconds < result.secondHalfPaceSeconds,
                        maxPace: max(result.firstHalfPaceSeconds, result.secondHalfPaceSeconds))
                halfRow(label: "2nd Half", paceSeconds: result.secondHalfPaceSeconds,
                        isFaster: result.secondHalfPaceSeconds < result.firstHalfPaceSeconds,
                        maxPace: max(result.firstHalfPaceSeconds, result.secondHalfPaceSeconds))
            }

            Text(verdictMessage(result))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showSplitInfo) {
            SplitExplainerView()
        }
    }

    private func halfRow(label: String, paceSeconds: Double, isFaster: Bool, maxPace: Double) -> some View {
        // Faster pace = fewer seconds = longer bar, so invert the fraction.
        let fraction = maxPace > 0 ? (1 - (paceSeconds / maxPace)) * 0.6 + 0.4 : 0.5

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.medium))
                if isFaster {
                    Text("Faster")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15), in: Capsule())
                }
                Spacer()
                Text(paceDisplay(paceSeconds))
                    .font(.subheadline.weight(.bold))
            }

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 5)
                    .fill(isFaster ? Color.green : Color.blue)
                    .frame(width: geo.size.width * fraction, height: 8)
            }
            .frame(height: 8)
        }
    }



    private func paceDisplay(_ secondsPerMile: Double) -> String {
        let unitSeconds = settings.measurementUnit == .miles ? secondsPerMile : secondsPerMile / 1.60934
        let m = Int(unitSeconds) / 60
        let s = Int(unitSeconds) % 60
        return String(format: "%d'%02d\"", m, s)
    }

    private func verdictMessage(_ result: HalfSplitResult) -> String {
        let seconds = Int(result.differenceSeconds)
        switch result.verdict {
        case .negative:
            return "Your 2nd half was \(seconds)s/mi faster than your 1st - a strong sign of well-paced effort."
        case .positive:
            return "Your 2nd half was \(seconds)s/mi slower than your 1st - you may have started faster than you could sustain."
        case .even:
            return "Your pace stayed nearly identical across both halves."
        }
    }
}
