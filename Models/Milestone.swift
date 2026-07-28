//
//  Milestone.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 7/28/26.
//

import Foundation
import SwiftData

enum MilestoneType: String, Codable {
    case bestEF = "Best Aerobic Baseline"
    case bestRunScore = "Best Run Score"
    case longestRun = "Longest Run"

    var emoji: String {
        switch self {
        case .bestEF: return "🥇"
        case .bestRunScore: return "🏆"
        case .longestRun: return "🎖️"
        }
    }

    var notificationTitle: String {
        "\(emoji) New \(rawValue)!"
    }
}

@Model
final class Milestone {
    @Attribute(.unique) var id: UUID
    var typeRawValue: String
    var achievedDate: Date
    var value: Double          // the EF, score, or distance that earned it
    var runHealthKitUUID: UUID // which run earned it, for reference

    var type: MilestoneType {
        MilestoneType(rawValue: typeRawValue) ?? .bestEF
    }

    init(type: MilestoneType, achievedDate: Date, value: Double, runHealthKitUUID: UUID) {
        self.id = UUID()
        self.typeRawValue = type.rawValue
        self.achievedDate = achievedDate
        self.value = value
        self.runHealthKitUUID = runHealthKitUUID
    }
}
