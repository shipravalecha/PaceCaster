//
//  HealthSyncSettingsView.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 7/9/26.
//

import SwiftUI
import SwiftData
import HealthKit

struct HealthSyncSettingsView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @State private var showFlushConfirmation = false
    @State private var flushError: String?
    @State private var showAgePrompt = false
    @State private var ageInput = ""
    @FocusState private var maxHRFieldFocused: Bool
    @EnvironmentObject private var notificationManager: NotificationManager
    @State private var isRequestingPermission = false
    @State private var settingsScreenReady = false
    @State private var isSyncing = false
    @State private var isDeleting = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    var body: some View {
        Form {
            Section("HealthKit Access") {
                Text("PaceCaster reads Workouts, Heart Rate, and Running Distance. iOS doesn't let apps check exact read-permission status - you can review or change exactly what's shared in the Health app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Open Health App") {
                    if let url = URL(string: "x-apple-health://") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            
            Section {
                HStack {
                    Text("Last Synced")
                    Spacer()
                    Text(lastSyncedDisplay)
                        .foregroundStyle(.secondary)
                }
            }
            
            Button {
                Task {
                    isSyncing = true
                    statusMessage = nil
                    let workouts = (try? await healthKitManager.scanLast90Days()) ?? []
                    var newCount = 0
                    for workout in workouts {
                        if WorkoutSyncHelper.insertIfNew(workout, modelContext: modelContext) {
                            newCount += 1
                        }
                    }
                    settings.lastSyncedAt = Date()
                    MilestoneChecker.rebuildAllMilestones(modelContext: modelContext, notifyForRunUUID: nil)
                    RunScoreRecalculator.recalculateAll(modelContext: modelContext, maxHeartRate: settings.maxHeartRate)

                    isSyncing = false
                    statusIsError = false
                    statusMessage = newCount > 0 ? "✓ Synced \(newCount) new run\(newCount == 1 ? "" : "s")" : "✓ Already up to date"
                    scheduleStatusDismiss()
                }
            } label: {
                HStack {
                    Text("Sync Now")
                    if isSyncing {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isSyncing)

            Section("Units") {
                Picker("Measurement Unit", selection: $settings.measurementUnit) {
                    ForEach(MeasurementUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
            }
            
            Section {
                NavigationLink("Shoes") {
                    ShoeMileageView()
                }
            } header: {
                Text("Gear")
            } footer: {
                Text("Track mileage on your running shoes and get a nudge when it's time to replace them.")
            }
            
            Section {
                Toggle("Set a Goal Race", isOn: Binding(
                    get: { settings.goalRaceDate != nil },
                    set: { isOn in
                        if isOn {
                            settings.goalRaceDistance = .fiveK
                            settings.goalRaceDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
                        } else {
                            settings.goalRaceDistance = nil
                            settings.goalRaceDate = nil
                        }
                    }
                ))

                if settings.goalRaceDate != nil {
                    Picker("Race Distance", selection: Binding(
                        get: { settings.goalRaceDistance ?? .fiveK },
                        set: { settings.goalRaceDistance = $0 }
                    )) {
                        ForEach(TargetDistance.allCases) { distance in
                            Text(distance.label).tag(distance)
                        }
                    }

                    DatePicker("Race Date", selection: Binding(
                        get: { settings.goalRaceDate ?? Date() },
                        set: { settings.goalRaceDate = $0 }
                    ), displayedComponents: .date)
                }
            } header: {
                Text("Goal Race")
            } footer: {
                Text("Set an upcoming race to see a personalized countdown on your dashboard.")
            }
            
            Section {
                HStack {
                    Text("Max Heart Rate")
                    Spacer()
                    TextField("bpm", value: $settings.maxHeartRate, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                        .focused($maxHRFieldFocused)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
                                    maxHRFieldFocused = false
                                }
                            }
                        }
                    Text("bpm")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    maxHRFieldFocused = true
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Max Heart Rate, \(settings.maxHeartRate) beats per minute")
                .accessibilityHint("Double tap to edit")
                
                .onChange(of: settings.maxHeartRate) { _, _ in
                    if maxHRFieldFocused {
                        settings.maxHRIsEstimated = false
                        RunScoreRecalculator.recalculateAll(modelContext: modelContext, maxHeartRate: settings.maxHeartRate)
                    }
                }

                Button("Estimate from age") {
                    showAgePrompt = true
                }
                if settings.maxHRIsEstimated {
                    Text("Using a generic estimate. Enter your age or your real max heart rate for a more accurate Run Score.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Run Score")
            } footer: {
                Text("Used to determine your aerobic and anaerobic zones during a run.")
            }
            
            Section {
                Button("Delete All Local Data", role: .destructive) {
                    showFlushConfirmation = true
                }
            } footer: {
                Text("Permanently deletes all stored running workouts and computed efficiency data from this device. This cannot be undone.")
            }
            
            #if DEBUG
            Section("Debug") {
                Button("Seed Test Data") {
                    DebugSeeder.seed(into: modelContext)
                }
                Button("Seed Flagged HR Run") {
                    DebugSeeder.seedFlaggedHRRun(into: modelContext)
                }
                Button("Clear Test Data", role: .destructive) {
                    DebugSeeder.clear(modelContext: modelContext)
                }
                Button("Seed Milestone-Beating Run") {
                    DebugSeeder.seedMilestoneBeatingRun(into: modelContext)
                }
                Button("Seed Training Load Spike") {
                    DebugSeeder.seedTrainingLoadSpike(into: modelContext)
                }
                Button("Fix Mistagged Shoe Runs") {
                    WorkoutSyncHelper.fixMistaggedShoeRuns(modelContext: modelContext)
                }
                Button("Seed Run for Current Shoe") {
                    DebugSeeder.seedRunForCurrentShoe(into: modelContext)
                }
                Button("Seed 350mi on Current Shoe") {
                    DebugSeeder.seedShoeMileage(into: modelContext, totalMiles: 350)
                }
                Button("Seed 420mi on Current Shoe") {
                    DebugSeeder.seedShoeMileage(into: modelContext, totalMiles: 420)
                }
            }
            #endif
            
            Section {
                Toggle("Weekly Recap Notification", isOn: $settings.weeklyRecapEnabled)
                    .onChange(of: settings.weeklyRecapEnabled) { _, enabled in
                        Task {
                            if enabled {
                                isRequestingPermission = true
                                defer { isRequestingPermission = false }
                                await notificationManager.requestAuthorizationIfNeeded()
                                try? await Task.sleep(nanoseconds: 400_000_000)
                                if notificationManager.authorizationGranted {
                                    notificationManager.scheduleWeeklyRecap()
                                } else {
                                    settings.weeklyRecapEnabled = false
                                }
                            } else {
                                notificationManager.cancelWeeklyRecap()
                            }
                        }
                    }
                NavigationLink {
                    WeeklyRecapView(showsDoneButton: false)
                } label: {
                    Text("Preview Recap")
                }
                .disabled(isRequestingPermission)
            } header: {
                Text("Weekly Recap")
            } footer: {
                Text("Get a notification every Sunday evening summarizing your training.")
            }
        }
        
        .scrollDismissesKeyboard(.immediately)
        .onDisappear {
            if maxHRFieldFocused {
                settings.maxHRIsEstimated = false
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Delete all running data?", isPresented: $showFlushConfirmation, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) { flushDatabase() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Couldn't Delete Data", isPresented: Binding(get: { flushError != nil }, set: { _ in flushError = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(flushError ?? "")
        }
        .alert("Estimate Max Heart Rate", isPresented: $showAgePrompt) {
            TextField("Age", text: $ageInput).keyboardType(.numberPad)
            Button("Calculate") {
                if let age = Int(ageInput), age > 0 {
                    settings.maxHeartRate = AppSettings.estimatedMaxHR(age: age)
                    settings.maxHRIsEstimated = true
                    RunScoreRecalculator.recalculateAll(modelContext: modelContext, maxHeartRate: settings.maxHeartRate)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We'll estimate your max heart rate using your age.")
        }
        if let statusMessage {
            Text(statusMessage)
                .font(.footnote.weight(.medium))
                .foregroundStyle(statusIsError ? .red : .green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .transition(.opacity)
        }
    }
    
    private var lastSyncedDisplay: String {
        guard let date = settings.lastSyncedAt else { return "Never" }
        return date.formatted(.relative(presentation: .named))
    }

    private func flushDatabase() {
        isDeleting = true
        do {
            try modelContext.delete(model: RunWorkout.self)
            try modelContext.delete(model: Milestone.self)
            try modelContext.save()
            statusIsError = false
            statusMessage = "✓ All data deleted"
        } catch {
            statusIsError = true
            statusMessage = "Something went wrong while deleting your data."
        }
        isDeleting = false
        scheduleStatusDismiss()
    }
    
    private func scheduleStatusDismiss() {
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation {
                statusMessage = nil
            }
        }
    }
}
