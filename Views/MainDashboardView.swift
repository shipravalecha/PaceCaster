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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    baselineCard
                    castSlider
                    outputCard
                }
                .padding()
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
        VStack(spacing: 8) {
            if viewModel.isLoading {
                ProgressView()
            } else if let ef = viewModel.aerobicBaselineEF {
                Text("Aerobic Baseline").font(.subheadline).foregroundStyle(.secondary)
                Text(String(format: "%.2f", ef)).font(.system(size: 48, weight: .bold, design: .rounded))
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
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .animation(.easeInOut(duration: 0.1), value: viewModel.predictedFinishTime)
    }
}
