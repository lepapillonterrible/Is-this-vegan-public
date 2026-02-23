// AnalysisPipeline.swift
// IsThisVegan
//
// The main orchestrator that ties together every analysis step:
//
//   ┌──────────┐     ┌──────────────────┐     ┌────────────┐
//   │  Image   │ ──▶ │  OCR (on-device) │ ──▶ │ Local DB   │
//   └──────────┘     └──────────────────┘     │  scan      │
//                                              └─────┬──────┘
//                                                    │
//                              ┌──────────────────────┤
//                              ▼                      ▼
//                     Definite non-vegan?      Uncertain / possibly vegan?
//                     ┌──────────────┐        ┌───────────────┐
//                     │ Return early │        │ Gemini Vision │
//                     │ (offline)    │        │ API call      │
//                     └──────────────┘        └───────┬───────┘
//                                                     │
//                                                     ▼
//                                              ┌──────────────┐
//                                              │ ScanResult   │
//                                              │ + track usage│
//                                              └──────────────┘
//
// This design minimises API calls (and cost) by resolving obvious cases
// locally, and only calling Gemini when the local database can't give
// a confident answer.

import UIKit
import Foundation

// MARK: - Pipeline Configuration

/// Controls how the pipeline behaves — useful for testing and user preferences.
struct PipelineOptions {
    /// If true, always call the LLM even when the local DB gives a definitive answer.
    /// Useful for getting richer explanations and product names.
    var alwaysUseLLM: Bool = false

    /// If true, skip the LLM entirely and only use local DB + OCR.
    /// Useful for offline mode or when the user has hit their API limit.
    var offlineOnly: Bool = false

    /// The type of content being analyzed (affects the LLM prompt).
    var inputType: LLMService.InputType = .unknown

    /// Default options for normal usage.
    static let `default` = PipelineOptions()

    /// Options for offline-only analysis.
    static let offline = PipelineOptions(offlineOnly: true)
}

// MARK: - Pipeline Errors

enum PipelineError: LocalizedError {
    case noTextDetected
    case rateLimitReached(String)
    case analysisFailedWithFallback(localResult: ScanResult, llmError: Error)

    var errorDescription: String? {
        switch self {
        case .noTextDetected:
            return "No text could be detected in the image. Try a clearer photo of the ingredient list."
        case .rateLimitReached(let message):
            return message
        case .analysisFailedWithFallback(_, let error):
            return "AI analysis failed (\(error.localizedDescription)), showing local results instead."
        }
    }
}

// MARK: - Analysis Pipeline


/// Thread-safety: All stored properties are `let` and the services themselves are
/// effectively immutable post-init (IngredientDatabase loads its dictionaries in init;
/// OCRService and LLMService are stateless). Safe to share across isolation domains.
final class AnalysisPipeline: @unchecked Sendable {

    // MARK: - Dependencies

    private let ocrService = OCRService()
    private let ingredientDB = IngredientDatabase()
    private let llmService = LLMService()
    let locationService = LocationService()
    private let heuristicService = HeuristicService()
    private let brandService = VeganBrandService()

    // MARK: - Public API

    /// Analyze an image end-to-end and return a ScanResult.
    ///
    /// Steps:
    /// 1. Run OCR on the image (on-device, free)
    /// 2. Scan OCR text against local ingredient database (on-device, free)
    /// 3. If local DB is confident → return result without API call
    /// 4. If uncertain → call Gemini Vision API for full analysis
    /// 5. Track API usage
    ///
    /// - Parameters:
    ///   - image: The photo to analyze (ingredient label, menu, product, etc.)
    ///   - options: Pipeline configuration options.
    /// - Returns: A fully populated ScanResult ready for display and persistence.
    func analyze(image: UIImage, options: PipelineOptions = .default) async throws -> ScanResult {

        // ── Step 0: Guard against oversized images ───────────────────
        let safeImage = Self.ensureSafeImageSize(image)

        // Compress image data for storage (do this early so we have it for any path)
        let imageData = safeImage.jpegData(compressionQuality: Config.storedImageCompressionQuality)

        // ── Step 1: OCR ──────────────────────────────────────────────
        let ocrText = await runOCR(on: safeImage)

        // ── Step 2: Local Database Scan ──────────────────────────────
        let localResult: LocalScanResult? = {
            guard let text = ocrText, !text.isEmpty else { return nil }
            return ingredientDB.scanText(text)
        }()

        // ── Step 2b: Brand Lookup ─────────────────────────────────────
        // Check if any known vegan (or mostly-vegan) brand appears in the OCR text.
        // This is a signal only — never a verdict.
        let brandMatch: BrandMatch? = {
            guard let text = ocrText, !text.isEmpty else { return nil }
            return brandService.lookup(in: text)
        }()

        // Determine the input type from OCR if not specified
        let inputType: LLMService.InputType = {
            if options.inputType != .unknown { return options.inputType }
            // If OCR found ingredient-list-like text, it's probably a label
            if let text = ocrText, text.lowercased().contains("ingredients") {
                return .ingredientLabel
            }
            // If OCR found menu-like text (prices, dish names)
            if let text = ocrText, text.contains("$") || text.contains("฿") || text.lowercased().contains("menu") {
                return .menu
            }
            // If very little text, it's probably a product or food photo
            if ocrText == nil || (ocrText?.count ?? 0) < 20 {
                return .productPhoto
            }
            return .unknown
        }()

        // ── Step 3: Decide if we can skip the LLM ───────────────────

        // Case A: Offline-only mode — always return local result
        if options.offlineOnly {
            return buildLocalOnlyResult(
                localScan: localResult,
                ocrText: ocrText,
                imageData: imageData
            )
        }

        // Case B: Local DB found definitive non-vegan ingredients AND we don't need LLM
        if !options.alwaysUseLLM,
           let local = localResult,
           local.localVerdict == .notVegan {
            // Record as offline-resolved (no API cost)
            await UsageTracker.shared.recordUsage(
                model: "local_db",
                promptTokens: 0,
                completionTokens: 0,
                estimatedCostUSD: 0,
                wasOfflineResolved: true,
                inputType: inputType.rawValue
            )
            return buildLocalNotVeganResult(
                localScan: local,
                ocrText: ocrText,
                imageData: imageData
            )
        }

        // ── Step 4: Check rate limits before calling LLM ─────────────
        if let limitMessage = await UsageTracker.shared.checkLimits() {
            // If we have a local result, return it with a note about the limit
            if let local = localResult {
                return buildLocalOnlyResult(
                    localScan: local,
                    ocrText: ocrText,
                    imageData: imageData,
                    note: limitMessage
                )
            }
            throw PipelineError.rateLimitReached(limitMessage)
        }

        // ── Step 5: Call Gemini Vision API ───────────────────────────
        do {
            // Get location context (if available and authorized)
            let locationContext = locationService.currentCountryName
            
            let llmResult = try await llmService.analyze(
                image: image,
                ocrText: ocrText,
                inputType: inputType,
                location: locationContext,
                brandContext: brandMatch?.promptContext
            )

            // Track usage
            let estimatedCost = estimateCost(
                promptTokens: llmResult.promptTokens,
                completionTokens: llmResult.completionTokens
            )
            await UsageTracker.shared.recordUsage(
                model: llmResult.model,
                promptTokens: llmResult.promptTokens,
                completionTokens: llmResult.completionTokens,
                estimatedCostUSD: estimatedCost,
                wasOfflineResolved: false,
                inputType: inputType.rawValue
            )

            // Build the final ScanResult from LLM response
            return buildLLMResult(
                analysis: llmResult.analysis,
                localScan: localResult,
                brandMatch: brandMatch,
                ocrText: ocrText,
                imageData: imageData
            )

        } catch {
            // LLM failed — fall back to local result if available
            let errorNote = "AI analysis unavailable: \(error.localizedDescription)"
            if let local = localResult {
                let fallbackResult = buildLocalOnlyResult(
                    localScan: local,
                    ocrText: ocrText,
                    imageData: imageData,
                    note: errorNote
                )
                // Don't throw — return the fallback
                print("[AnalysisPipeline] LLM failed, using local fallback: \(error)")
                return fallbackResult
            }

            // No local result either — propagate the error
            throw error
        }
    }

    /// Build a ScanResult from the LLM analysis, enriched with local DB findings.
    private func buildLLMResult(
        analysis: GeminiVeganAnalysis,
        localScan: LocalScanResult?,
        brandMatch: BrandMatch?,
        ocrText: String?,
        imageData: Data?
    ) -> ScanResult {
        var verdict = VeganVerdict(rawValue: analysis.verdict) ?? .uncertain

        // Start with LLM findings
        var finalNonVegan = analysis.nonVeganIngredients
        var finalAmbiguous = analysis.ambiguousIngredients
        var explanation = analysis.summary

        // ── Heuristic Check (Regional Rules) ─────────────────────────
        if let countryCode = locationService.currentCountryCode,
           let rule = heuristicService.checkDish(name: analysis.productName, regionCode: countryCode) {
            
            // Append regional warning
            explanation += "\n\n📍 Regional Context (\(locationService.currentCountryName ?? countryCode)): "
            explanation += rule.reason
            
            // Adjust verdict based on heuristic risk
            switch rule.status {
            case .notVegan:
                verdict = .notVegan
                if !finalNonVegan.contains("Traditional Preparation") {
                    finalNonVegan.append("Traditional Preparation (usually contains animal products)")
                }
            case .risky:
                if verdict == .vegan { verdict = .uncertain } // Downgrade strict vegan to uncertain
                if !finalAmbiguous.contains("Traditional Preparation") {
                    finalAmbiguous.append("Traditional Preparation (often risky in this region)")
                }
            case .likelyVegan, .vegan:
                // If AI was uncertain but local rule says it's usually vegan, we could upgrade...
                // But let's be conservative and just keep the note.
                break
            }
        }

        // Merge local DB findings (deduplicating by name)
        if let local = localScan {
            // If local DB found definitive non-vegan ingredients the LLM missed, override verdict
            if !local.definitelyNonVegan.isEmpty && verdict != .notVegan {
                verdict = .notVegan
            }

            // Add definite non-vegan items from local DB
            for item in local.definitelyNonVegan {
                let name = item.matchedTerm
                // Check if already present (case-insensitive)
                if !finalNonVegan.contains(where: { $0.localizedCaseInsensitiveContains(name) }) {
                    finalNonVegan.append("\(name) (detected locally)")
                }
            }


            // Add ambiguous items from local DB
            for item in local.ambiguous {
                let name = item.matchedTerm
                if !finalAmbiguous.contains(where: { $0.localizedCaseInsensitiveContains(name) }) {
                    finalAmbiguous.append(name)
                }
            }
        }

        // Combine into final list for display
        var flagged = finalNonVegan
        if !finalAmbiguous.isEmpty {
            flagged += finalAmbiguous.map { "\($0) (uncertain)" }
        }

        // Build a rich explanation (append suggestions/confidence)
        if !analysis.suggestions.isEmpty {
            explanation += "\n\n💡 Tips: " + analysis.suggestions.joined(separator: ". ")
        }
        if analysis.confidence < 0.7 {
            explanation += "\n\n⚠️ Confidence is low (\(Int(analysis.confidence * 100))%). Consider checking the ingredient list directly."
        }

        // Append brand context note at the end of the explanation
        // Only show for vegan / uncertain verdicts — showing it on not_vegan would be misleading.
        // (e.g. "THIS is a fully vegan brand" makes no sense under a Not Vegan verdict)
        if let brand = brandMatch, verdict != .notVegan {
            explanation += "\n\n" + brand.explanationNote
        }

        return ScanResult(
            verdict: verdict,
            productName: analysis.productName,
            explanation: explanation,
            flaggedIngredients: flagged,
            ocrText: ocrText,
            imageData: imageData
        )
    }

    /// Build a ScanResult when the local DB found definitive non-vegan ingredients.
    private func buildLocalNotVeganResult(
        localScan: LocalScanResult,
        ocrText: String?,
        imageData: Data?
    ) -> ScanResult {
        let flaggedNames = localScan.definitelyNonVegan.map { lookup in
            "\(lookup.matchedTerm) (\(lookup.category))"
        }
        let ambiguousNames = localScan.ambiguous.map { lookup in
            "\(lookup.matchedTerm) (uncertain)"
        }

        let explanation = buildLocalExplanation(
            definite: localScan.definitelyNonVegan,
            ambiguous: localScan.ambiguous,
            note: nil
        )

        return ScanResult(
            verdict: .notVegan,
            productName: "Unknown Product",
            explanation: explanation,
            flaggedIngredients: flaggedNames + ambiguousNames,
            ocrText: ocrText,
            imageData: imageData
        )
    }

    /// Build a ScanResult from local-only analysis (offline mode or LLM failure).
    private func buildLocalOnlyResult(
        localScan: LocalScanResult?,
        ocrText: String?,
        imageData: Data?,
        note: String? = nil
    ) -> ScanResult {
        guard let scan = localScan else {
            // No OCR text and no local scan — we can't determine anything
            return ScanResult(
                verdict: .uncertain,
                productName: "Unknown",
                explanation: note ?? "Could not extract text from the image. Try a clearer photo of the ingredient list.",
                flaggedIngredients: [],
                ocrText: ocrText,
                imageData: imageData
            )
        }

        let verdict: VeganVerdict = {
            switch scan.localVerdict {
            case .notVegan: return .notVegan
            case .uncertain: return .uncertain
            case .possiblyVegan: return .uncertain  // Local DB can't confirm vegan
            }
        }()

        let flaggedNames = scan.definitelyNonVegan.map { "\($0.matchedTerm) (\($0.category))" }
        let ambiguousNames = scan.ambiguous.map { "\($0.matchedTerm) (uncertain)" }

        let explanation = buildLocalExplanation(
            definite: scan.definitelyNonVegan,
            ambiguous: scan.ambiguous,
            note: note
        )

        return ScanResult(
            verdict: verdict,
            productName: "Unknown Product",
            explanation: explanation,
            flaggedIngredients: flaggedNames + ambiguousNames,
            ocrText: ocrText,
            imageData: imageData
        )
    }

    // MARK: - Helpers

    /// Run OCR on the image. Returns nil if no text found or if OCR fails.
    private func runOCR(on image: UIImage) async -> String? {
        do {
            let result = try await ocrService.recognizeText(in: image)
            return result.isEmpty ? nil : result.fullText
        } catch {
            print("[AnalysisPipeline] OCR failed: \(error)")
            return nil
        }
    }

    /// Build a human-readable explanation from local DB results.
    private func buildLocalExplanation(
        definite: [IngredientLookup],
        ambiguous: [IngredientLookup],
        note: String?
    ) -> String {
        var parts: [String] = []

        if !definite.isEmpty {
            let names = definite.map { $0.matchedTerm }.joined(separator: ", ")
            parts.append("Found non-vegan ingredients: \(names).")
        }

        if !ambiguous.isEmpty {
            let names = ambiguous.map { $0.matchedTerm }.joined(separator: ", ")
            parts.append("Potentially non-vegan: \(names).")
            // Add notes for ambiguous items
            for item in ambiguous {
                if let itemNote = item.note {
                    parts.append("• \(item.matchedTerm): \(itemNote)")
                }
            }
        }

        if definite.isEmpty && ambiguous.isEmpty {
            parts.append("No known non-vegan ingredients detected locally, but this is based on limited offline analysis.")
        }

        parts.append("\n📱 Analyzed using on-device database (no API call used).")

        if let note = note {
            parts.append("\nℹ️ \(note)")
        }

        return parts.joined(separator: "\n")
    }

    /// Estimate the cost of a Gemini API call based on token counts.
    /// Pricing: Gemini 2.5 Flash ~ $0.075/M input tokens, $0.30/M output tokens.
    private func estimateCost(promptTokens: Int, completionTokens: Int) -> Double {
        let inputCost = Double(promptTokens) * 0.000000075   // $0.075 per 1M tokens
        let outputCost = Double(completionTokens) * 0.0000003  // $0.30 per 1M tokens
        return inputCost + outputCost
    }

    // MARK: - Image Safety

    /// Maximum pixel count before we force-downscale to prevent OOM.
    /// 16 megapixels (~4096×4096) is safe on all modern iPhones.
    private static let maxSafePixels: CGFloat = 4096 * 4096

    /// Downscale an image if its total pixel count exceeds the safe limit.
    /// This runs before any processing to prevent memory pressure from
    /// extremely large images (some phones shoot 48MP+ photos).
    private static func ensureSafeImageSize(_ image: UIImage) -> UIImage {
        let scale = image.scale
        let pixelWidth = image.size.width * scale
        let pixelHeight = image.size.height * scale
        let totalPixels = pixelWidth * pixelHeight

        guard totalPixels > maxSafePixels else { return image }

        let ratio = sqrt(maxSafePixels / totalPixels)
        let newSize = CGSize(
            width: floor(image.size.width * ratio),
            height: floor(image.size.height * ratio)
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - Location Support

    /// Request location permission to enable regional analysis.
    func requestLocationPermission() {
        locationService.requestPermission()
    }
}
