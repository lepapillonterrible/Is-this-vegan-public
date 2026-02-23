// ErrorHandlingTests.swift
// IsThisVeganTests
//
// Tests for error handling, categorization, and retry logic.

import XCTest
@testable import IsThisVegan

final class ErrorHandlingTests: XCTestCase {
    
    // MARK: - Error Categorization Tests
    
    func testLLMError_RateLimitExceeded_IsCategorizedCorrectly() {
        // Given: A rate limit exceeded error
        let error = LLMError.rateLimitExceeded
        
        // When: We analyze the error
        let context = ErrorAnalyzer.analyze(error)
        
        // Then: It should be categorized as user-actionable and not retryable
        XCTAssertEqual(context.category, .userActionable)
        XCTAssertFalse(context.isRetryable)
        XCTAssertNotNil(context.suggestedAction)
    }
    
    func testLLMError_InvalidResponse_IsCategorizedCorrectly() {
        // Given: An invalid response error
        let error = LLMError.invalidResponse
        
        // When: We analyze the error
        let context = ErrorAnalyzer.analyze(error)
        
        // Then: It should be transient and retryable
        XCTAssertEqual(context.category, .transient)
        XCTAssertTrue(context.isRetryable)
    }
    
    func testLLMError_ConfigurationError_IsCategorizedCorrectly() {
        // Given: A configuration error
        let error = LLMError.configurationError("API key missing")
        
        // When: We analyze the error
        let context = ErrorAnalyzer.analyze(error)
        
        // Then: It should be permanent and not retryable
        XCTAssertEqual(context.category, .permanent)
        XCTAssertFalse(context.isRetryable)
    }
    
    func testNetworkError_Timeout_IsCategorizedCorrectly() {
        // Given: A network timeout error
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: nil
        )
        
        // When: We analyze the error
        let context = ErrorAnalyzer.analyze(error)
        
        // Then: It should be transient and retryable
        XCTAssertEqual(context.category, .transient)
        XCTAssertTrue(context.isRetryable)
        XCTAssertTrue(context.userMessage.localizedCaseInsensitiveContains("timeout"))
    }
    
    func testNetworkError_NoInternet_IsCategorizedCorrectly() {
        // Given: A no internet connection error
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )
        
        // When: We analyze the error
        let context = ErrorAnalyzer.analyze(error)
        
        // Then: It should be transient and retryable with helpful message
        XCTAssertEqual(context.category, .transient)
        XCTAssertTrue(context.isRetryable)
        XCTAssertTrue(context.userMessage.localizedCaseInsensitiveContains("internet"))
        XCTAssertTrue(context.suggestedAction?.localizedCaseInsensitiveContains("offline") ?? false)
    }
    
    func testAPIError_500_IsCategorizedCorrectly() {
        // Given: A 500 server error
        let error = LLMError.apiError(statusCode: 500, message: "Internal Server Error")
        
        // When: We analyze the error
        let context = ErrorAnalyzer.analyze(error)
        
        // Then: It should be transient and retryable
        XCTAssertEqual(context.category, .transient)
        XCTAssertTrue(context.isRetryable)
    }
    
    func testAPIError_400_IsCategorizedCorrectly() {
        // Given: A 400 bad request error
        let error = LLMError.apiError(statusCode: 400, message: "Bad Request")
        
        // When: We analyze the error
        let context = ErrorAnalyzer.analyze(error)
        
        // Then: It should be permanent and not retryable
        XCTAssertEqual(context.category, .permanent)
        XCTAssertFalse(context.isRetryable)
    }
    
    func testAPIError_429_IsCategorizedCorrectly() {
        // Given: A 429 rate limit error
        let error = LLMError.apiError(statusCode: 429, message: "Too Many Requests")
        
        // When: We analyze the error
        let context = ErrorAnalyzer.analyze(error)
        
        // Then: It should be user-actionable and not retryable
        XCTAssertEqual(context.category, .userActionable)
        XCTAssertFalse(context.isRetryable)
    }
    
    // MARK: - Persistence Error Tests
    
    func testPersistenceError_SaveFailed_HasRecoverySuggestion() {
        // Given: A save failed error
        let underlyingError = NSError(domain: "TestDomain", code: 1, userInfo: nil)
        let error = PersistenceError.saveFailed(underlyingError: underlyingError)
        
        // Then: It should have an error description and recovery suggestion
        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.errorDescription?.contains("save") ?? false)
    }
    
    func testPersistenceError_ContextNotAvailable_HasHelpfulMessage() {
        // Given: A context not available error
        let error = PersistenceError.contextNotAvailable
        
        // Then: It should have a helpful message
        XCTAssertTrue(error.errorDescription?.localizedCaseInsensitiveContains("database") ?? false)
        XCTAssertTrue(error.recoverySuggestion?.localizedCaseInsensitiveContains("restart") ?? false)
    }
    
    // MARK: - Retry Logic Tests
    
    func testRetry_SucceedsOnSecondAttempt() async throws {
        // Given: An operation that fails once then succeeds
        var attemptCount = 0
        let operation = {
            attemptCount += 1
            if attemptCount == 1 {
                throw LLMError.invalidResponse
            }
            return "Success"
        }
        
        // When: We retry with a fast config
        let config = RetryConfig(
            maxAttempts: 3,
            initialDelay: 0.01,
            backoffMultiplier: 1.0,
            maxDelay: 0.01
        )
        let result = try await withRetry(config: config, operation: operation)
        
        // Then: It should succeed after 2 attempts
        XCTAssertEqual(result, "Success")
        XCTAssertEqual(attemptCount, 2)
    }
    
    func testRetry_FailsWithPermanentError() async {
        // Given: An operation that always fails with a permanent error
        let operation = {
            throw LLMError.configurationError("API key missing")
        }
        
        // When: We try to retry
        let config = RetryConfig(
            maxAttempts: 3,
            initialDelay: 0.01,
            backoffMultiplier: 1.0,
            maxDelay: 0.01
        )
        
        // Then: It should fail immediately without retries
        do {
            let _ = try await withRetry(config: config, operation: operation)
            XCTFail("Should have thrown an error")
        } catch {
            // Should fail fast with permanent errors
            XCTAssertTrue(error is LLMError)
        }
    }
    
    func testRetry_ExhaustsAllAttempts() async {
        // Given: An operation that always fails with a transient error
        var attemptCount = 0
        let operation = {
            attemptCount += 1
            throw LLMError.invalidResponse
        }
        
        // When: We retry with limited attempts
        let config = RetryConfig(
            maxAttempts: 3,
            initialDelay: 0.01,
            backoffMultiplier: 1.0,
            maxDelay: 0.01
        )
        
        // Then: It should try exactly 3 times then fail
        do {
            let _ = try await withRetry(config: config, operation: operation)
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertEqual(attemptCount, 3)
        }
    }
    
    func testRetry_ExponentialBackoff() async {
        // Given: An operation that fails multiple times
        var attemptTimes: [Date] = []
        let operation = {
            attemptTimes.append(Date())
            throw LLMError.invalidResponse
        }
        
        // When: We retry with exponential backoff
        let config = RetryConfig(
            maxAttempts: 3,
            initialDelay: 0.1,
            backoffMultiplier: 2.0,
            maxDelay: 1.0
        )
        
        do {
            let _ = try await withRetry(config: config, operation: operation)
        } catch {
            // Expected to fail
        }
        
        // Then: Delays should approximately double each time
        XCTAssertEqual(attemptTimes.count, 3)
        
        if attemptTimes.count >= 2 {
            let delay1 = attemptTimes[1].timeIntervalSince(attemptTimes[0])
            // First delay should be ~0.1s (with some tolerance)
            XCTAssertGreaterThanOrEqual(delay1, 0.09)
            XCTAssertLessThanOrEqual(delay1, 0.2)
        }
        
        if attemptTimes.count >= 3 {
            let delay2 = attemptTimes[2].timeIntervalSince(attemptTimes[1])
            // Second delay should be ~0.2s (2x first delay)
            XCTAssertGreaterThanOrEqual(delay2, 0.15)
            XCTAssertLessThanOrEqual(delay2, 0.3)
        }
    }
    
    // MARK: - Error Message Quality Tests
    
    func testErrorAnalyzer_ProvidesUserFriendlyMessages() {
        // Test that error messages are user-friendly, not technical
        let testCases: [(Error, String)] = [
            (LLMError.rateLimitExceeded, "limit"),
            (LLMError.invalidResponse, "invalid response"),
            (NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil), "internet"),
        ]
        
        for (error, expectedKeyword) in testCases {
            let context = ErrorAnalyzer.analyze(error)
            XCTAssertTrue(
                context.userMessage.localizedCaseInsensitiveContains(expectedKeyword),
                "User message '\(context.userMessage)' should contain '\(expectedKeyword)'"
            )
        }
    }
    
    func testErrorAnalyzer_ProvidesSuggestedActions() {
        // Test that user-actionable errors have suggested actions
        let actionableErrors: [Error] = [
            LLMError.rateLimitExceeded,
            PersistenceError.contextNotAvailable,
            NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        ]
        
        for error in actionableErrors {
            let context = ErrorAnalyzer.analyze(error)
            XCTAssertNotNil(context.suggestedAction, "Error should have a suggested action: \(error)")
        }
    }
}
