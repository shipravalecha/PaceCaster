//
//  WeeklyRecapView.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 7/22/26.
//

import SwiftUI
import SwiftData

struct WeeklyRecapView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var notificationManager: NotificationManager
    
    var showsDoneButton: Bool = false

    @State private var thisWeekRuns: [RunWorkout] = []
    @State private var lastWeekRuns: [RunWorkout] = []

    var body: some View {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    statsGrid
                    if let bestRun = bestScoredRun {
                        bestRunCard(bestRun)
                    }
                    trendCard
                }
                .padding()
            }
            .navigationTitle("Weekly Recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsDoneButton {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            notificationManager.pendingDeepLinkToRecap = false
                            dismiss()
                        }
                    }
                }
            }
            .onAppear(perform: loadData)
        }

    private var header: some View {
        VStack(spacing: 4) {
            Text(dateRangeLabel).font(.subheadline).foregroundStyle(.secondary)
            Text("\(thisWeekRuns.count) \(thisWeekRuns.count == 1 ? "run" : "runs") this week")
                .font(.title2.weight(.bold))
        }
        .frame(maxWidth: .infinity)
    }

    private var statsGrid: some View {
        HStack(spacing: 16) {
            statBox(title: "Distance", value: distanceDisplay)
            statBox(title: "Time", value: durationDisplay)
            statBox(title: "Avg Score", value: avgScoreDisplay)
        }
    }

    private func statBox(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.weight(.bold))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func bestRunCard(_ run: RunWorkout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Best Run").font(.headline)
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
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vs Last Week").font(.headline)
            Text(trendMessage).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func loadData() {
        print("🟡 loadData() called")
        let now = Date()
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now)!

        let descriptor = FetchDescriptor<RunWorkout>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        let all = (try? modelContext.fetch(descriptor)) ?? []

        thisWeekRuns = all.filter { $0.startDate >= weekAgo && $0.startDate <= now }
        lastWeekRuns = all.filter { $0.startDate >= twoWeeksAgo && $0.startDate < weekAgo }
    }

    private var dateRangeLabel: String {
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -7, to: end)!
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    private var totalDistanceMeters: Double {
        thisWeekRuns.reduce(0) { $0 + ($1.distanceMeters ?? 0) }
    }

    private var distanceDisplay: String {
        let unitDistance = settings.measurementUnit == .miles ? totalDistanceMeters / 1609.344 : totalDistanceMeters / 1000.0
        return String(format: "%.1f %@", unitDistance, settings.measurementUnit == .miles ? "mi" : "km")
    }

    private var durationDisplay: String {
        let totalSeconds = thisWeekRuns.reduce(0) { $0 + $1.durationSeconds }
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private var avgScoreDisplay: String {
        let scores = thisWeekRuns.compactMap { $0.runScore }
        guard !scores.isEmpty else { return "--" }
        return "\(scores.reduce(0, +) / scores.count)"
    }

    private var bestScoredRun: RunWorkout? {
        thisWeekRuns.filter { $0.runScore != nil }.max { ($0.runScore ?? 0) < ($1.runScore ?? 0) }
    }

    private var trendMessage: String {
        let thisWeekDistance = totalDistanceMeters
        let lastWeekDistance = lastWeekRuns.reduce(0) { $0 + ($1.distanceMeters ?? 0) }

        guard lastWeekDistance > 0 else {
            return thisWeekRuns.isEmpty ? "No runs logged this week." : "Nice work — keep the momentum going next week."
        }
        let percentChange = ((thisWeekDistance - lastWeekDistance) / lastWeekDistance) * 100
        if abs(percentChange) < 5 {
            return "About the same distance as last week."
        } else if percentChange > 0 {
            return String(format: "You ran %.0f%% more than last week.", percentChange)
        } else {
            return String(format: "You ran %.0f%% less than last week.", abs(percentChange))
        }
    }
}
