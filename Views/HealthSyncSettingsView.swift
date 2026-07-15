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
                Button("Clear Test Data", role: .destructive) {
                    DebugSeeder.clear(modelContext: modelContext)
                }
            }
            #endif
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
