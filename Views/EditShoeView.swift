//
//  EditShoeView.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 9/1/26.
//

import SwiftUI
import SwiftData

struct EditShoeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let shoe: Shoe
    var onSave: () -> Void

    @State private var name: String
    @State private var startDate: Date

    init(shoe: Shoe, onSave: @escaping () -> Void) {
        self.shoe = shoe
        self.onSave = onSave
        _name = State(initialValue: shoe.name)
        _startDate = State(initialValue: shoe.startDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Shoe name", text: $name)
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
            }
            .navigationTitle("Edit Shoe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        shoe.name = trimmed
                        shoe.startDate = startDate
                        try? modelContext.save()
                        onSave()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
