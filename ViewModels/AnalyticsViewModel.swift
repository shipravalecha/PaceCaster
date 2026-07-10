//
//  AnalyticsViewModel.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 7/9/26.
//

import Foundation
import Combine
import SwiftData

struct EFPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct WeeklyVolume: Identifiable {
    let id = UUID()
    let weekStart: Date
    let distanceInUnit: Double
}

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var timeWindowDays: Int = 30
    @Published var efTrend: [EFPoint] = []
    @Published var weeklyVolume: [WeeklyVolume] = []

    private var modelContext: ModelContext?
    private var allWorkouts: [RunWorkout] = []
    private let settings: AppSettings

    init(settings: AppSettings? = nil) {
            self.settings = settings ?? AppSettings.shared
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        reload()
    }

    func reload() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<RunWorkout>(sortBy: [SortDescriptor(\.startDate)])
        allWorkouts = (try? modelContext.fetch(descriptor)) ?? []
        updateTrend()
        updateWeeklyVolume()
    }

    func selectTimeWindow(_ days: Int) {
        timeWindowDays = days
        updateTrend()
    }

    private func updateTrend() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -timeWindowDays, to: Date()) ?? Date()
        efTrend = allWorkouts
            .filter { $0.startDate >= cutoff && $0.efficiencyFactor != nil }
            .map { EFPoint(date: $0.startDate, value: $0.efficiencyFactor!) }
    }

    private func updateWeeklyVolume() {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: allWorkouts) { workout -> Date in
            calendar.dateInterval(of: .weekOfYear, for: workout.startDate)?.start ?? workout.startDate
        }
        weeklyVolume = grouped.map { weekStart, workouts in
            let totalMeters = workouts.reduce(0.0) { $0 + ($1.distanceMeters ?? 0) }
            let converted = settings.measurementUnit == .miles ? totalMeters / 1609.344 : totalMeters / 1000.0
            return WeeklyVolume(weekStart: weekStart, distanceInUnit: converted)
        }.sorted { $0.weekStart < $1.weekStart }
    }
}
