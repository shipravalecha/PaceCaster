//
//  AddShoeView.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 8/30/26.
//

import SwiftUI

struct AddShoeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    var onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("e.g. Pegasus 41", text: $name)
            }
            .navigationTitle("New Shoe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
