//
//  MainDashboardView.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 7/9/26.
//

import SwiftUI
import SwiftData

struct MainDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showBaselineInfo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    baselineCard
                    runScoreSection
                    castSlider
                    outputCard
                }
                .padding()
                .sheet(isPresented: $showBaselineInfo) {
                    BaselineExplainerView()
                }
            }
            .navigationTitle("PaceCaster")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: MetricsAnalyticsView()) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: HealthSyncSettingsView()) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .onAppear { viewModel.configure(modelContext: modelContext) }
        }
    }

    private var baselineCard: some View {
        VStack(spacing: 12) {
            if viewModel.isLoading {
                ProgressView()
            } else if let ef = viewModel.aerobicBaselineEF {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Aerobic Baseline").font(.subheadline).foregroundStyle(.secondary)
                        Button {
                            showBaselineInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Text(String(format: "%.2f", ef)).font(.system(size: 48, weight: .bold, design: .rounded))
                        if let direction = viewModel.efTrendDirection, let percent = viewModel.efTrendPercentDisplay {
                            trendBadge(direction: direction, percent: percent)
                        }
                    }

                    if let date = viewModel.baselineDate {
                        Text("from run on \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Divider()

                VStack(spacing: 8) {
                    Text("Last Run")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    HStack(spacing: 20) {
                        VStack(spacing: 2) {
                            Text("Distance").font(.caption).foregroundStyle(.secondary)
                            Text(viewModel.latestRunDistanceDisplay).font(.headline)
                        }
                        VStack(spacing: 2) {
                            Text("Pace").font(.caption).foregroundStyle(.secondary)
                            Text(viewModel.latestRunPaceDisplay).font(.headline)
                        }
                        VStack(spacing: 2) {
                            Text("Heart Rate").font(.caption).foregroundStyle(.secondary)
                                Text(viewModel.latestRunHRDisplay)
                                    .font(.headline)
                                    .foregroundStyle(
                                        viewModel.latestRunHRIsFlagged ? .red :
                                        (viewModel.latestRunHRDisplay == "No data" ? .secondary : .primary)
                                    )

                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                if let note = viewModel.recentRunNote {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
            } else {
                Text("Complete a run longer than 20 minutes with heart rate data to see your Aerobic Baseline.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var runScoreSection: some View {
        Group {
            if viewModel.runScore != nil {
                NavigationLink {
                    RunScoreDetailView(scoredRuns: viewModel.scoredRuns)
                } label: {
                    runScoreCard
                }
                .buttonStyle(.plain)
            } else {
                runScoreCard
            }
        }
    }
    
    private var runScoreCard: some View {
        VStack(spacing: 16) {
            if let score = viewModel.runScore, let label = viewModel.runScoreLabel {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Run Score").font(.subheadline).foregroundStyle(.secondary)
                        Text(label).font(.title2.weight(.bold))
                    }
                    Spacer()
                    ZStack {
                        Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: CGFloat(score) / 100)
                            .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(score)").font(.title3.weight(.bold))
                    }
                    .frame(width: 64, height: 64)
                    
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(spacing: 10) {
                    factorRow(title: "Aerobic Time", points: viewModel.aerobicTimePoints ?? 0, outOf: 50, color: .green)
                    factorRow(title: "Pacing Control", points: viewModel.pacingControlPoints ?? 0, outOf: 30, color: .blue)
                    factorRow(title: "Effort Spikes", points: viewModel.effortSpikePoints ?? 0, outOf: 20, color: .orange)
                }
            } else {
                Text("Run Score needs more heart rate data from your last run to calculate.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var spikeSubtitle: String {
        guard let count = viewModel.effortSpikeCount else { return "" }
        if count == 0 { return "No anaerobic spikes" }
        return count == 1 ? "1 anaerobic spike detected" : "\(count) anaerobic spikes detected"
    }

    private func factorRow(title: String, points: Int, outOf: Int, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).font(.subheadline)
            Spacer()
            Text("\(points)/\(outOf)").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
        }
    }
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 90...: return .green
        case 70..<90: return .blue
        case 50..<70: return .orange
        default: return .red
        }
    }

    private var castSlider: some View {
        VStack(spacing: 12) {
            Text("Cast Slider").font(.headline)
            Picker("Target Distance", selection: Binding(
                get: { viewModel.targetDistance },
                set: { viewModel.selectTargetDistance($0) }
            )) {
                ForEach(TargetDistance.allCases) { distance in
                    Text(distance.label).tag(distance)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var outputCard: some View {
        VStack(spacing: 16) {
            if let message = viewModel.predictionUnavailableMessage {
                Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 4) {
                    Text("Predicted Finish").font(.subheadline).foregroundStyle(.secondary)
                    Text(viewModel.predictedFinishTime).font(.system(size: 36, weight: .semibold, design: .rounded))
                }
                VStack(spacing: 4) {
                    Text("Target Split").font(.subheadline).foregroundStyle(.secondary)
                    Text(viewModel.splitPace).font(.title2.weight(.medium))
                }
                if let basis = viewModel.castBasisDisplay {
                    Text(basis)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .animation(.easeInOut(duration: 0.1), value: viewModel.predictedFinishTime)
    }
    
    @ViewBuilder
    private func trendBadge(direction: DashboardViewModel.EFTrendDirection, percent: String) -> some View {
        let (icon, color): (String, Color) = {
            switch direction {
            case .up: return ("arrow.up", .green)
            case .down: return ("arrow.down", .red)
            case .flat: return ("minus", .secondary)
            }
        }()

        HStack(spacing: 2) {
            Image(systemName: icon)
            Text(percent)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
        .padding(.bottom, 8) // align baseline with the large number's baseline
    }
}
