// IngredientDatabase.swift
// IsThisVegan
//
// Local ingredient database loaded from NonVeganIngredients.json.
// Provides fast, offline, zero-cost pre-screening of ingredient text
// BEFORE calling the Gemini API. This saves API calls (and money)
// when the answer is obvious from the ingredient list alone.
//
// The database supports:
// - Canonical names + aliases (e.g. "ghee" → "clarified butter", "เนยใส")
// - Categories (dairy, meat, seafood, etc.)
// - Ambiguous ingredients with explanatory notes
// - Exceptions (e.g. "cream" is bad, but "coconut cream" is fine)

import Foundation

// MARK: - JSON Models

/// Top-level structure of NonVeganIngredients.json
private struct IngredientDataFile: Codable {
    let definitely_not_vegan: [IngredientEntry]
    let ambiguous: [AmbiguousEntry]
}

/// A definitely-not-vegan ingredient with aliases, category, and exceptions.
private struct IngredientEntry: Codable {
    let name: String
    let aliases: [String]
    let category: String
    let exceptions: [String]? // NEW: Phrases that contain the name but are actually vegan
}

/// An ingredient that may or may not be vegan depending on source.
private struct AmbiguousEntry: Codable {
    let name: String
    let aliases: [String]
    let note: String
}

// MARK: - Public Result Types

/// Result of checking a single ingredient against the database.
struct IngredientLookup {
    let matchedTerm: String   // The term from the DB that matched
    let category: String      // e.g. "dairy", "meat", "seafood"
    let isDefinitelyNonVegan: Bool  // true = definitely not vegan, false = ambiguous
    let note: String?         // Explanation for ambiguous items
}

/// Result of scanning a full text for non-vegan ingredients.
struct LocalScanResult {
    let definitelyNonVegan: [IngredientLookup]
    let ambiguous: [IngredientLookup]

    /// Quick verdict based on local DB alone.
    var localVerdict: LocalVerdict {
        if !definitelyNonVegan.isEmpty { return .notVegan }
        if !ambiguous.isEmpty { return .uncertain }
        return .possiblyVegan
    }
}

/// Verdict from local-only analysis (before calling the LLM).
enum LocalVerdict {
    case notVegan       // Found definite non-vegan ingredients
    case uncertain      // Found ambiguous ingredients only
    case possiblyVegan  // Nothing flagged — but LLM should still verify
}

// MARK: - IngredientDatabase

/// Thread-safety: Dictionaries are populated once in init() and only read thereafter.
final class IngredientDatabase: @unchecked Sendable {

    /// Data structure for a registered non-vegan term
    private struct TermInfo {
        let name: String
        let category: String
        let exceptions: [String]
    }

    /// All search terms for definitely-not-vegan ingredients.
    /// Maps lowercased term → Info.
    private var nonVeganTerms: [String: TermInfo] = [:]

    /// All search terms for ambiguous ingredients.
    /// Maps lowercased term → (canonical name, note).
    private var ambiguousTerms: [String: (name: String, note: String)] = [:]

    // MARK: - Init

    init() {
        loadDatabase()
    }

    // MARK: - Public API

    /// Check a single ingredient string against the database.
    /// Returns nil if the ingredient is not found (assumed vegan).
    func lookup(_ ingredient: String) -> IngredientLookup? {
        let lowered = ingredient.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check definitely-not-vegan first
        for (term, info) in nonVeganTerms {
            if containsWholeWord(term, in: lowered) {
                // Check exceptions (e.g. if term is "cream", ignore if text is "coconut cream")
                if !isException(term: term, in: lowered, exceptions: info.exceptions) {
                    return IngredientLookup(
                        matchedTerm: info.name,
                        category: info.category,
                        isDefinitelyNonVegan: true,
                        note: nil
                    )
                }
            }
        }

        // Check ambiguous
        for (term, info) in ambiguousTerms {
            if containsWholeWord(term, in: lowered) {
                return IngredientLookup(
                    matchedTerm: info.name,
                    category: "ambiguous",
                    isDefinitelyNonVegan: false,
                    note: info.note
                )
            }
        }

        return nil
    }

    /// Scan a block of text (e.g. OCR output) and find all non-vegan
    /// and ambiguous ingredients mentioned.
    func scanText(_ text: String) -> LocalScanResult {
        let lowered = text.lowercased()
        var definite: [IngredientLookup] = []
        var ambiguous: [IngredientLookup] = []
        var seenNames = Set<String>()

        // Check all definitely-not-vegan terms
        for (term, info) in nonVeganTerms {
            guard !seenNames.contains(info.name) else { continue }
            
            if containsWholeWord(term, in: lowered) {
                // If the word exists, verify it's not part of an exception phrase
                if !isException(term: term, in: lowered, exceptions: info.exceptions) {
                    seenNames.insert(info.name)
                    definite.append(IngredientLookup(
                        matchedTerm: info.name,
                        category: info.category,
                        isDefinitelyNonVegan: true,
                        note: nil
                    ))
                }
            }
        }

        // Check all ambiguous terms
        for (term, info) in ambiguousTerms {
            guard !seenNames.contains(info.name) else { continue }
            if containsWholeWord(term, in: lowered) {
                seenNames.insert(info.name)
                ambiguous.append(IngredientLookup(
                    matchedTerm: info.name,
                    category: "ambiguous",
                    isDefinitelyNonVegan: false,
                    note: info.note
                ))
            }
        }

        return LocalScanResult(
            definitelyNonVegan: definite.sorted { $0.matchedTerm < $1.matchedTerm },
            ambiguous: ambiguous.sorted { $0.matchedTerm < $1.matchedTerm }
        )
    }

    // MARK: - Word Matching

    /// Check if `term` appears as a whole word in `text`.
    private func containsWholeWord(_ term: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: term)
        let pattern = "\\b\(escaped)\\b"
        return text.range(of: pattern, options: .regularExpression) != nil
    }
    
    /// Returns true if the found term is actually part of an exception phrase.
    /// e.g. term="cream", text="coconut cream", exceptions=["coconut cream"]
    private func isException(term: String, in text: String, exceptions: [String]) -> Bool {
        guard !exceptions.isEmpty else { return false }
        
        // 1. Remove all exception phrases from the text
        var cleanText = text
        for exception in exceptions {
            cleanText = cleanText.replacingOccurrences(of: exception, with: "")
        }
        
        // 2. Check if the term still exists in the cleaned text
        // If it's gone, it meant it was only present inside an exception.
        return !containsWholeWord(term, in: cleanText)
    }

    // MARK: - Loading

    /// Load the ingredient database from the bundled JSON file.
    private func loadDatabase() {
        guard let url = Bundle.main.url(forResource: "NonVeganIngredients", withExtension: "json") else {
            loadFallbackDatabase()
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(IngredientDataFile.self, from: data)

            // Index definitely-not-vegan items
            for entry in file.definitely_not_vegan {
                let name = entry.name.lowercased()
                let category = entry.category
                let exceptions = entry.exceptions?.map { $0.lowercased() } ?? []
                
                // Register the canonical name
                nonVeganTerms[name] = TermInfo(name: entry.name, category: category, exceptions: exceptions)
                
                // Register all aliases
                for alias in entry.aliases {
                    nonVeganTerms[alias.lowercased()] = TermInfo(name: entry.name, category: category, exceptions: exceptions)
                }
            }

            // Index ambiguous items
            for entry in file.ambiguous {
                let name = entry.name.lowercased()
                ambiguousTerms[name] = (name: entry.name, note: entry.note)
                for alias in entry.aliases {
                    ambiguousTerms[alias.lowercased()] = (name: entry.name, note: entry.note)
                }
            }

            print("[IngredientDatabase] Loaded \(nonVeganTerms.count) non-vegan terms, \(ambiguousTerms.count) ambiguous terms")

        } catch {
            print("[IngredientDatabase] Failed to parse JSON: \(error). Using fallback.")
            loadFallbackDatabase()
        }
    }

    /// Minimal fallback if the JSON file can't be loaded.
    private func loadFallbackDatabase() {
        let basics = [
            "milk", "butter", "cream", "cheese", "whey", "casein", "lactose",
            "egg", "eggs", "albumin", "honey", "beeswax",
            "gelatin", "gelatine", "collagen", "lard", "tallow",
            "chicken", "beef", "pork", "fish", "shrimp",
            "anchovy", "anchovies", "carmine", "shellac",
            "fish sauce", "oyster sauce", "shrimp paste"
        ]
        for term in basics {
            nonVeganTerms[term] = TermInfo(name: term, category: "unknown", exceptions: [])
        }
        print("[IngredientDatabase] Loaded fallback database with \(basics.count) terms")
    }
}
