// LLMServiceValidationTests.swift
// IsThisVeganTests
//
// Tests for LLMService response validation.

import XCTest
@testable import IsThisVegan

final class LLMServiceValidationTests: XCTestCase {
    
    // Helper to create a valid analysis for testing
    private func createValidAnalysis() -> GeminiVeganAnalysis {
        return GeminiVeganAnalysis(
            verdict: "vegan",
            confidence: 0.85,
            summary: "This product appears to be vegan-friendly based on the ingredient list.",
            nonVeganIngredients: [],
            ambiguousIngredients: [],
            suggestions: ["Double-check with manufacturer"],
            productName: "Test Product"
        )
    }
    
    // MARK: - Valid Analysis Tests
    
    func testValidation_AcceptsValidVeganVerdict() {
        //Given: A valid analysis with vegan verdict
        let analysis = GeminiVeganAnalysis(
            verdict: "vegan",
            confidence: 0.9,
            summary: "All ingredients are plant-based and cruelty-free.",
            nonVeganIngredients: [],
            ambiguousIngredients: [],
            suggestions: [],
            productName: "Vegan Protein Bar"
        )
        
        // When/Then: Validation should pass (no throw)
        let service = LLMService()
        XCTAssertNoThrow(try service.validateAnalysis(analysis))
    }
    
    func testValidation_AcceptsValidNotVeganVerdict() {
        // Given: A valid analysis with not_vegan verdict
        let analysis = GeminiVeganAnalysis(
            verdict: "not_vegan",
            confidence: 0.95,
            summary: "Contains milk and eggs.",
            nonVeganIngredients: ["milk", "eggs"],
            ambiguousIngredients: [],
            suggestions: ["Look for plant-based alternatives"],
            productName: "Chocolate Cake"
        )
        
        // When/Then: Validation should pass
        let service = LLMService()
        XCTAssertNoThrow(try service.validateAnalysis(analysis))
    }
    
    func testValidation_AcceptsValidUncertainVerdict() {
        // Given: A valid analysis with uncertain verdict
        let analysis = GeminiVeganAnalysis(
            verdict: "uncertain",
            confidence: 0.6,
            summary: "Unable to determine definitively due to ambiguous ingredients.",
            nonVeganIngredients: [],
            ambiguousIngredients: ["natural flavors", "mono and diglycerides"],
            suggestions: ["Contact manufacturer for clarification"],
            productName: "Mixed Nuts"
        )
        
        // When/Then: Validation should pass
        let service = LLMService()
        XCTAssertNoThrow(try service.validateAnalysis(analysis))
    }
    
    // MARK: - Invalid Verdict Tests
    
    func testValidation_RejectsInvalidVerdict() {
        // Given: An analysis with invalid verdict
        var analysis = createValidAnalysis()
        analysis.verdict = "maybe_vegan"  // Invalid verdict
        
        // When/Then: Should throw invalidAnalysis error
        let service = LLMService()
        XCTAssertThrowsError(try service.validateAnalysis(analysis)) { error in
            guard case LLMError.invalidAnalysis(let reason) = error else {
                XCTFail("Expected invalidAnalysis error")
                return
            }
            XCTAssertTrue(reason.contains("verdict"))
        }
    }
    
    func testValidation_RejectsEmptyVerdict() {
        // Given: An analysis with empty verdict
        var analysis = createValidAnalysis()
        analysis.verdict = ""
        
        // When/Then: Should throw
        let service = LLMService()
        XCTAssertThrowsError(try service.validateAnalysis(analysis))
    }
    
    // MARK: - Invalid Confidence Tests
    
    func testValidation_RejectsNegativeConfidence() {
        // Given: An analysis with negative confidence
        var analysis = createValidAnalysis()
        analysis.confidence = -0.1
        
        // When/Then: Should throw
        let service = LLMService()
        XCTAssertThrowsError(try service.validateAnalysis(analysis)) { error in
            guard case LLMError.invalidAnalysis(let reason) = error else {
                XCTFail("Expected invalidAnalysis error")
                return
            }
            XCTAssertTrue(reason.localizedCaseInsensitiveContains("confidence"))
        }
    }
    
    func testValidation_RejectsConfidenceAboveOne() {
        // Given: An analysis with confidence > 1.0
        var analysis = createValidAnalysis()
        analysis.confidence = 1.5
        
        // When/Then: Should throw
        let service = LLMService()
        XCTAssertThrowsError(try service.validateAnalysis(analysis))
    }
    
    func testValidation_AcceptsEdgeCaseConfidenceValues() {
        // Test boundary values
        let service = LLMService()
        
        // Test 0.0
        var analysis1 = createValidAnalysis()
        analysis1.confidence = 0.0
        XCTAssertNoThrow(try service.validateAnalysis(analysis1))
        
        // Test 1.0
        var analysis2 = createValidAnalysis()
        analysis2.confidence = 1.0
        XCTAssertNoThrow(try service.validateAnalysis(analysis2))
    }
    
    // MARK: - Invalid Summary Tests
    
    func testValidation_RejectsEmptySummary() {
        // Given: An analysis with empty summary
        var analysis = createValidAnalysis()
        analysis.summary = ""
        
        // When/Then: Should throw
        let service = LLMService()
        XCTAssertThrowsError(try service.validateAnalysis(analysis)) { error in
            guard case LLMError.invalidAnalysis(let reason) = error else {
                XCTFail("Expected invalidAnalysis error")
                return
            }
            XCTAssertTrue(reason.localizedCaseInsensitiveContains("summary"))
        }
    }
    
    func testValidation_RejectsTooShortSummary() {
        // Given: An analysis with too short summary
        var analysis = createValidAnalysis()
        analysis.summary = "Too short"  // Less than 10 characters
        
        // When/Then: Should throw
        let service = LLMService()
        XCTAssertThrowsError(try service.validateAnalysis(analysis))
    }
    
    func testValidation_RejectsExcessivelyLongSummary() {
        // Given: An analysis with unreasonably long summary
        var analysis = createValidAnalysis()
        analysis.summary = String(repeating: "a", count: 6000)  // > 5000 characters
        
        // When/Then: Should throw (possible hallucination)
        let service = LLMService()
        XCTAssertThrowsError(try service.validateAnalysis(analysis)) { error in
            guard case LLMError.invalidAnalysis(let reason) = error else {
                XCTFail("Expected invalidAnalysis error")
                return
            }
            XCTAssertTrue(reason.localizedCaseInsensitiveContains("long"))
        }
    }
    
    // MARK: - Invalid Product Name Tests
    
    func testValidation_RejectsEmptyProductName() {
        // Given: An analysis with empty product name
        var analysis = createValidAnalysis()
        analysis.productName = ""
        
        // When/Then: Should throw
        let service = LLMService()
        XCTAssertThrowsError(try service.validateAnalysis(analysis))
    }
    
    func testValidation_RejectsTooShortProductName() {
        // Given: An analysis with single character product name
        var analysis = createValidAnalysis()
        analysis.productName = "A"
        
        // When/Then: Should throw
        let service = LLMService()
        XCTAssertThrowsError(try service.validateAnalysis(analysis))
    }
    
    func testValidation_RejectsExcessivelyLongProductName() {
        // Given: An analysis with unreasonably long product name
        var analysis = createValidAnalysis()
        analysis.productName = String(repeating: "Product Name ", count: 20)  // > 200 characters
        
        // When/Then: Should throw
        let service = LLMService()
        XCTAssertThrowsError(try service.validateAnalysis(analysis))
    }
    
    // MARK: - Ingredient List Validation Tests
    
    func testValidation_AcceptsTooManyFlaggedIngredients() {
        // Given: An analysis with suspiciously many flagged ingredients
        var analysis = createValidAnalysis()
        analysis.verdict = "not_vegan"
        analysis.nonVeganIngredients = Array(repeating: "ingredient", count: 60)
        
        // When/Then: Should throw (likely a parsing error)
        let service = LLMService()
        XCTAssertThrowsError(try service.validateAnalysis(analysis)) { error in
            guard case LLMError.invalidAnalysis(let reason) = error else {
                XCTFail("Expected invalidAnalysis error")
                return
            }
            XCTAssertTrue(reason.localizedCaseInsensitiveContains("too many"))
        }
    }
    
    func testValidation_AcceptsReasonableNumberOfIngredients() {
        // Given: An analysis with reasonable ingredient counts
        var analysis = createValidAnalysis()
        analysis.verdict = "not_vegan"
        analysis.nonVeganIngredients = ["milk", "eggs", "honey"]
        analysis.ambiguousIngredients = ["natural flavors", "mono and diglycerides"]
        
        // When/Then: Should pass (5 total < 50 limit)
        let service = LLMService()
        XCTAssertNoThrow(try service.validateAnalysis(analysis))
    }
    
    // MARK: - Sanity Check Tests
    
    func testValidation_WarnsAboutNotVeganWithoutFlaggedIngredients() {
        // Given: An analysis marked not_vegan but no ingredients flagged
        var analysis = createValidAnalysis()
        analysis.verdict = "not_vegan"
        analysis.summary = "This contains animal products"
        analysis.nonVeganIngredients = []
        analysis.ambiguousIngredients = []
        
        // When: We validate (should pass but log warning)
        let service = LLMService()
        
        // Then: Should not throw (just warning logged)
        XCTAssertNoThrow(try service.validateAnalysis(analysis))
    }
    
    // MARK: - Integration: Real-World Examples
    
    func testValidation_AcceptsRealWorldVeganExample() {
        // Real-world example of vegan product analysis
        let analysis = GeminiVeganAnalysis(
            verdict: "vegan",
            confidence: 0.92,
            summary: "This oat milk contains only plant-based ingredients: oats, water, sunflower oil, and sea salt. No animal-derived ingredients detected.",
            nonVeganIngredients: [],
            ambiguousIngredients: [],
            suggestions: ["Look for certification labels for additional assurance"],
            productName: "Oatly Oat Milk"
        )
        
        let service = LLMService()
        XCTAssertNoThrow(try service.validateAnalysis(analysis))
    }
    
    func testValidation_AcceptsRealWorldNotVeganExample() {
        // Real-world example of non-vegan product
        let analysis = GeminiVeganAnalysis(
            verdict: "not_vegan",
            confidence: 0.98,
            summary: "This yogurt contains milk, which is an animal-derived ingredient. It also contains live bacterial cultures which are typically vegan, but the milk base makes it unsuitable for vegans.",
            nonVeganIngredients: ["milk", "whey protein concentrate"],
            ambiguousIngredients: [],
            suggestions: ["Try plant-based yogurt alternatives made from coconut, almond, or soy"],
            productName: "Greek Yogurt"
        )
        
        let service = LLMService()
        XCTAssertNoThrow(try service.validateAnalysis(analysis))
    }
    
    func testValidation_AcceptsRealWorldUncertainExample() {
        // Real-world example where verdict is uncertain
        let analysis = GeminiVeganAnalysis(
            verdict: "uncertain",
            confidence: 0.65,
            summary: "This product lists 'natural flavors' and 'mono and diglycerides' which can be derived from either plant or animal sources. Without contacting the manufacturer, it's impossible to confirm with certainty.",
            nonVeganIngredients: [],
            ambiguousIngredients: ["natural flavors", "mono and diglycerides", "vitamin D3"],
            suggestions: [
                "Contact the manufacturer to ask about the source of natural flavors",
                "Check if vitamin D3 is from lichen (vegan) or lanolin (not vegan)",
                "Look for products with clearer ingredient sourcing"
            ],
            productName: "Protein Bar"
        )
        
        let service = LLMService()
        XCTAssertNoThrow(try service.validateAnalysis(analysis))
    }
}

// MARK: - Test Extension

// Make the validation method accessible for testing
extension LLMService {
    func validateAnalysis(_ analysis: GeminiVeganAnalysis) throws {
        // Call the private validation method (we'll need to add @testable import)
        try self.validateAnalysis(analysis)
    }
}
