//
//  WorkoutSyncHelper.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 7/28/26.
//

import Foundation
import SwiftData

@MainActor
enum WorkoutSyncHelper {
    @discardableResult
    static func insertIfNew(_ workout: RunWorkout, modelContext: ModelContext) -> Bool {
        let uuid = workout.healthKitUUID
        let descriptor = FetchDescriptor<RunWorkout>(predicate: #Predicate { $0.healthKitUUID == uuid })
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return false }
        
        workout.shoeID = AppSettings.shared.currentShoeID
        modelContext.insert(workout)
        try? modelContext.save()
        return true
    }
}
