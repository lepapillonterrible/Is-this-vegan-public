// ScanResult.swift
// IsThisVegan
//
// Core data model representing a single scan result.
// Persisted via SwiftData and shared with the widget via App Group.

import Foundation
import SwiftData
import UIKit

@Model
final class ScanResult {
    /// Unique identifier
    var id: UUID
    
    /// When the scan was performed
    var timestamp: Date
    
    /// The verdict: vegan, not vegan, or uncertain
    var verdictRaw: String
    
    /// Name of the product or menu item (extracted by AI)
    var productName: String
    
    /// Detailed explanation from the AI about why the verdict was given
    var explanation: String
    
    /// List of non-vegan ingredients found (if any)
    var flaggedIngredients: [String] = []
    
    /// Raw OCR text extracted from the image (if OCR was used)
    var ocrText: String?
    
    /// The original image data (stored as JPEG for efficiency)
    @Attribute(.externalStorage)
    var imageData: Data?
    
    // MARK: - Computed Properties
    
    /// Type-safe verdict accessor
    var verdict: VeganVerdict {
        get { VeganVerdict(rawValue: verdictRaw) ?? .error }
        set { verdictRaw = newValue.rawValue }
    }
    
    /// Thumbnail image for display in lists
    var thumbnailImage: UIImage? {
        guard let imageData else { return nil }
        return UIImage(data: imageData)
    }
    
    // MARK: - Initialization
    
    init(
        verdict: VeganVerdict,
        productName: String,
        explanation: String,
        flaggedIngredients: [String] = [],
        ocrText: String? = nil,
        imageData: Data? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.verdictRaw = verdict.rawValue
        self.productName = productName
        self.explanation = explanation
        self.flaggedIngredients = flaggedIngredients
        self.ocrText = ocrText
        self.imageData = imageData
    }
}

// MARK: - Sample Data (for previews and testing)

extension ScanResult {
    static var sampleVegan: ScanResult {
        ScanResult(
            verdict: .vegan,
            productName: "Oat Milk Latte",
            explanation: "This product contains oat milk, water, and natural flavors. All ingredients are plant-based.",
            flaggedIngredients: []
        )
    }
    
    static var sampleNotVegan: ScanResult {
        ScanResult(
            verdict: .notVegan,
            productName: "Chocolate Chip Cookie",
            explanation: "This product contains butter (dairy), eggs, and whey protein — all animal-derived ingredients.",
            flaggedIngredients: ["Butter", "Eggs", "Whey Protein"]
        )
    }
    
    static var sampleUncertain: ScanResult {
        ScanResult(
            verdict: .uncertain,
            productName: "Gummy Bears",
            explanation: "This product lists 'natural flavors' and 'confectioner's glaze' which may or may not be animal-derived. The gelatin source is not specified.",
            flaggedIngredients: ["Natural Flavors", "Confectioner's Glaze", "Gelatin (source unknown)"]
        )
    }
}
