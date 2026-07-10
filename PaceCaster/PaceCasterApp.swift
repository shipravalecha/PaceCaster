import SwiftUI
import SwiftData

@main
struct PaceCasterApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var healthKitManager = HealthKitManager.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([RunWorkout.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(healthKitManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
