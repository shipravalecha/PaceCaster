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
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.onboarded) }
    }

    private enum Keys {
        static let unit = "measurementUnit"
        static let onboarded = "hasCompletedOnboarding"
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: Keys.unit),
           let unit = MeasurementUnit(rawValue: saved) {
            measurementUnit = unit
        } else {
            // Req 11.4: default by locale region
            let isUS = Locale.current.region?.identifier == "US"
            measurementUnit = isUS ? .miles : .kilometers
        }
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Keys.onboarded)
    }
}
