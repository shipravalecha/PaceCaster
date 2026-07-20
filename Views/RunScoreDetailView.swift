//
//  RunScoreDetailView.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 7/20/26.
//

import SwiftUI

struct RunScoreDetailView: View {
    let scoredRuns: [RunWorkout]
    @EnvironmentObject private var settings: AppSettings

    @State private var selectedRun: RunWorkout?
    @Environment(\.dismiss) private var dismiss

    private var displayedRun: RunWorkout? {
        selectedRun ?? scoredRuns.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                if let run = displayedRun {
                    scoreHeader(for: run)
                    factorBreakdown(for: run)
                }

                if settings.maxHRIsEstimated {
                    maxHRNudge
                }

                howItWorksSection

                if scoredRuns.count > 1 {
                    historySection
                }
            }
            .padding()
        }
        .navigationTitle("Run Score")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private func scoreHeader(for run: RunWorkout) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: CGFloat(run.runScore ?? 0) / 100)
                    .stroke(scoreColor(run.runScore ?? 0), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(run.runScore ?? 0)").font(.system(size: 32, weight: .bold, design: .rounded))
                    Text(RunScoreLabel.forScore(run.runScore ?? 0).rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, height: 120)

            Text(run.startDate.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Factor breakdown

    private func factorBreakdown(for run: RunWorkout) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            factorDetail(
                title: "Aerobic Time",
                points: run.aerobicTimePoints ?? 0,
                outOf: 50,
                color: .green,
                stat: aerobicStat(for: run),
                explanation: "Measures how much of your run stayed in a steady, sustainable effort - roughly below 80% of your max heart rate. More aerobic time means your body was working efficiently rather than straining."
            )
            Divider()
            factorDetail(
                title: "Pacing Control",
                points: run.pacingControlPoints ?? 0,
                outOf: 30,
                color: .blue,
                stat: pacingStat(for: run),
                explanation: "Looks at how consistent your effort stayed from start to finish. Starting too fast and fading, or surging on and off, lowers this score. Steady effort throughout scores higher."
            )
            Divider()
            factorDetail(
                title: "Effort Spikes",
                points: run.effortSpikePoints ?? 0,
                outOf: 20,
                color: .orange,
                stat: spikeStat(for: run),
                explanation: "Counts how many separate times your heart rate crossed into a hard, near-maximum zone during the run - not how long you spent there. One sustained hard push counts as a single spike; several short hard bursts count as multiple. Fewer spikes means steadier, more controlled effort, which is why more points here is better even though \"spikes\" sounds like a bad thing."
            )
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func factorDetail(title: String, points: Int, outOf: Int, color: Color, stat: String, explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title).font(.headline)
                Spacer()
                Text("\(points)/\(outOf)").font(.headline).foregroundStyle(.secondary)
            }
            Text(stat)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Text(explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func aerobicStat(for run: RunWorkout) -> String {
        guard let percent = run.aerobicPercent else { return "Not enough data for this run." }
        return String(format: "You spent about %.0f%% of this run in your aerobic zone.", percent)
    }

    private func pacingStat(for run: RunWorkout) -> String {
        switch run.pacingControlPoints ?? 0 {
        case 24...30: return "Your effort stayed very steady throughout."
        case 12..<24: return "Your effort had some ups and downs."
        default: return "Your effort varied significantly during this run."
        }
    }

    private func spikeStat(for run: RunWorkout) -> String {
        let count = run.effortSpikeCount ?? 0
        if count == 0 { return "No hard effort spikes detected." }
        return count == 1 ? "1 hard effort spike detected." : "\(count) hard effort spikes detected."
    }

    // MARK: - Max HR nudge

    private var maxHRNudge: some View {
        NavigationLink {
            HealthSyncSettingsView()
        } label: {
            HStack {
                Image(systemName: "heart.text.square")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Using an estimated max heart rate")
                        .font(.subheadline.weight(.medium))
                    Text("Set your real max heart rate in Settings for a more accurate Run Score.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - How it works

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How Run Score works")
                .font(.headline)
            Text("Run Score grades a single run out of 100, combining how much time you spent training aerobically, how consistent your effort stayed, and how many hard efforts you had. It's calculated using your heart rate during the run and your max heart rate - not just your pace.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Run History")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(scoredRuns) { run in
                    Button {
                        selectedRun = run
                    } label: {
                        historyRow(for: run)
                    }
                    .buttonStyle(.plain)

                    if run.id != scoredRuns.last?.id {
                        Divider()
                    }
                }
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func historyRow(for run: RunWorkout) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(run.startDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.medium))
                if let distance = run.distanceMeters {
                    Text(String(format: "%.1f mi", distance / 1609.344))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(run.runScore ?? 0)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(scoreColor(run.runScore ?? 0))
        }
        .padding()
        .background(run.id == displayedRun?.id ? Color.secondary.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())   // ← makes the entire row (including empty space) tappable
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 90...: return .green
        case 70..<90: return .blue
        case 50..<70: return .orange
        default: return .red
        }
    }
}
