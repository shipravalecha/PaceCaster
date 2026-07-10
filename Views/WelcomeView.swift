//
//  WelcomeView.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 7/9/26.
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var isRequesting = false
    @State private var showSettingsPrompt = false
    var onAuthorized: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "figure.run")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("PaceCaster")
                .font(.largeTitle.bold())
            Text("Pure running metrics. No noise, no social feed — just your own aerobic data, turned into honest race predictions.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Spacer()

            if showSettingsPrompt {
                VStack(spacing: 12) {
                    Text("PaceCaster needs Health access to work. You can grant it anytime in Settings.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 32)
            }

            Button {
                Task { await requestAccess() }
            } label: {
                if isRequesting {
                    ProgressView()
                } else {
                    Text("Continue").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .disabled(isRequesting)

            Spacer()
        }
    }

    private func requestAccess() async {
        isRequesting = true
        do {
            try await healthKitManager.requestAuthorization()
            onAuthorized()
        } catch {
            showSettingsPrompt = true
        }
        isRequesting = false
    }
}
