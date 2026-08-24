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
    @State private var authorizedButNotScanned = false
    @EnvironmentObject private var notificationManager: NotificationManager

    var body: some View {
            Group {
                if isScanning {
                    scanningView
                } else if settings.hasCompletedOnboarding || didFinishSetup {
                    if !settings.hasCompletedMaxHRSetup {
                        MaxHRSetupView {
                            // no-op; hasCompletedMaxHRSetup flip re-renders into MainDashboardView
                        }
                    } else {
                        MainDashboardView()
                    }
                } else if authorizedButNotScanned {
                    if !settings.hasCompletedMaxHRSetup {
                        MaxHRSetupView {
                            Task { await runInitialScan() }
                        }
                    } else {
                        Color.clear
                            .onAppear { Task { await runInitialScan() } }
                    }
                } else {
                    WelcomeView {
                        authorizedButNotScanned = true
                    }
                }
            }
            .task {
                if settings.hasCompletedOnboarding {
                    registerSync()
                }
                settings.clearGoalRaceIfPast()
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
        MilestoneChecker.rebuildAllMilestones(modelContext: modelContext, notifyForRunUUID: nil)
        RunScoreRecalculator.recalculateAll(modelContext: modelContext, maxHeartRate: settings.maxHeartRate)
        settings.lastSyncedAt = Date()

        healthKitManager.registerObserverQuery { newWorkout in
            Task { @MainActor in
                self.insertIfNew(newWorkout)
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
                let wasNew = self.insertIfNew(newWorkout)
                try? self.modelContext.save()
                self.settings.lastSyncedAt = Date()
                if wasNew {
                    MilestoneChecker.rebuildAllMilestones(modelContext: self.modelContext, notifyForRunUUID: newWorkout.healthKitUUID)
                }
            }
        }
    }

    @discardableResult
    private func insertIfNew(_ workout: RunWorkout) -> Bool {
        WorkoutSyncHelper.insertIfNew(workout, modelContext: modelContext)
    }
}
