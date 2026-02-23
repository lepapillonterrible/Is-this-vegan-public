// WidgetIntents.swift
// IsThisVegan
//
// App Intents powering the interactive buttons in the QuickScan widget (iOS 17+).
// Compiled into BOTH the widget extension AND the main app target.
//
// Strategy: openAppWhenRun = true brings the app to foreground.
// The chosen action is written to the shared App Group UserDefaults so that
// ContentView's willEnterForeground handler can read it and trigger the
// correct picker (camera or photo library) immediately on launch.

import AppIntents
import Foundation

private let appGroupID = "group.papillonmakes.isthisvegan"
private let pendingKey  = "pendingWidgetAction"

// MARK: - Scan with Camera

struct ScanWithCameraIntent: AppIntent {

    static let title: LocalizedStringResource = "Scan with Camera"
    static let description = IntentDescription(
        "Opens Is This Vegan? and starts the camera to scan a product."
    )

    /// Bringing the app to foreground is sufficient on iOS 17.
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: appGroupID)?.set("camera", forKey: pendingKey)
        return .result()
    }
}

// MARK: - Scan from Library

struct ScanFromLibraryIntent: AppIntent {

    static let title: LocalizedStringResource = "Choose from Library"
    static let description = IntentDescription(
        "Opens Is This Vegan? and shows the photo library picker."
    )

    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: appGroupID)?.set("library", forKey: pendingKey)
        return .result()
    }
}
