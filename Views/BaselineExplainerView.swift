//
//  BaselineExplainerView.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 7/15/26.
//

import SwiftUI

struct BaselineExplainerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    formulaCard

                    explainerSection(
                        title: "What it measures",
                        body: "Your Aerobic Baseline shows how much speed you get for every heartbeat. A higher number means your heart is working less to hold the same pace - a sign of improving aerobic fitness."
                    )

                    explainerSection(
                        title: "Where it comes from",
                        body: "It's calculated from your most recent qualifying run - one longer than 20 minutes, with a steady heart rate throughout. Shorter runs or runs missing heart rate data aren't used, since they can't produce a reliable reading."
                    )

                    explainerSection(
                        title: "Why it can seem to \"lag\"",
                        body: "If your last run didn't qualify, your baseline will still show your most recent good run instead - with a note explaining why. This keeps the number honest rather than computing it from a run that wouldn't give a meaningful reading."
                    )

                    explainerSection(
                        title: "Rising vs falling",
                        body: "The arrow next to your baseline compares it to your previous qualifying run. A rising baseline generally means your training is working; a falling one can mean fatigue, heat, or an off day - not necessarily lost fitness."
                    )
                }
                .padding()
            }
            .navigationTitle("Aerobic Baseline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var formulaCard: some View {
        VStack(spacing: 12) {
            Text("Aerobic Efficiency Factor (EF)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                labelBox("Speed", subtitle: "m/s")
                Text("÷").font(.title3).foregroundStyle(.secondary)
                labelBox("Heart Rate", subtitle: "bpm")
                Text("× 100").font(.title3).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func labelBox(_ title: String, subtitle: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.subheadline.weight(.medium))
            Text(subtitle).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private func explainerSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(body).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
