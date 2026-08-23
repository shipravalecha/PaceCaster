//
//  MaxHRSetupView.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 8/21/26.
//

import SwiftUI

struct MaxHRSetupView: View {
    @EnvironmentObject private var settings: AppSettings
    var onContinue: () -> Void

    @State private var mode: Mode = .choosing
    @State private var ageInput = ""
    @State private var maxHRInput = ""

    private enum Mode {
        case choosing, enteringAge, enteringMaxHR
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.text.square")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("One More Thing")
                .font(.largeTitle.bold())

            Text("PaceCaster uses your max heart rate to power Run Score - grading how well each run was paced, not just how fast.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            Spacer()

            switch mode {
            case .choosing:
                choosingButtons
            case .enteringAge:
                ageEntry
            case .enteringMaxHR:
                maxHREntry
            }

            Spacer()
        }
        .padding()
    }

    private var choosingButtons: some View {
        VStack(spacing: 12) {
            Button {
                mode = .enteringMaxHR
            } label: {
                Text("I Know my Max Heart Rate").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
                mode = .enteringAge
            } label: {
                Text("Estimate From my Age").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button("Skip for now") {
                finish()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
        .padding(.horizontal, 32)
    }

    private var ageEntry: some View {
        VStack(spacing: 16) {
            TextField("Age", text: $ageInput)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title2)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            if let message = ageValidationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
            }

            Button {
                if let age = Int(ageInput), isValidAge(age) {
                    settings.maxHeartRate = AppSettings.estimatedMaxHR(age: age)
                    settings.maxHRIsEstimated = true
                    finish()
                }
            } label: {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isAgeInputValid)

            Button("Back") { mode = .choosing }
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 32)
    }

    private func isValidAge(_ age: Int) -> Bool {
        age >= 10 && age < 100
    }

    private var isAgeInputValid: Bool {
        guard let age = Int(ageInput) else { return false }
        return isValidAge(age)
    }

    private var ageValidationMessage: String? {
        guard !ageInput.isEmpty else { return nil }
        guard let age = Int(ageInput) else {
            return "Enter a number."
        }
        if !isValidAge(age) {
            return "Enter an age between 10 and 99."
        }
        return nil
    }

    private var maxHREntry: some View {
        VStack(spacing: 16) {
            HStack {
                TextField("bpm", text: $maxHRInput)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.title2)
                Text("bpm").foregroundStyle(.secondary)
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            if let message = maxHRValidationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
            }

            Button {
                if let hr = Int(maxHRInput), isValidMaxHR(hr) {
                    settings.maxHeartRate = hr
                    settings.maxHRIsEstimated = false
                    finish()
                }
            } label: {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isMaxHRInputValid)

            Button("Back") { mode = .choosing }
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 32)
    }

    private func isValidMaxHR(_ hr: Int) -> Bool {
        hr >= 100 && hr <= 230
    }

    private var isMaxHRInputValid: Bool {
        guard let hr = Int(maxHRInput) else { return false }
        return isValidMaxHR(hr)
    }

    private var maxHRValidationMessage: String? {
        guard !maxHRInput.isEmpty else { return nil }
        guard let hr = Int(maxHRInput) else {
            return "Enter a number."
        }
        if hr < 100 {
            return "That seems low for a max heart rate - most adults fall between 140-220 bpm. Double check the number."
        }
        if hr > 230 {
            return "That seems high for a max heart rate - most adults fall between 140-220 bpm. Double check the number."
        }
        return nil
    }

    private func finish() {
        settings.hasCompletedMaxHRSetup = true
        onContinue()
    }
}
