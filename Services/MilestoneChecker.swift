import Foundation
import SwiftData

@MainActor
enum MilestoneChecker {
    private static let efImprovementThreshold = 0.005
    private static let scoreImprovementThreshold = 1
    private static let distanceImprovementThreshold = 50.0

    static func rebuildAllMilestones(modelContext: ModelContext, notifyForRunUUID: UUID?) {
        try? modelContext.delete(model: Milestone.self)

        let descriptor = FetchDescriptor<RunWorkout>(sortBy: [SortDescriptor(\.startDate, order: .forward)])
        let chronological = (try? modelContext.fetch(descriptor)) ?? []
        let maxHR = AppSettings.shared.maxHeartRate

        var bestEF: Double = 0
        var bestScore: Int = 0
        var bestDistance: Double = 0
        var lastInserted: [MilestoneType: Milestone] = [:]

        for run in chronological {
            if let ef = run.efficiencyFactor {
                if ef > bestEF + efImprovementThreshold {
                    upsert(.bestEF, value: ef, run: run, modelContext: modelContext,
                           notify: run.healthKitUUID == notifyForRunUUID, lastInserted: &lastInserted)
                }
                bestEF = max(bestEF, ef)
            }
            if let result = RunScoreCalculator.compute(for: run, maxHeartRate: maxHR) {
                let score = result.totalScore
                if score > bestScore + scoreImprovementThreshold {
                    upsert(.bestRunScore, value: Double(score), run: run, modelContext: modelContext,
                           notify: run.healthKitUUID == notifyForRunUUID, lastInserted: &lastInserted)
                }
                bestScore = max(bestScore, score)
            }
            if let distance = run.distanceMeters {
                if distance > bestDistance + distanceImprovementThreshold {
                    upsert(.longestRun, value: distance, run: run, modelContext: modelContext,
                           notify: run.healthKitUUID == notifyForRunUUID, lastInserted: &lastInserted)
                }
                bestDistance = max(bestDistance, distance)
            }
        }
        try? modelContext.save()
    }
    
    private static func upsert(
        _ type: MilestoneType, value: Double, run: RunWorkout, modelContext: ModelContext,
        notify: Bool, lastInserted: inout [MilestoneType: Milestone]
    ) {
        let calendar = Calendar.current
        if let existing = lastInserted[type], calendar.isDate(existing.achievedDate, inSameDayAs: run.startDate) {
            existing.value = value
            existing.runHealthKitUUID = run.healthKitUUID
        } else {
            let milestone = Milestone(type: type, achievedDate: run.startDate, value: value, runHealthKitUUID: run.healthKitUUID)
            modelContext.insert(milestone)
            lastInserted[type] = milestone
        }
        if notify {
            NotificationManager.shared.sendMilestoneNotification(type: type, value: value)
        }
    }
}
