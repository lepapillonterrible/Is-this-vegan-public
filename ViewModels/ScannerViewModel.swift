// ScannerViewModel.swift
// IsThisVegan
//
// ViewModel for the scanner screen. Bridges the UI to the
// AnalysisPipeline, managing loading states, errors, and results.
//
// Owns all scan-related state so the views stay thin and declarative.
// The view just binds to published properties and calls public methods.
//
// Changes from the old version:
// - Replaced VisionService + ClassificationService with AnalysisPipeline
// - Now uses async/await instead of callbacks
// - Supports pipeline options (offline mode, input type hints)
// - Exposes usage stats for the UI
// - Persists results to SwiftData via modelContext

import SwiftUI
import SwiftData

@MainActor
class ScannerViewModel: ObservableObject {

    // MARK: - Published State

    /// The most recent scan result (displayed in the UI).
    @Published var latestResult: ScanResult?

    /// True while the pipeline is analyzing an image.
    @Published var isProcessing = false

    /// User-facing error message, if any.
    @Published var errorMessage: String?
    
    /// Warning message for non-critical issues (e.g., save failed but scan succeeded).
    @Published var warningMessage: String?

    /// The image currently being analyzed (shown in the UI).
    @Published var selectedImage: UIImage?

    /// Current usage statistics (updated after each scan).
    @Published var usageStats: UsageStats = .empty

    /// Whether to use offline-only mode (no API calls).
    @Published var offlineMode = false

    // MARK: - Input Type



    // MARK: - Dependencies

    /// The analysis pipeline (OCR → local DB → Gemini).
    private let pipeline = AnalysisPipeline()

    /// SwiftData model context for persisting scan results.
    /// Set by ContentView when it appears (injected from environment).
    var modelContext: ModelContext?

    /// Handle to the in-flight analysis task, used for cancellation
    /// when a new scan is started before the previous one completes.
    private var currentTask: Task<Void, Never>?

    /// Service for community contributions.
    let crowdSourceService = CrowdSourceService()

    // MARK: - Public API

    /// Submit a community correction or confirmation.
    func submitCommunityReport(for result: ScanResult, verdict: String, reason: String) {
        // We need a location to submit.
        // We can access it via the pipeline's location service if we expose it,
        // or just rely on the fact that we requested permission.
        // For now, let's assume we can get it from the pipeline if we expose it,
        // or cleaner: let's instantiate LocationService in ViewModel instead of Pipeline?
        // Ah, Pipeline owns it. Let's rely on a shared instance or expose it from Pipeline.
        
        // Quick fix: Expose LocationService from Pipeline
        guard let location = pipeline.locationService.lastKnownLocation else {
            print("[ScannerViewModel] Cannot submit report: Location unknown")
            return
        }
        
        Task {
            do {
                try await crowdSourceService.submitReport(
                    dishName: result.productName,
                    verdict: verdict,
                    reason: reason,
                    location: location
                )
                print("[ScannerViewModel] Community report submitted!")
            } catch {
                print("[ScannerViewModel] Failed to submit report: \(error)")
            }
        }
    }

    /// Analyze an image through the full pipeline.

    /// Analyze an image through the full pipeline.
    ///
    /// This is the main entry point called by the UI when the user
    /// takes a photo, picks from gallery, or shares a screenshot.
    ///
    /// If a previous analysis is still running, it will be cancelled
    /// before the new one starts. After the async work completes we
    /// check `Task.isCancelled` to avoid overwriting results with
    /// stale data from a superseded scan.
    ///
    /// - Parameter image: The image to analyze.
    func processImage(_ image: UIImage) {
        // Cancel any in-flight analysis
        currentTask?.cancel()

        // Update the selected image for display
        selectedImage = image

        // Reset state
        isProcessing = true
        errorMessage = nil
        latestResult = nil

        // Build pipeline options
        var options = PipelineOptions.default
        // Default to ingredient label, but pipeline will auto-switch to visual if text is sparse
        options.inputType = .ingredientLabel
        options.offlineOnly = offlineMode

        // Run the async pipeline
        currentTask = Task {
            do {
                let result = try await pipeline.analyze(image: image, options: options)

                // Bail out if a newer scan superseded this one
                guard !Task.isCancelled else { return }

                // Store the original image data on the result for history
                if result.imageData == nil {
                    result.imageData = image.jpegData(compressionQuality: Config.storedImageCompressionQuality)
                }

                // Update UI
                self.latestResult = result
                self.errorMessage = nil

                // Persist to SwiftData
                persistResult(result)

                // Refresh usage stats
                self.usageStats = UsageTracker.shared.getStats()

            } catch is CancellationError {
                // Expected when a newer scan cancels this one — no error to show
            } catch {
                guard !Task.isCancelled else { return }
                
                // Analyze the error for better user messaging
                let context = ErrorAnalyzer.analyze(error)
                self.errorMessage = context.userMessage
                if let suggestion = context.suggestedAction {
                    self.errorMessage? += "\n\n➡️ " + suggestion
                }
                
                // Log technical details for debugging
                print("[ScannerViewModel] Analysis failed [\(context.category)]: \(context.technicalDetails)")
            }

            if !Task.isCancelled {
                self.isProcessing = false
            }
        }
    }

    /// Reset state so the user can scan again.
    func scanAgain() {
        latestResult = nil
        selectedImage = nil
        errorMessage = nil
    }

    /// Clear just the error state (e.g. after dismissing an alert).
    func clearError() {
        errorMessage = nil
    }
    
    /// Clear warning message.
    func clearWarning() {
        warningMessage = nil
    }

    /// Refresh usage statistics (call on view appear).
    func refreshUsageStats() {
        usageStats = UsageTracker.shared.getStats()
    }

    /// Request location permission for regional analysis.
    func requestLocationPermission() {
        pipeline.requestLocationPermission()
    }

    // MARK: - Persistence

    /// Save a ScanResult to SwiftData for history and widget access.
    /// Shows a warning to the user if persistence fails, but doesn't block the scan result.
    private func persistResult(_ result: ScanResult) {
        guard let context = modelContext else {
            let error = PersistenceError.contextNotAvailable
            self.warningMessage = error.errorDescription
            print("[ScannerViewModel] Error: \(error.errorDescription ?? "Unknown")")
            return
        }

        context.insert(result)

        do {
            try context.save()
            print("[ScannerViewModel] ✓ Saved scan result to SwiftData")
        } catch {
            // Wrap the error with context
            let persistenceError = PersistenceError.saveFailed(underlyingError: error)
            
            // Show user-friendly warning
            self.warningMessage = persistenceError.errorDescription
            if let suggestion = persistenceError.recoverySuggestion {
                self.warningMessage? += "\n\n" + suggestion
            }
            
            // Log technical details
            print("[ScannerViewModel] ⚠️ Persistence failed: \(error)")
            print("[ScannerViewModel] Result is still available but not saved to history")
        }
    }

    // MARK: - Error Mapping

    /// Convert technical errors into user-friendly messages.
    private func friendlyError(from error: Error) -> String {
        let description = error.localizedDescription.lowercased()

        if description.contains("network") || description.contains("internet") {
            return "No internet connection. Try offline mode or check your connection."
        } else if description.contains("rate limit") || description.contains("quota") {
            return "You've reached the daily scan limit. Try again tomorrow or upgrade."
        } else if description.contains("api key") || description.contains("unauthorized") {
            return "API configuration error. Please contact support."
        } else if description.contains("timeout") {
            return "The request timed out. Please try again."
        } else {
            return "Something went wrong: \(error.localizedDescription)"
        }
    }
}
