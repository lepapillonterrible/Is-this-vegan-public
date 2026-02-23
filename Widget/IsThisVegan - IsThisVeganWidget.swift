// IsThisVeganWidget.swift
// IsThisVeganWidget
//
// Defines two widgets:
// 1. QuickScanWidget - A tap-to-scan widget that opens the app's camera
// 2. LastScanWidget - Shows the most recent scan result from history
//
// Both widgets use the shared App Group container to access SwiftData.

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Shared Data Provider

/// Fetches the most recent scan result from the shared SwiftData store
struct VeganWidgetDataProvider {
    
    /// Loads the most recent scan result from the App Group's SwiftData container
    static func fetchLastScan() -> ScanResult? {
        do {
            let config = ModelConfiguration(
                "IsThisVegan",
                groupContainer: .identifier(Config.appGroupIdentifier),
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: ScanResult.self, APIUsageRecord.self,
                configurations: config
            )
            let context = ModelContext(container)
            
            var descriptor = FetchDescriptor<ScanResult>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            descriptor.fetchLimit = 1
            
            let results = try context.fetch(descriptor)
            return results.first
        } catch {
            print("Widget: Failed to fetch last scan: \(error)")
            return nil
        }
    }
}

// MARK: - ═══════════════════════════════════════════
// MARK:   1. QUICK SCAN WIDGET
// MARK: - ═══════════════════════════════════════════

/// A simple widget that acts as a shortcut to open the app and start scanning.
/// Tapping it deep-links into the app's scan screen.
struct IsThisVeganQuickScanWidget: Widget {
    let kind: String = "IsThisVeganQuickScan"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickScanProvider()) { entry in
            QuickScanWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Scan")
        .description("Tap to quickly scan a product or menu item.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Timeline provider for the quick scan widget (static - doesn't change)
struct QuickScanProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickScanEntry {
        QuickScanEntry(date: Date())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (QuickScanEntry) -> Void) {
        completion(QuickScanEntry(date: Date()))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickScanEntry>) -> Void) {
        // This widget is static - just refresh once a day
        let entry = QuickScanEntry(date: Date())
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 24, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

/// Entry for the quick scan widget
struct QuickScanEntry: TimelineEntry {
    let date: Date
}

// MARK: - ═══════════════════════════════════════════
// MARK:   2. LAST SCAN WIDGET
// MARK: - ═══════════════════════════════════════════

/// A widget that displays the most recent scan result.
/// Updates whenever a new scan is performed (via WidgetCenter.shared.reloadAllTimelines()).
struct IsThisVeganLastScanWidget: Widget {
    let kind: String = "IsThisVeganLastScan"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LastScanProvider()) { entry in
            LastScanWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Last Scan")
        .description("Shows your most recent vegan check result.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Timeline provider for the last scan widget
struct LastScanProvider: TimelineProvider {
    func placeholder(in context: Context) -> LastScanEntry {
        LastScanEntry(
            date: Date(),
            productName: "Oat Milk",
            verdict: .vegan,
            explanation: "All ingredients are plant-based.",
            flaggedIngredients: [],
            scanDate: Date()
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (LastScanEntry) -> Void) {
        let entry = makeEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<LastScanEntry>) -> Void) {
        let entry = makeEntry()
        // Refresh every 15 minutes (also refreshed manually when a new scan is saved)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func makeEntry() -> LastScanEntry {
        if let lastScan = VeganWidgetDataProvider.fetchLastScan() {
            return LastScanEntry(
                date: Date(),
                productName: lastScan.productName,
                verdict: lastScan.verdict,
                explanation: lastScan.explanation,
                flaggedIngredients: lastScan.flaggedIngredients,
                scanDate: lastScan.timestamp
            )
        } else {
            // No scans yet - show placeholder
            return LastScanEntry(
                date: Date(),
                productName: nil,
                verdict: nil,
                explanation: nil,
                flaggedIngredients: [],
                scanDate: nil
            )
        }
    }
}

/// Entry for the last scan widget
struct LastScanEntry: TimelineEntry {
    let date: Date
    let productName: String?
    let verdict: VeganVerdict?
    let explanation: String?
    let flaggedIngredients: [String]
    let scanDate: Date?
    
    /// Whether there's actual scan data to display
    var hasData: Bool { productName != nil }
}
