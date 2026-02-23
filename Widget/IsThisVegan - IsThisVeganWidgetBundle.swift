// IsThisVeganWidgetBundle.swift
// IsThisVeganWidget
//
// The widget bundle that registers all widgets for the app.
// This is the entry point for the widget extension target.

import WidgetKit
import SwiftUI

@main
struct IsThisVeganWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Quick scan widget - opens the app's camera directly
        IsThisVeganQuickScanWidget()
        
        // Last scan widget - shows the most recent scan result
        IsThisVeganLastScanWidget()
    }
}
