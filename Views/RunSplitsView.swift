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
}
