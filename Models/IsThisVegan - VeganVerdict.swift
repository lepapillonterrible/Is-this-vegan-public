// VeganVerdict.swift
// IsThisVegan
//
// Represents the possible outcomes of a vegan analysis.
// Used throughout the app and widget to display results.

import SwiftUI

/// The result of analyzing whether a product/menu item is vegan
enum VeganVerdict: String, Codable, CaseIterable {
    case vegan = "vegan"
    case notVegan = "not_vegan"
    case uncertain = "uncertain"
    case error = "error"
    
    // MARK: - Display Properties
    
    /// User-facing title (includes emoji)
    var title: String {
        switch self {
        case .vegan:    return "Vegan ✅"
        case .notVegan: return "Not Vegan ❌"
        case .uncertain: return "Uncertain ⚠️"
        case .error:    return "Error"
        }
    }
    
    /// Short description for the widget
    var shortTitle: String {
        switch self {
        case .vegan:    return "Vegan"
        case .notVegan: return "Not Vegan"
        case .uncertain: return "Unsure"
        case .error:    return "Error"
        }
    }

    /// Clean label without emoji — used in result cards and detail views
    var label: String {
        switch self {
        case .vegan:    return "Vegan Friendly"
        case .notVegan: return "Not Vegan"
        case .uncertain: return "Uncertain"
        case .error:    return "Analysis Error"
        }
    }

    /// Single emoji for compact display (list rows, badges, hero sections)
    var emoji: String {
        switch self {
        case .vegan:    return "🌱"
        case .notVegan: return "🚫"
        case .uncertain: return "🤔"
        case .error:    return "⚠️"
        }
    }
    
    /// Color associated with this verdict
    var color: Color {
        switch self {
        case .vegan:    return .green
        case .notVegan: return .red
        case .uncertain: return .orange
        case .error:    return .gray
        }
    }
    
    /// SF Symbol icon name
    var iconName: String {
        switch self {
        case .vegan:    return "leaf.fill"
        case .notVegan: return "xmark.circle.fill"
        case .uncertain: return "questionmark.circle.fill"
        case .error:    return "exclamationmark.triangle.fill"
        }
    }
    
    /// Background gradient for result display
    var gradient: LinearGradient {
        switch self {
        case .vegan:
            return LinearGradient(
                colors: [.green.opacity(0.3), .mint.opacity(0.2)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .notVegan:
            return LinearGradient(
                colors: [.red.opacity(0.3), .pink.opacity(0.2)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .uncertain:
            return LinearGradient(
                colors: [.orange.opacity(0.3), .yellow.opacity(0.2)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .error:
            return LinearGradient(
                colors: [.gray.opacity(0.3), .gray.opacity(0.1)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
}
