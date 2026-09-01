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
        
        workout.shoeID = currentShoeID(for: workout.startDate, modelContext: modelContext)
        modelContext.insert(workout)
        try? modelContext.save()
        return true
    }

    private static func currentShoeID(for runDate: Date, modelContext: ModelContext) -> UUID? {
        guard let shoeID = AppSettings.shared.currentShoeID else { return nil }
        let descriptor = FetchDescriptor<Shoe>(predicate: #Predicate { $0.id == shoeID })
        guard let shoe = (try? modelContext.fetch(descriptor))?.first else { return nil }
        return runDate >= shoe.startDate ? shoeID : nil
    }
    
    #if DEBUG
    static func fixMistaggedShoeRuns(modelContext: ModelContext) {
        let shoeDescriptor = FetchDescriptor<Shoe>()
        let shoes = (try? modelContext.fetch(shoeDescriptor)) ?? []
        let runDescriptor = FetchDescriptor<RunWorkout>()
        let runs = (try? modelContext.fetch(runDescriptor)) ?? []

        var fixedCount = 0
        for run in runs {
            guard let shoeID = run.shoeID,
                  let shoe = shoes.first(where: { $0.id == shoeID }) else { continue }
            if run.startDate < shoe.startDate {
                run.shoeID = nil
                fixedCount += 1
            }
        }
        try? modelContext.save()
        print("🥾 Untagged \(fixedCount) runs that predated their assigned shoe's start date")
    }
    #endif
}
