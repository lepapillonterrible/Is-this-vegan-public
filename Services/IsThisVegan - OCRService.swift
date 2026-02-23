// OCRService.swift
// IsThisVegan
//
// On-device OCR using Apple Vision framework.
// Extracts text from images with multi-language support (English, Thai, etc.).
// Runs entirely on-device — no network needed, no cost, fully private.

import UIKit
import Vision

/// Result of an OCR scan, including the raw text and whether it looks like an ingredient list.
struct OCRResult {
    /// All recognized text joined together.
    let fullText: String

    /// Individual text observations with confidence scores.
    let observations: [(text: String, confidence: Float)]

    /// Whether the extracted text appears to contain an ingredient list.
    let containsIngredientList: Bool

    /// True if no meaningful text was found.
    var isEmpty: Bool { fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

/// Thread-safety: No stored mutable state; all methods create local request objects.
final class OCRService: @unchecked Sendable {

    // MARK: - Public API

    /// Recognize text in the given image using Apple Vision.
    /// Supports English, Thai, and other languages available on-device.
    /// - Parameter image: The UIImage to scan.
    /// - Returns: An OCRResult with extracted text and metadata.
    func recognizeText(in image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.visionError(error))
                    return
                }

                guard let results = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: OCRResult(
                        fullText: "",
                        observations: [],
                        containsIngredientList: false
                    ))
                    return
                }

                // Extract top candidate from each observation
                let observations: [(text: String, confidence: Float)] = results.compactMap { obs in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    return (text: candidate.string, confidence: candidate.confidence)
                }

                let fullText = observations.map { $0.text }.joined(separator: "\n")
                let containsIngredients = Self.detectIngredientList(in: fullText)

                continuation.resume(returning: OCRResult(
                    fullText: fullText,
                    observations: observations,
                    containsIngredientList: containsIngredients
                ))
            }

            // Configure for accuracy and multi-language support
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            // Support English and Thai; Vision will auto-detect others
            request.recognitionLanguages = ["en-US", "th-TH"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.visionError(error))
            }
        }
    }

    // MARK: - Ingredient List Detection

    /// Heuristic check: does this text look like it contains an ingredient list?
    /// Looks for common patterns like "Ingredients:", comma-separated items, etc.
    private static func detectIngredientList(in text: String) -> Bool {
        let lowered = text.lowercased()

        // Check for explicit ingredient headers (English + Thai)
        let ingredientHeaders = [
            "ingredients:", "ingredients :", "ingredient:",
            "contains:", "contains :",
            "ส่วนประกอบ", "วัตถุดิบ", "ส่วนผสม"
        ]

        for header in ingredientHeaders {
            if lowered.contains(header) {
                return true
            }
        }

        // Heuristic: if there are many commas, it's likely a list
        // (ingredient lists are typically comma-separated)
        let commaCount = text.filter { $0 == "," }.count
        let wordCount = text.split(separator: " ").count
        if commaCount >= 3 && wordCount >= 5 {
            return true
        }

        return false
    }
}

// MARK: - Errors

enum OCRError: LocalizedError {
    case invalidImage
    case visionError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image. Please try another photo."
        case .visionError(let error):
            return "Text recognition failed: \(error.localizedDescription)"
        }
    }
}
