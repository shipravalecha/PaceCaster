import SwiftUI
import SwiftData

struct ShoeMileageView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: AppSettings

    @State private var shoes: [Shoe] = []
    @State private var allRuns: [RunWorkout] = []
    @State private var showAddShoe = false
    @State private var editingShoe: Shoe?

    var body: some View {
        List {
            ForEach(shoes) { shoe in
                shoeRow(shoe)
            }
            .onDelete(perform: deleteShoes)

            Button("Add Shoe") {
                showAddShoe = true
            }
        }
        .navigationTitle("Shoes")
        .toolbar {
            EditButton()
        }
        .safeAreaInset(edge: .bottom) {
            Text("Most runners replace shoes every 300–500 miles as cushioning wears down, which can increase injury risk.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.thinMaterial)
        }
        .sheet(isPresented: $showAddShoe) {
            AddShoeView { name in
                let shoe = Shoe(name: name)
                modelContext.insert(shoe)
                try? modelContext.save()
                loadData()
            }
        }
        .sheet(item: $editingShoe) { shoe in
            EditShoeView(shoe: shoe) {
                loadData()
            }
        }
        .onAppear(perform: loadData)
    }

    private func shoeRow(_ shoe: Shoe) -> some View {
        let mileage = ShoeMileageCalculator.mileage(for: shoe, allRuns: allRuns)
        let isCurrent = settings.currentShoeID == shoe.id

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(shoe.name).font(.subheadline.weight(.semibold))
                    Text("\(mileage.runCount) run\(mileage.runCount == 1 ? "" : "s") since \(shoe.startDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isCurrent {
                    Text("Current")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.15), in: Capsule())
                        .foregroundStyle(.blue)
                }
                Button {
                    editingShoe = shoe
                } label: {
                    Image(systemName: "pencil.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Text(String(format: "%.0f mi", mileage.miles))
                    .font(.headline)
                Spacer()
                if mileage.isPastReplacement {
                    Label("Time for new shoes", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if mileage.isNearingReplacement {
                    Label("Getting worn", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            ProgressView(value: min(mileage.miles, 500), total: 500)
                .tint(mileage.isPastReplacement ? .red : (mileage.isNearingReplacement ? .orange : .blue))

            if !isCurrent {
                Button("Set as Current Shoe") {
                    settings.currentShoeID = shoe.id
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(shoeAccessibilityLabel(shoe: shoe, mileage: mileage, isCurrent: isCurrent))
    }

    private func shoeAccessibilityLabel(shoe: Shoe, mileage: ShoeMileage, isCurrent: Bool) -> String {
        var label = "\(shoe.name), \(String(format: "%.0f", mileage.miles)) miles"
        if isCurrent { label += ", current shoe" }
        if mileage.isPastReplacement { label += ", time for new shoes" }
        else if mileage.isNearingReplacement { label += ", getting worn" }
        return label
    }

    private func loadData() {
        let shoeDescriptor = FetchDescriptor<Shoe>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        shoes = (try? modelContext.fetch(shoeDescriptor)) ?? []
        let runDescriptor = FetchDescriptor<RunWorkout>()
        allRuns = (try? modelContext.fetch(runDescriptor)) ?? []
    }

    private func deleteShoes(at offsets: IndexSet) {
        for index in offsets {
            let shoe = shoes[index]
            if settings.currentShoeID == shoe.id {
                settings.currentShoeID = nil
            }
            modelContext.delete(shoe)
        }
        try? modelContext.save()
        loadData()
    }
}
