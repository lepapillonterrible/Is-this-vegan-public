// ContentView.swift
// IsThisVegan
//
// The root view of the app. Uses a TabView with three tabs:
// 1. Scan    – Take/select a photo to analyze (main flow)
// 2. History – View past scan results
// 3. Settings
//
// Creates and owns the ScannerViewModel as a @StateObject,
// then injects it into the view hierarchy via .environmentObject()
// so all child views share the same instance.

import SwiftUI
import SwiftData

struct ContentView: View {

    // MARK: - State

    /// Currently selected tab
    @State private var selectedTab = 0

    /// The shared scanner view model — created here, shared via environment.
    @StateObject private var scannerViewModel = ScannerViewModel()

    /// Whether the user has already accepted the privacy consent.
    @AppStorage("hasAcceptedConsent") private var hasAcceptedConsent = false

    /// Action requested by a widget intent: "camera" | "library" | nil
    @State private var pendingWidgetAction: String? = nil

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {

            // MARK: - Scan Tab (main)
            ScanView(pendingWidgetAction: $pendingWidgetAction)
                .tabItem {
                    Label("Scan", systemImage: "viewfinder")
                }
                .tag(0)

            // MARK: - History Tab
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(1)

            // MARK: - Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
        .tint(.green)
        .environmentObject(scannerViewModel)
        // Show consent screen on first launch only
        .fullScreenCover(isPresented: Binding(
            get: { !hasAcceptedConsent },
            set: { _ in }
        )) {
            ConsentView {
                hasAcceptedConsent = true
            }
        }
        // Handle deep links from widget intents
        .onOpenURL { url in
            handleWidgetURL(url)
        }
        // Also check UserDefaults on foreground (belt-and-suspenders for iOS 17 intents)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            drainPendingWidgetAction()
        }
    }

    // MARK: - URL Handling

    private func handleWidgetURL(_ url: URL) {
        guard url.scheme == "isthisvegan", url.host == "scan" else { return }
        let source = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "source" })?.value
        applyWidgetAction(source ?? "scan")
    }

    private func drainPendingWidgetAction() {
        let defaults = UserDefaults(suiteName: "group.papillonmakes.isthisvegan")
        if let action = defaults?.string(forKey: "pendingWidgetAction") {
            defaults?.removeObject(forKey: "pendingWidgetAction")
            applyWidgetAction(action)
        }
    }

    private func applyWidgetAction(_ action: String) {
        selectedTab = 0 // always switch to Scan tab
        pendingWidgetAction = action
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: [ScanResult.self], inMemory: true)
}
