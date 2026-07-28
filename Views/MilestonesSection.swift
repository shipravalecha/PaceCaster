//
//  MilestonesSection.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 7/28/26.
//

import SwiftUI
import SwiftData

struct MilestonesSection: View {
    @Environment(\.modelContext) private var modelContext
    @State private var milestones: [Milestone] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestones").font(.headline)

            if milestones.isEmpty {
                Text("Keep running - your first milestone is on its way.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                VStack(spacing: 0) {
                    ForEach(milestones) { milestone in
                        milestoneRow(milestone)
                        if milestone.id != milestones.last?.id {
                            Divider()
                        }
                    }
                }
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .onAppear(perform: loadMilestones)
    }

    private func milestoneRow(_ milestone: Milestone) -> some View {
        HStack(spacing: 12) {
            Text(milestone.type.emoji).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.type.rawValue).font(.subheadline.weight(.medium))
                Text(milestone.achievedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(valueDisplay(for: milestone))
                .font(.subheadline.weight(.semibold))
        }
        .padding()
    }

    private func valueDisplay(for milestone: Milestone) -> String {
        switch milestone.type {
        case .bestEF:
            return String(format: "%.2f", milestone.value)
        case .bestRunScore:
            return "\(Int(milestone.value))"
        case .longestRun:
            return String(format: "%.1f mi", milestone.value / 1609.344)
        }
    }

    private func loadMilestones() {
        let descriptor = FetchDescriptor<Milestone>(sortBy: [SortDescriptor(\.achievedDate, order: .reverse)])
        milestones = (try? modelContext.fetch(descriptor)) ?? []
    }
}
