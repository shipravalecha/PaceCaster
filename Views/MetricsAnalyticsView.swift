//
//  MetricsAnalyticsView.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 7/9/26.
//

import SwiftUI
import SwiftData
import Charts

struct MetricsAnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = AnalyticsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Trends").font(.largeTitle.bold())
                Picker("Window", selection: Binding(
                    get: { viewModel.timeWindowDays },
                    set: { viewModel.selectTimeWindow($0) }
                )) {
                    Text("30d").tag(30)
                    Text("60d").tag(60)
                    Text("90d").tag(90)
                }
                .pickerStyle(.segmented)

                efficiencySection
                volumeSection
                TrainingLoadSection()
                MilestonesSection()
            }
            .padding()
        }
        .onAppear { viewModel.configure(modelContext: modelContext) }
    }

    private var efficiencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aerobic Efficiency Trend").font(.headline)

            if viewModel.efTrend.count < 2 {
                Text(viewModel.efTrend.isEmpty
                     ? "No qualifying runs in this window yet to chart your efficiency trend."
                     : "Only 1 qualifying run in this window - you need at least 2 to chart your efficiency trend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(viewModel.efTrend) { point in
                    LineMark(x: .value("Date", point.date), y: .value("EF", point.value))
                }
                .frame(height: 200)
            }
        }
    }

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Volume").font(.headline)

            if viewModel.weeklyVolume.isEmpty {
                Text("No running workouts recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(viewModel.weeklyVolume) { week in
                    BarMark(x: .value("Week", week.weekStart, unit: .weekOfYear),
                            y: .value("Distance", week.distanceInUnit))
                }
                .frame(height: 200)
            }
        }
    }
}
