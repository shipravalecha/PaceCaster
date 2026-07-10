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
                statusRow(title: "Workouts", type: HKObjectType.workoutType())
                statusRow(title: "Heart Rate", type: HKObjectType.quantityType(forIdentifier: .heartRate)!)
                statusRow(title: "Running Distance", type: HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!)

                Button("Open Health Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
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

    private func statusRow(title: String, type: HKObjectType) -> some View {
        let status = healthKitManager.authorizationStatus(for: type)
        return HStack {
            Text(title)
            Spacer()
            Text(status == .sharingAuthorized ? "Authorized" : "Not Authorized")
                .foregroundStyle(status == .sharingAuthorized ? .green : .red)
        }
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
