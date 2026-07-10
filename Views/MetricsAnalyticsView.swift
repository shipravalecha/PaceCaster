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
                efficiencySection
                volumeSection
            }
            .padding()
        }
        .navigationTitle("Trends")
        .onAppear { viewModel.configure(modelContext: modelContext) }
    }

    private var efficiencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aerobic Efficiency Trend").font(.headline)

            Picker("Window", selection: Binding(
                get: { viewModel.timeWindowDays },
                set: { viewModel.selectTimeWindow($0) }
            )) {
                Text("30d").tag(30)
                Text("60d").tag(60)
                Text("90d").tag(90)
            }
            .pickerStyle(.segmented)

            if viewModel.efTrend.count < 2 {
                Text("Not enough data yet to chart your efficiency trend for this window.")
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
