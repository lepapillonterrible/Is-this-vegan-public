// VeganBrandService.swift
// IsThisVegan
//
// Offline database of known vegan (and mostly-vegan) brands.
// Loaded from Resources/VeganBrands.json at init time.
//
// Usage: after OCR, call lookup(in: ocrText) to check if a known brand
// is visible on the product. The result is used to:
//   1. Inject brand context into the LLM prompt for better analysis.
//   2. Add a helpful note in the ScanResult explanation.
//
// ⚠️ The brand database is a SIGNAL, not a verdict.
//    Even a 100% vegan brand can have non-vegan regional variants,
//    cross-contamination, or limited-edition collab products.
//    The LLM still runs for final verdict.

import Foundation

// MARK: - JSON Models

private struct BrandDatabase: Codable {
    let brands: [BrandEntry]
}

private struct BrandEntry: Codable {
    let name: String
    let aliases: [String]
    let confidence: String          // "fully_vegan" | "mostly_vegan" | "vegan_line"
    let category: String
    let certifications: [String]
    let note: String
    let website: String
}

// MARK: - Public Types

/// Confidence level of a brand's vegan status.
enum BrandConfidence: String {
    /// The brand's entire product line is vegan.
    case fullyVegan = "fully_vegan"
    /// The brand is majority vegan — some products may not be.
    case mostlyVegan = "mostly_vegan"
    /// Only a specific sub-line is labelled vegan.
    case veganLine = "vegan_line"

    /// Human-readable label used in UI explanations.
    var displayText: String {
        switch self {
        case .fullyVegan:  return "fully vegan brand"
        case .mostlyVegan: return "mostly vegan brand"
        case .veganLine:   return "has a vegan range"
        }
    }

    /// Emoji badge for quick visual communication.
    var badge: String {
        switch self {
        case .fullyVegan:  return "🌱"
        case .mostlyVegan: return "🌿"
        case .veganLine:   return "⚠️"
        }
    }
}

/// Result of a brand lookup against OCR text.
struct BrandMatch {
    /// The canonical brand name as it appears in the database.
    let brandName: String
    /// Product category (e.g. "dairy_alternative", "cosmetics").
    let category: String
    /// How vegan-friendly this brand is.
    let confidence: BrandConfidence
    /// Certifications held by the brand (e.g. ["Vegan Society"]).
    let certifications: [String]
    /// A human-readable note to show in the result explanation.
    let note: String

    /// A short, formatted context string suitable for injecting into LLM prompts.
    var promptContext: String {
        var parts = ["Brand: \(brandName) (\(confidence.displayText))"]
        if !certifications.isEmpty {
            parts.append("Certifications: \(certifications.joined(separator: ", "))")
        }
        parts.append("Note: \(note)")
        return parts.joined(separator: ". ")
    }

    /// A user-facing explanation note to append to the ScanResult.
    var explanationNote: String {
        var text = "\(confidence.badge) \(brandName) is a \(confidence.displayText)"
        if !certifications.isEmpty {
            text += " (certified by \(certifications.joined(separator: ", ")))"
        }
        text += ". \(note)"
        return text
    }
}

// MARK: - VeganBrandService

/// Thread-safety: Dictionaries are populated once in init() and only read thereafter.
final class VeganBrandService: @unchecked Sendable {

    // MARK: - Storage

    /// Maps lowercase brand name/alias → full BrandEntry for fast lookup.
    private var brandIndex: [String: BrandEntry] = [:]

    // MARK: - Init

    init() {
        loadDatabase()
    }

    // MARK: - Public API

    /// Scan a block of OCR text and return the first matching known brand.
    /// Returns `nil` if no known brand is detected.
    ///
    /// - Parameter text: Raw OCR output from the image.
    /// - Returns: A `BrandMatch` if a brand is found, otherwise `nil`.
    func lookup(in text: String) -> BrandMatch? {
        let lowered = text.lowercased()

        // Sort by name length descending so longer / more specific names match first
        // (e.g. "Beyond Burger" before "Beyond")
        let sorted = brandIndex.keys.sorted { $0.count > $1.count }

        for key in sorted {
            guard let entry = brandIndex[key] else { continue }
            if containsWholeWord(key, in: lowered) {
                return makeBrandMatch(from: entry)
            }
        }
        return nil
    }

    /// Lookup all matching brands in the OCR text (not just the first).
    /// Useful when a label mentions multiple brand partnerships.
    func lookupAll(in text: String) -> [BrandMatch] {
        let lowered = text.lowercased()
        var seen = Set<String>()
        var matches: [BrandMatch] = []

        let sorted = brandIndex.keys.sorted { $0.count > $1.count }
        for key in sorted {
            guard let entry = brandIndex[key] else { continue }
            guard !seen.contains(entry.name) else { continue }
            if containsWholeWord(key, in: lowered) {
                seen.insert(entry.name)
                matches.append(makeBrandMatch(from: entry))
            }
        }
        return matches
    }

    // MARK: - Private

    private func makeBrandMatch(from entry: BrandEntry) -> BrandMatch {
        let confidence = BrandConfidence(rawValue: entry.confidence) ?? .veganLine
        return BrandMatch(
            brandName: entry.name,
            category: entry.category,
            confidence: confidence,
            certifications: entry.certifications,
            note: entry.note
        )
    }

    /// Whole-word check so "Oreo" doesn't match "Oreos" only, and "Silk" doesn't
    /// match words like "silky".
    private func containsWholeWord(_ word: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: word)
        // Allow word boundaries or punctuation (brand names can appear as "Oatly!")
        let pattern = "(?<![\\w])\(escaped)(?![\\w])"
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Loading

    private func loadDatabase() {
        guard let url = Bundle.main.url(forResource: "VeganBrands", withExtension: "json") else {
            print("[VeganBrandService] VeganBrands.json not found in bundle.")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let db = try JSONDecoder().decode(BrandDatabase.self, from: data)

            for entry in db.brands {
                brandIndex[entry.name.lowercased()] = entry
                for alias in entry.aliases {
                    brandIndex[alias.lowercased()] = entry
                }
            }
            print("[VeganBrandService] Loaded \(db.brands.count) brands (\(brandIndex.count) index keys).")
        } catch {
            print("[VeganBrandService] Failed to load database: \(error)")
        }
    }
}
