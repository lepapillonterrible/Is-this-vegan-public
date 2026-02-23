// LLMService.swift
// IsThisVegan
//
// Handles communication with Google Gemini's Vision API.
// Sends images (with optional OCR context) and receives structured
// vegan analysis responses. Tracks token usage for every call.
//
// Gemini API docs: https://ai.google.dev/gemini-api/docs

import UIKit
import Foundation

// MARK: - Response Models

/// The structured response we ask Gemini to return.
/// Uses a custom `init(from:)` to handle missing or malformed fields
/// gracefully instead of crashing on unexpected API responses.
struct GeminiVeganAnalysis: Codable {
    /// "vegan", "not_vegan", or "uncertain"
    let verdict: String

    /// Confidence from 0.0 to 1.0
    let confidence: Double

    /// Human-readable summary of the analysis
    let summary: String

    /// List of non-vegan ingredients found (if any)
    let nonVeganIngredients: [String]

    /// List of potentially non-vegan / ambiguous ingredients
    let ambiguousIngredients: [String]

    /// Actionable suggestions (e.g. "ask for no fish sauce")
    let suggestions: [String]

    /// What the AI thinks the product/dish is
    let productName: String

    // Known valid verdict values
    private static let validVerdicts: Set<String> = ["vegan", "not_vegan", "uncertain"]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Verdict: default to "uncertain" if missing or unrecognized
        let rawVerdict = try container.decodeIfPresent(String.self, forKey: .verdict) ?? "uncertain"
        self.verdict = Self.validVerdicts.contains(rawVerdict) ? rawVerdict : "uncertain"

        // Confidence: default to 0.5, clamp to 0...1
        let rawConfidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0.5
        self.confidence = min(max(rawConfidence, 0.0), 1.0)

        // Strings: default to sensible fallbacks
        self.summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? "Analysis completed but no summary was provided."
        self.productName = try container.decodeIfPresent(String.self, forKey: .productName)
            ?? "Unknown Product"

        // Arrays: default to empty
        self.nonVeganIngredients = try container.decodeIfPresent([String].self, forKey: .nonVeganIngredients) ?? []
        self.ambiguousIngredients = try container.decodeIfPresent([String].self, forKey: .ambiguousIngredients) ?? []
        self.suggestions = try container.decodeIfPresent([String].self, forKey: .suggestions) ?? []
    }
}

/// Raw Gemini API response structure for parsing.
struct GeminiAPIResponse: Codable {
    let candidates: [GeminiCandidate]?
    let usageMetadata: GeminiUsageMetadata?
    let error: GeminiAPIError?
}

struct GeminiCandidate: Codable {
    let content: GeminiContent?
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]?
}

struct GeminiPart: Codable {
    let text: String?
}

struct GeminiUsageMetadata: Codable {
    let promptTokenCount: Int?
    let candidatesTokenCount: Int?
    let totalTokenCount: Int?
}

struct GeminiAPIError: Codable {
    let code: Int?
    let message: String?
    let status: String?
}

// MARK: - LLM Service

/// Thread-safety: No stored mutable state; all methods use URLSession.shared.
final class LLMService: @unchecked Sendable {

    // MARK: - Types

    /// Result of an LLM analysis call, including the parsed analysis and raw usage data.
    struct AnalysisResult {
        let analysis: GeminiVeganAnalysis
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        let model: String
    }

    /// The type of content being analyzed — affects the prompt.
    enum InputType: String {
        case ingredientLabel = "ingredient_label"
        case menu = "menu"
        case productPhoto = "product_photo"
        case foodPhoto = "food_photo"
        case unknown = "unknown"
    }

    // MARK: - Public API

    /// Analyze an image using Gemini Vision API.
    /// - Parameters:
    ///   - image: The photo to analyze.
    ///   - ocrText: Optional OCR-extracted text to provide as context.
    ///   - inputType: What kind of image this is (affects prompt).
    /// - Returns: An AnalysisResult with the verdict, details, and token usage.
    /// Analyze an image using Gemini Vision API.
    /// - Parameters:
    ///   - image: The photo to analyze.
    ///   - ocrText: Optional OCR-extracted text to provide as context.
    ///   - inputType: What kind of image this is (affects prompt).
    ///   - location: Optional location string (e.g. "Thailand", "India") for regional context.
    /// - Returns: An AnalysisResult with the verdict, details, and token usage.
    func analyze(
        image: UIImage,
        ocrText: String? = nil,
        inputType: InputType = .unknown,
        location: String? = nil,
        brandContext: String? = nil
    ) async throws -> AnalysisResult {

        // 1. Prepare the image — resize and compress to save tokens/cost
        let processedImage = resizeImage(image, maxDimension: Config.maxImageDimension)
        guard let imageData = processedImage.jpegData(compressionQuality: Config.imageCompressionQuality) else {
            throw LLMError.imageProcessingFailed
        }
        let base64Image = imageData.base64EncodedString()

        // 2. Build the prompt based on input type
        let prompt = buildPrompt(inputType: inputType, ocrText: ocrText, location: location, brandContext: brandContext)

        // 3. Build the request body
        let requestBody = buildRequestBody(prompt: prompt, base64Image: base64Image)

        // 4. Make the API call with retry logic for transient failures
        let (data, response) = try await withRetry(config: .default) {
            let url: URL
            if Config.useBackendProxy {
                // Use backend proxy (App Store version)
                url = URL(string: Config.backendProxyURL)!
            } else {
                // Direct API call (development)
                guard let apiKey = Config.geminiAPIKey else {
                    throw LLMError.configurationError("API key not configured")
                }
                url = URL(string: "\(Config.geminiBaseURL)/models/\(Config.geminiModel):generateContent?key=\(apiKey)")!
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            // Generous timeout — vision calls can take a few seconds
            request.timeoutInterval = 30

            return try await URLSession.shared.data(for: request)
        }

        // 5. Check HTTP status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Try to parse error message from Gemini
            let apiResponse = try? JSONDecoder().decode(GeminiAPIResponse.self, from: data)
            let errorMessage = apiResponse?.error?.message

            // Map rate-limit / quota errors to a dedicated error type
            // so the pipeline can fall back gracefully and the UI shows a friendlier message
            if httpResponse.statusCode == 429 {
                throw LLMError.rateLimitExceeded
            }
            if httpResponse.statusCode == 403,
                let msg = errorMessage?.lowercased(),
                msg.contains("quota") || msg.contains("rate") || msg.contains("limit") {
                throw LLMError.rateLimitExceeded
            }

            throw LLMError.apiError(
                statusCode: httpResponse.statusCode,
                message: errorMessage ?? "Unknown error"
            )
        }

        // 6. Parse the response
        let apiResponse = try JSONDecoder().decode(GeminiAPIResponse.self, from: data)

        guard let textContent = apiResponse.candidates?.first?.content?.parts?.first?.text else {
            throw LLMError.emptyResponse
        }

        // 7. Extract the JSON from Gemini's response text
        let analysis = try parseAnalysis(from: textContent)
        
        // 8. Validate the response for completeness and sanity
        try validateAnalysis(analysis)

        // 9. Extract token usage
        let promptTokens = apiResponse.usageMetadata?.promptTokenCount ?? 0
        let completionTokens = apiResponse.usageMetadata?.candidatesTokenCount ?? 0
        let totalTokens = apiResponse.usageMetadata?.totalTokenCount ?? 0

        return AnalysisResult(
            analysis: analysis,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            totalTokens: totalTokens,
            model: Config.geminiModel
        )
    }

    // MARK: - Prompt Building

    /// Build the analysis prompt tailored to the input type.
    private func buildPrompt(inputType: InputType, ocrText: String?, location: String?, brandContext: String?) -> String {
        let baseInstruction = """
        You are an expert in analyzing products for vegan suitability (food, cosmetics, household items, etc.).
        Analyze the provided image and determine if the product is vegan.

        IMPORTANT RULES:
        - Be thorough but practical. Flag definite non-vegan ingredients AND ambiguous ones.
        - Watch for hidden animal derivatives (e.g. carmine, lanolin, tallow, beeswax, keratin).
        - If you're uncertain, say so honestly with your best guess and confidence level.
        - Provide actionable suggestions when possible (e.g. "look for a cruelty-free label").
        - Consider regional variations (e.g. Thai food often contains fish sauce).
        - If the image shows a known product, use your knowledge of that product's ingredients.

        Respond ONLY with valid JSON (no markdown, no backticks, no extra text).

        Field constraints:
        - "verdict": must be exactly one of "vegan", "not_vegan", or "uncertain"
        - "confidence": a number between 0.0 and 1.0
        - All array fields may be empty arrays [] if not applicable

        Example response:
        {
          "verdict": "not_vegan",
          "confidence": 0.85,
          "summary": "This lipstick contains carmine, which is derived from insects.",
          "nonVeganIngredients": ["carmine", "beeswax"],
          "ambiguousIngredients": ["fragrance"],
          "suggestions": ["Look for a vegan certified alternative"],
          "productName": "Red Lipstick"
        }
        """

        var contextSection = ""

        switch inputType {
        case .ingredientLabel:
            contextSection = """

            CONTEXT: This image shows a product's ingredient label/list.
            Focus on identifying each ingredient and checking if it's vegan.
            Check for common non-vegan additives in food (milk, egg) AND cosmetics (carmine, lanolin, collagen).
            """

        case .menu:
            contextSection = """

            CONTEXT: This image shows a restaurant menu or menu item description.
            You won't see a full ingredient list — use your knowledge of how these dishes are typically prepared.
            Flag hidden non-vegan ingredients (e.g. Caesar dressing contains anchovies, pad thai often has fish sauce).
            Provide specific questions the user can ask their server.
            """

        case .productPhoto:
            contextSection = """

            CONTEXT: This image shows a product (packaging, bottle, box, etc.) but may NOT show the ingredient list.
            Try to identify the product by its packaging, brand, and name.
            Use your knowledge of this product's typical ingredients.
            If you can't identify it, say so and suggest the user photograph the ingredient list.
            """

        case .foodPhoto:
            contextSection = """

            CONTEXT: This image shows prepared food (a dish, plate, meal).
            There is no ingredient list — analyze what you can see visually.
            Identify visible non-vegan items (cheese, meat, eggs, cream-based sauces).
            This will be your best guess — mention that in your confidence level.
            """

        case .unknown:
            contextSection = """

            CONTEXT: Analyze whatever is shown in this image for vegan-friendliness.
            """
        }
        
        // Add Brand Context if available
        if let brand = brandContext, !brand.isEmpty {
            contextSection += """

            KNOWN BRAND CONTEXT: \(brand)
            Use this as a helpful signal, but still verify the specific product's ingredients.
            """
        }

        // Add Location Context if available
        if let location = location, !location.isEmpty {
            contextSection += """

            USER LOCATION: \(location)
            Apply local food norms and ingredient risks for this region.
            Example: "Vegetarian" in India (Lacto-Veg) vs Thailand (Jay/Vegan).
            """
        }

        // Add OCR text if available
        var ocrSection = ""
        if let ocrText = ocrText, !ocrText.isEmpty {
            ocrSection = """

            EXTRACTED TEXT (from OCR — may contain errors):
            \(ocrText)
            """
        }

        return baseInstruction + contextSection + ocrSection
    }

    // MARK: - Request Building

    /// Build the Gemini API request body with inline image data.
    private func buildRequestBody(prompt: String, base64Image: String) -> [String: Any] {
        return [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        [
                            "inlineData": [
                                "mimeType": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2,       // Low temperature for more consistent/factual output
                "maxOutputTokens": 4096,  // Raised from 1024 — 2.5 Flash uses thinking tokens on top
                "topP": 0.8,
                "responseMimeType": "application/json",
                "thinkingConfig": [
                    "thinkingBudget": 1024  // Cap thinking tokens — enough for ingredient analysis
                ]
            ]
        ]
    }

    // MARK: - Response Parsing

    /// Parse the GeminiVeganAnalysis JSON from the model's text output.
    /// Handles cases where Gemini wraps the JSON in markdown code blocks.
    private func parseAnalysis(from text: String) throws -> GeminiVeganAnalysis {
        // Strip markdown code block wrappers if present
        var jsonString = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove ```json ... ``` wrapper
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw LLMError.invalidJSON(text)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(GeminiVeganAnalysis.self, from: jsonData)
        } catch {
            throw LLMError.invalidJSON(text)
        }
    }

    // MARK: - Response Validation
    
    /// Validate the AI analysis for completeness and sanity checks.
    /// Throws if the response is invalid or contains suspicious values.
    private func validateAnalysis(_ analysis: GeminiVeganAnalysis) throws {
        // 1. Validate verdict is one of the allowed values
        let validVerdicts: Set<String> = ["vegan", "not_vegan", "uncertain"]
        guard validVerdicts.contains(analysis.verdict) else {
            throw LLMError.invalidAnalysis(reason: "Invalid verdict '\(analysis.verdict)'")
        }
        
        // 2. Validate confidence is in valid range
        guard (0.0...1.0).contains(analysis.confidence) else {
            throw LLMError.invalidAnalysis(reason: "Confidence \(analysis.confidence) out of range [0,1]")
        }
        
        // 3. Validate summary is not empty or too short
        guard !analysis.summary.isEmpty, analysis.summary.count >= 10 else {
            throw LLMError.invalidAnalysis(reason: "Summary too short or empty")
        }
        
        // 4. Validate productName is not empty
        guard !analysis.productName.isEmpty, analysis.productName.count >= 2 else {
            throw LLMError.invalidAnalysis(reason: "Product name missing or too short")
        }
        
        // 5. Sanity check: if verdict is not_vegan, there should be flagged ingredients
        if analysis.verdict == "not_vegan" {
            let hasFlaggedIngredients = !analysis.nonVeganIngredients.isEmpty || !analysis.ambiguousIngredients.isEmpty
            if !hasFlaggedIngredients {
                // This is suspicious but not fatal - log warning but don't throw
                print("[LLMService] ⚠️ Verdict is not_vegan but no ingredients flagged - possible hallucination")
            }
        }
        
        // 6. Check for obviously invalid data (string lengths, etc.)
        if analysis.summary.count > 5000 {
            throw LLMError.invalidAnalysis(reason: "Summary unreasonably long (possible hallucination)")
        }
        
        if analysis.productName.count > 200 {
            throw LLMError.invalidAnalysis(reason: "Product name unreasonably long")
        }
        
        // 7. Check for too many flagged ingredients (possible parsing error)
        let totalFlagged = analysis.nonVeganIngredients.count + analysis.ambiguousIngredients.count
        if totalFlagged > 50 {
            throw LLMError.invalidAnalysis(reason: "Too many flagged ingredients (\(totalFlagged)) - possible error")
        }
        
        // All validations passed
        print("[LLMService] ✓ Analysis validation passed")
    }
    
    // MARK: - Image Processing

    /// Resize an image so its longest dimension is at most `maxDimension`.
    /// This reduces the token count (and cost) when sending to Gemini.
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longestSide = max(size.width, size.height)

        // No resize needed if already small enough
        guard longestSide > maxDimension else { return image }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Errors

enum LLMError: LocalizedError {
    case imageProcessingFailed
    case invalidResponse
    case emptyResponse
    case apiError(statusCode: Int, message: String)
    case invalidJSON(String)
    case rateLimitExceeded
    case configurationError(String)
    case invalidAnalysis(reason: String)

    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Failed to process the image for analysis."
        case .invalidResponse:
            return "Received an invalid response from the AI service."
        case .emptyResponse:
            return "The AI service returned an empty response. Please try again."
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        case .invalidJSON(let raw):
            return "Failed to parse AI response. Raw: \(raw.prefix(200))"
        case .rateLimitExceeded:
            return "You've reached your usage limit. Try again tomorrow."
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .invalidAnalysis(let reason):
            return "AI returned invalid analysis: \(reason)"
        }
    }
}
