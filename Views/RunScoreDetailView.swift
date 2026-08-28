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
    @State private var selectedIndex: Int = 0
    @State private var showRoute = false
    @State private var showSplits = false

    @Environment(\.dismiss) private var dismiss
    
    private var displayedRun: RunWorkout? {
        guard scoredRuns.indices.contains(selectedIndex) else { return nil }
        return scoredRuns[selectedIndex]
    }
    
    private var canGoOlder: Bool { selectedIndex < scoredRuns.count - 1 }
    private var canGoNewer: Bool { selectedIndex > 0 }

    private func goOlder() {
        guard canGoOlder else { return }
        selectedIndex += 1
    }

    private func goNewer() {
        guard canGoNewer else { return }
        selectedIndex -= 1
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 28) {
                    if let run = displayedRun {
                        scoreHeader(for: run)
                            .id("top")
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
            .onChange(of: selectedIndex) { _, _ in
                withAnimation {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
        }
        .navigationTitle("Run Score")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showSplits) {
            if let run = displayedRun {
                RunSplitsView(run: run)
            }
        }
        .navigationDestination(isPresented: $showRoute) {
            if let run = displayedRun {
                RunRouteView(run: run)
            }
        }
    }

    // MARK: - Header

    private func scoreHeader(for run: RunWorkout) -> some View {
        HStack(spacing: 20) {
            Button {
                goOlder()
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title)
                    .foregroundStyle(canGoOlder ? .secondary : Color.secondary.opacity(0.25))
            }
            .disabled(!canGoOlder)
            .accessibilityLabel("Previous run")

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
                .contentShape(Circle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Run Score")
                .accessibilityValue("\(run.runScore ?? 0), \(RunScoreLabel.forScore(run.runScore ?? 0).rawValue)")
                .gesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onEnded { value in
                            let horizontal = value.translation.width
                            let vertical = value.translation.height
                            guard abs(horizontal) > abs(vertical) * 1.5 else { return }
                            if horizontal < 0 {
                                goOlder()
                            } else {
                                goNewer()
                            }
                        }
                )

                Text(run.startDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if let temp = run.weatherTempF, let condition = run.weatherCondition {
                    HStack(spacing: 4) {
                        Image(systemName: weatherIcon(for: condition))
                        Text("\(Int(temp))°F, \(condition)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                if let run = displayedRun {
                    HStack(spacing: 16) {
                        Button("View Splits") {
                            showSplits = true
                        }
                        .font(.caption.weight(.medium))
                        
                        if !run.routeCoordinates.isEmpty {
                            Button("View Route") {
                                showRoute = true
                            }
                            .font(.caption.weight(.medium))
                        }
                    }
                    .padding(.top, 4)
                }

            }

            Button {
                goNewer()
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title)
                    .foregroundStyle(canGoNewer ? .secondary : Color.secondary.opacity(0.25))
            }
            .disabled(!canGoNewer)
            .accessibilityLabel("Next run")
        }
        .frame(maxWidth: .infinity)
    }

    private func factorBreakdown(for run: RunWorkout) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            factorDetail(
                title: "Aerobic Time",
                points: run.aerobicTimePoints ?? 0,
                outOf: 50,
                color: .green,
                stat: aerobicStat(for: run),
                explanation: "Aerobic means a steady, sustainable effort - roughly below 80% of your max heart rate. Tempo is a harder but still controlled effort - around 80-90% of your max. Anaerobic is a near-maximum push that can't be sustained long, it is when your heart rate is over 90% of your max. More aerobic time means your body was working efficiently rather than straining. Aerobic is a great thing, as it helps build endurance. Tempo is great, as it helps build strength. And anaerobic is bad, as it can lead to injury."
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
            
            if let score = run.runScore, score < 50,
               let temp = run.weatherTempF, temp >= 85 {
                HStack(spacing: 8) {
                    Image(systemName: "thermometer.sun")
                        .foregroundStyle(.orange)
                    Text("It was \(Int(temp))°F during this run - heat can significantly affect heart rate and pacing, independent of fitness.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func factorDetail(title: String, points: Int, outOf: Int, color: Color, stat: String, explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(title).font(.headline)
                Spacer()
                Text("\(points)/\(outOf)").font(.headline).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            Text(stat)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Text(explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func aerobicStat(for run: RunWorkout) -> String {
        guard let aerobic = run.aerobicPercent else { return "Not enough data for this run." }
        let tempo = run.tempoPercent ?? 0
        let anaerobic = run.anaerobicPercent ?? 0
        return String(format: "%.0f%% aerobic · %.0f%% tempo · %.0f%% anaerobic", aerobic, tempo, anaerobic)
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

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Run History")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(scoredRuns) { run in
                    Button {
                        if let index = scoredRuns.firstIndex(where: { $0.healthKitUUID == run.healthKitUUID }) {
                            selectedIndex = index
                        }
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
        .background(run.healthKitUUID == displayedRun?.healthKitUUID ? Color.secondary.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(run.startDate.formatted(date: .abbreviated, time: .omitted)), score \(run.runScore ?? 0)")
        .accessibilityAddTraits(.isButton)
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 90...: return .green
        case 70..<90: return .blue
        case 50..<70: return .orange
        default: return .red
        }
    }
    
    private func weatherIcon(for condition: String) -> String {
        switch condition {
        case "Clear": return "sun.max"
        case "Partly Cloudy": return "cloud.sun"
        case "Foggy": return "cloud.fog"
        case "Drizzle", "Rain", "Rain Showers": return "cloud.rain"
        case "Snow", "Snow Showers": return "cloud.snow"
        case "Thunderstorm": return "cloud.bolt.rain"
        default: return "cloud"
        }
    }
}
