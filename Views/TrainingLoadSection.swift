//
//  TrainingLoadSection.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 8/4/26.
//

import SwiftUI
import SwiftData

struct TrainingLoadSection: View {
    @Environment(\.modelContext) private var modelContext
    @State private var result: TrainingLoadResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Load").font(.headline)

            if let result, let ratio = result.ratio {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(result.status.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(result.status.color)
                        Spacer()
                        Text(String(format: "%.2fx", ratio))
                            .font(.subheadline.weight(.bold))
                    }

                    ProgressView(value: min(ratio, 2.0), total: 2.0)
                        .tint(result.status.color)

                    Text(message(for: result.status, ratio: ratio))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            } else {
                Text("Keep logging runs — we need about 3 weeks of history to gauge your training load.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
        .onAppear(perform: loadData)
    }

    private func loadData() {
        let descriptor = FetchDescriptor<RunWorkout>()
        let allRuns = (try? modelContext.fetch(descriptor)) ?? []
        result = TrainingLoadCalculator.compute(from: allRuns)
    }

    private func message(for status: TrainingLoadStatus, ratio: Double) -> String {
        switch status {
        case .low:
            return "Your mileage this week is lower than your recent average. That's fine — just worth noting if it wasn't planned."
        case .normal:
            return "Your training load is in a sustainable range compared to your recent average."
        case .elevated:
            return "Your mileage this week is higher than your recent average. Keep an eye on how your body responds."
        case .high:
            let percent = Int((ratio - 1) * 100)
            return "Your mileage this week is \(percent)% higher than your recent average. This kind of jump is linked to higher injury risk — consider easing up slightly."
        }
    }
}
