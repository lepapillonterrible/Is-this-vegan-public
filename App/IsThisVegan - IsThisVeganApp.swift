// IsThisVeganApp.swift
// IsThisVegan
//
// Main app entry point. Sets up SwiftData model container
// and the root view hierarchy.
//
// Updated to:
// - Register APIUsageRecord model alongside ScanResult
// - Configure UsageTracker with the model context on launch

import SwiftUI
import SwiftData

@main
struct IsThisVeganApp: App {

    /// SwiftData model container for persisting scan results and API usage records
    let modelContainer: ModelContainer

    init() {
        do {
            // Configure SwiftData with our models
            // Using App Group container so the widget can also access the data
            let config = ModelConfiguration(
                "IsThisVegan",
                groupContainer: .identifier(Config.appGroupIdentifier),
                cloudKitDatabase: .none
            )

            // Register both ScanResult and APIUsageRecord models
            modelContainer = try ModelContainer(
                for: ScanResult.self, APIUsageRecord.self,
                configurations: config
            )

            // Configure the UsageTracker with the main context
            // so it can read/write usage records immediately
            let context = modelContainer.mainContext
            UsageTracker.shared.modelContext = context

            print("[IsThisVeganApp] SwiftData container initialized with ScanResult + APIUsageRecord")

        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
