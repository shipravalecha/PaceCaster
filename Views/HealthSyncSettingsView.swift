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

    var body: some View {
        Form {
            Section("HealthKit Access") {
                Text("PaceCaster reads Workouts, Heart Rate, and Running Distance. iOS doesn't let apps check exact read-permission status — you can review or change exactly what's shared in the Health app.")
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
            Button("Sync Now") {
                Task {
                    let workouts = (try? await healthKitManager.scanLast90Days()) ?? []
                    for workout in workouts {
                        let uuid = workout.healthKitUUID
                        let descriptor = FetchDescriptor<RunWorkout>(predicate: #Predicate { $0.healthKitUUID == uuid })
                        if (try? modelContext.fetch(descriptor))?.isEmpty ?? true {
                            modelContext.insert(workout)
                        }
                    }
                    try? modelContext.save()
                    settings.lastSyncedAt = Date()
                }
            }

            Section("Units") {
                Picker("Measurement Unit", selection: $settings.measurementUnit) {
                    ForEach(MeasurementUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
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
                .onChange(of: settings.maxHeartRate) { _, _ in
                    // Only treat this as a manual edit if the field is actively focused —
                    // this excludes programmatic changes like the "Estimate from age" button,
                    // and commits the instant the user types, regardless of how they later
                    // leave the screen (Done, back button, swipe, tap elsewhere).
                    if maxHRFieldFocused {
                        settings.maxHRIsEstimated = false
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
            }
            #endif
        }
        .scrollDismissesKeyboard(.immediately)   // ← tapping/scrolling anywhere dismisses the keyboard
        .onDisappear {
            // Guaranteed fallback: commits "manually confirmed" the moment this
            // screen is left, regardless of how — back button, swipe, or tab switch.
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
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We'll estimate your max heart rate using your age.")
        }
    }
    
    private var lastSyncedDisplay: String {
        guard let date = settings.lastSyncedAt else { return "Never" }
        return date.formatted(.relative(presentation: .named))
    }

    private func flushDatabase() {
        do {
            try modelContext.delete(model: RunWorkout.self)
            try modelContext.save()
        } catch {
            flushError = "Something went wrong while deleting your data. Your existing data has been kept."
        }
    }
}
