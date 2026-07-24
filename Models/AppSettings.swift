//
//  AppSettings.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 7/9/26.
//

import Foundation
import Combine

enum MeasurementUnit: String, CaseIterable, Identifiable {
    case miles, kilometers
    var id: String { rawValue }
    var label: String { self == .miles ? "Miles" : "Kilometers" }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var measurementUnit: MeasurementUnit {
        didSet { UserDefaults.standard.set(measurementUnit.rawValue, forKey: Keys.unit) }
    }
    
    @Published var weeklyRecapEnabled: Bool {
        didSet { UserDefaults.standard.set(weeklyRecapEnabled, forKey: Keys.weeklyRecapEnabled) }
    }
    
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.onboarded) }
    }
    
    @Published var lastSyncedAt: Date? {
        didSet {
            if let lastSyncedAt {
                UserDefaults.standard.set(lastSyncedAt, forKey: Keys.lastSynced)
            }
        }
    }
    
    @Published var maxHeartRate: Int {
        didSet { UserDefaults.standard.set(maxHeartRate, forKey: Keys.maxHR) }
    }
    
    @Published var maxHRIsEstimated: Bool {
        didSet { UserDefaults.standard.set(maxHRIsEstimated, forKey: Keys.maxHRIsEstimated) }
    }

    private enum Keys {
        static let unit = "measurementUnit"
        static let onboarded = "hasCompletedOnboarding"
        static let lastSynced = "lastSyncedAt"
        static let maxHR = "maxHeartRate"
        static let maxHRIsEstimated = "maxHRIsEstimated"
        static let weeklyRecapEnabled = "weeklyRecapEnabled"
    }

    private init() {
        weeklyRecapEnabled = UserDefaults.standard.bool(forKey: Keys.weeklyRecapEnabled)
        if let saved = UserDefaults.standard.string(forKey: Keys.unit),
           let unit = MeasurementUnit(rawValue: saved) {
            measurementUnit = unit
        } else {
            // Req 11.4: default by locale region
            let isUS = Locale.current.region?.identifier == "US"
            measurementUnit = isUS ? .miles : .kilometers
        }
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Keys.onboarded)
        lastSyncedAt = UserDefaults.standard.object(forKey: Keys.lastSynced) as? Date
        
        if UserDefaults.standard.object(forKey: Keys.maxHR) != nil {
            maxHeartRate = UserDefaults.standard.integer(forKey: Keys.maxHR)
            maxHRIsEstimated = UserDefaults.standard.bool(forKey: Keys.maxHRIsEstimated)
        } else {
            maxHeartRate = AppSettings.estimatedMaxHR(age: 35) // generic fallback until the user sets a real value
            maxHRIsEstimated = true
        }
    }
    
    static func estimatedMaxHR(age: Int) -> Int {
        Int((208 - 0.7 * Double(age)).rounded()) // Tanaka formula
    }
}
