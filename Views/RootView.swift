//
//  RootView.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 7/9/26.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @Environment(\.modelContext) private var modelContext
    @State private var isScanning = false
    @State private var didFinishSetup = false
    @EnvironmentObject private var notificationManager: NotificationManager

    var body: some View {
        Group {
            if settings.hasCompletedOnboarding || didFinishSetup {
                if isScanning {
                    scanningView
                } else {
                    MainDashboardView()
                }
            } else {
                WelcomeView {
                    Task { await runInitialScan() }
                }
            }
        }
        .task {
                // Re-register the observer on every cold launch, not just the first one.
                if settings.hasCompletedOnboarding {
                    registerSync()
                }
            }
        .sheet(isPresented: $notificationManager.pendingDeepLinkToRecap) {
            NavigationStack {
                WeeklyRecapView(showsDoneButton: true)
            }
        }
    }

    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Scanning the last 90 days of your running history…")
                .foregroundStyle(.secondary)
        }
    }

    private func runInitialScan() async {
        isScanning = true
        let workouts = (try? await healthKitManager.scanLast90Days()) ?? []
        for workout in workouts {
            insertIfNew(workout)
        }
        try? modelContext.save()
        settings.lastSyncedAt = Date()

        healthKitManager.registerObserverQuery { newWorkout in
            Task { @MainActor in
                self.insertIfNew(newWorkout)
                try? self.modelContext.save()
                self.settings.lastSyncedAt = Date()
            }
        }

        settings.hasCompletedOnboarding = true
        didFinishSetup = true
        isScanning = false
    }
    
    private func registerSync() {
        healthKitManager.registerObserverQuery { newWorkout in
            Task { @MainActor in
                self.insertIfNew(newWorkout)
                try? self.modelContext.save()
                self.settings.lastSyncedAt = Date()
            }
        }
    }

    /// Req 2.6: dedupe by HealthKit workout UUID
    private func insertIfNew(_ workout: RunWorkout) {
        let uuid = workout.healthKitUUID
        let descriptor = FetchDescriptor<RunWorkout>(predicate: #Predicate { $0.healthKitUUID == uuid })
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        if existing.isEmpty {
            modelContext.insert(workout)
        }
    }
}
