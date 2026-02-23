// HeuristicService.swift
// IsThisVegan
//
// Augments AI analysis with definitive local knowledge.
// Loads a JSON of regional food rules (e.g. "Pad Thai in Thailand usually has fish sauce")
// and checks the AI's predicted "product name" against this database.
//
// This helps catch common pitfalls that visual AI might miss (e.g. looking at a curry
// and not knowing it contains hidden shrimp paste).

import Foundation

struct RegionalRuleSet: Codable {
    let regionName: String
    let risks: [String]
    let dishes: [String: DishRule]
}

struct DishRule: Codable {
    enum Status: String, Codable {
        case vegan = "VEGAN"
        case likelyVegan = "LIKELY_VEGAN"
        case risky = "RISKY"
        case notVegan = "NOT_VEGAN"
    }
    
    let status: Status
    let reason: String
}

final class HeuristicService: @unchecked Sendable {
    
    // MARK: - State
    
    /// Map of Country Code (e.g. "TH") -> Rules
    private var rules: [String: RegionalRuleSet] = [:]
    
    // MARK: - Lifecycle
    
    init() {
        loadRules()
    }
    
    private func loadRules() {
        // Try root first, then Resources subdirectory
        let url = Bundle.main.url(forResource: "RegionalRules", withExtension: "json") ??
                  Bundle.main.url(forResource: "RegionalRules", withExtension: "json", subdirectory: "Resources")
                  
        guard let validUrl = url else {
            print("[HeuristicService] RegionalRules.json not found in bundle.")
            return
        }
        
        do {
            let data = try Data(contentsOf: validUrl)
            self.rules = try JSONDecoder().decode([String: RegionalRuleSet].self, from: data)
            print("[HeuristicService] Loaded rules for \(rules.count) regions.")
        } catch {
            print("[HeuristicService] Failed to load rules: \(error)")
        }
    }
    
    // MARK: - Public API
    
    /// Check a dish name against local rules for the given region.
    func checkDish(name: String, regionCode: String) -> DishRule? {
        guard let regionRules = rules[regionCode], !name.isEmpty else { return nil }
        
        // Normalize name for lookup (lowercase, trimmed)
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Direct lookup
        if let rule = regionRules.dishes[normalizedName] {
            return rule
        }
        
        // Fuzzy / Partial match (e.g. "Chicken Pad Thai" matches "pad thai")
        // We look for keys in our DB that appear in the input string
        for (key, rule) in regionRules.dishes {
            if normalizedName.contains(key) {
                return rule
            }
        }
        
        return nil
    }
    
    /// Get a list of high-risk ingredients for a region (e.g. "fish sauce" for TH).
    func getRegionalRisks(for regionCode: String) -> [String] {
        return rules[regionCode]?.risks ?? []
    }
}
