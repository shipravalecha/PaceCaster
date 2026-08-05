//
//  SplitExplainerView.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 8/5/26.
//

import SwiftUI

struct SplitExplainerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    explainerSection(
                        title: "What is a split?",
                        body: "A split compares your pace in the first half of a run to your pace in the second half - it tells you the story of how your effort changed over the run, not just the average."
                    )
                    explainerSection(
                        title: "Negative Split",
                        body: "Despite the name, this is the good outcome - it means you ran the 2nd half faster than the 1st. It's a sign you paced yourself well and had energy left to finish strong, rather than burning out early."
                    )
                    explainerSection(
                        title: "Positive Split",
                        body: "This means you slowed down in the 2nd half. It usually means you started faster than you could sustain - very common, and not something to be discouraged by, just useful to notice."
                    )
                    explainerSection(
                        title: "Even Split",
                        body: "Your pace stayed nearly identical throughout - very consistent, controlled effort."
                    )
                }
                .padding()
            }
            .navigationTitle("About Splits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func explainerSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(body).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
