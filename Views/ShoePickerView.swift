import SwiftUI
import SwiftData

struct ShoePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let run: RunWorkout
    var onSave: () -> Void

    @State private var allShoes: [Shoe] = []

    var body: some View {
        NavigationStack {
            List {
                Button {
                    run.shoeID = nil
                    save()
                } label: {
                    HStack {
                        Text("No shoe assigned")
                        Spacer()
                        if run.shoeID == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .foregroundStyle(.primary)

                ForEach(allShoes) { shoe in
                    Button {
                        run.shoeID = shoe.id
                        save()
                    } label: {
                        HStack {
                            Text(shoe.name)
                            Spacer()
                            if run.shoeID == shoe.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Assign Shoe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: loadShoes)
        }
    }

    private func loadShoes() {
        let descriptor = FetchDescriptor<Shoe>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        allShoes = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func save() {
        try? modelContext.save()
        onSave()
        dismiss()
    }
}
