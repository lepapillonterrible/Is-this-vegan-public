// ErrorHandling.swift
// IsThisVegan
//
// Centralized error handling with retry logic, error categorization,
// and user-friendly messaging.

import Foundation

// MARK: - Error Categories

/// Categorizes errors to determine appropriate handling strategy.
enum ErrorCategory {
    /// Temporary failures that may succeed on retry (network glitches, timeouts).
    case transient
    
    /// Permanent failures that won't succeed on retry (invalid API key, malformed request).
    case permanent
    
    /// User-actionable errors (permission denied, rate limit).
    case userActionable
    
    /// Unknown or unexpected errors.
    case unknown
}

/// Extended error information for better handling and debugging.
struct ErrorContext {
    /// The original error.
    let error: Error
    
    /// Error category for determining retry strategy.
    let category: ErrorCategory
    
    /// User-friendly message suitable for display in UI.
    let userMessage: String
    
    /// Whether this error can be retried.
    let isRetryable: Bool
    
    /// Technical details for logging (not shown to users).
    let technicalDetails: String
    
    /// Suggested action for the user (optional).
    let suggestedAction: String?
}

// MARK: - Error Analyzer

/// Analyzes errors and provides context for handling.
struct ErrorAnalyzer {
    
    /// Analyze an error and return enriched context.
    static func analyze(_ error: Error) -> ErrorContext {
        // Check for specific error types
        if let llmError = error as? LLMError {
            return analyzeLLMError(llmError)
        }
        
        if let pipelineError = error as? PipelineError {
            return analyzePipelineError(pipelineError)
        }
        
        // Check for common system errors
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return analyzeNetworkError(nsError)
        }
        
        // Fallback to generic analysis
        return ErrorContext(
            error: error,
            category: .unknown,
            userMessage: "An unexpected error occurred: \(error.localizedDescription)",
            isRetryable: false,
            technicalDetails: "\(error)",
            suggestedAction: "Please try again or contact support if the issue persists."
        )
    }
    
    // MARK: - Specific Error Analysis
    
    /// Analyze LLM service errors.
    private static func analyzeLLMError(_ error: LLMError) -> ErrorContext {
        switch error {
        case .imageProcessingFailed:
            return ErrorContext(
                error: error,
                category: .permanent,
                userMessage: "Failed to process the image",
                isRetryable: false,
                technicalDetails: "Image compression or encoding failed",
                suggestedAction: "Try a different image or reduce image quality"
            )
            
        case .invalidResponse:
            return ErrorContext(
                error: error,
                category: .transient,
                userMessage: "Received an invalid response from the AI",
                isRetryable: true,
                technicalDetails: "Malformed HTTP response or missing data",
                suggestedAction: "This is usually temporary. Please try again."
            )
            
        case .emptyResponse:
            return ErrorContext(
                error: error,
                category: .transient,
                userMessage: "The AI returned an empty response",
                isRetryable: true,
                technicalDetails: "API returned 200 but with no content",
                suggestedAction: "Try again with a clearer photo"
            )
            
        case .apiError(let code, let message):
            return analyzeAPIError(code: code, message: message)
            
        case .invalidJSON(let raw):
            return ErrorContext(
                error: error,
                category: .transient,
                userMessage: "Failed to understand the AI's response",
                isRetryable: true,
                technicalDetails: "JSON parse error. Raw: \(raw.prefix(100))",
                suggestedAction: "This is usually temporary. Try again."
            )
            
        case .rateLimitExceeded:
            return ErrorContext(
                error: error,
                category: .userActionable,
                userMessage: "Daily scan limit reached",
                isRetryable: false,
                technicalDetails: "API rate limit or quota exceeded",
                suggestedAction: "Try again tomorrow or enable offline mode for basic scanning"
            )
            
        case .configurationError(let message):
            return ErrorContext(
                error: error,
                category: .permanent,
                userMessage: "Configuration error",
                isRetryable: false,
                technicalDetails: message,
                suggestedAction: "Please contact support"
            )
            
        case .invalidAnalysis(let reason):
            return ErrorContext(
                error: error,
                category: .transient,
                userMessage: "The AI returned an invalid response",
                isRetryable: true,
                technicalDetails: "Validation failed: \(reason)",
                suggestedAction: "Please try again with a clearer photo"
            )
        }
    }
    
    /// Analyze API HTTP error codes.
    private static func analyzeAPIError(code: Int, message: String) -> ErrorContext {
        switch code {
        case 400:
            return ErrorContext(
                error: LLMError.apiError(statusCode: code, message: message),
                category: .permanent,
                userMessage: "Invalid request",
                isRetryable: false,
                technicalDetails: "HTTP 400: \(message)",
                suggestedAction: "This image may be unsupported. Try a different one."
            )
            
        case 401, 403:
            return ErrorContext(
                error: LLMError.apiError(statusCode: code, message: message),
                category: .permanent,
                userMessage: "Authentication failed",
                isRetryable: false,
                technicalDetails: "HTTP \(code): \(message)",
                suggestedAction: "Please contact support"
            )
            
        case 429:
            return ErrorContext(
                error: LLMError.apiError(statusCode: code, message: message),
                category: .userActionable,
                userMessage: "Too many requests",
                isRetryable: false,
                technicalDetails: "HTTP 429: Rate limit exceeded",
                suggestedAction: "Please try again in a few minutes"
            )
            
        case 500...599:
            return ErrorContext(
                error: LLMError.apiError(statusCode: code, message: message),
                category: .transient,
                userMessage: "Server error",
                isRetryable: true,
                technicalDetails: "HTTP \(code): \(message)",
                suggestedAction: "The AI service is experiencing issues. Please try again."
            )
            
        default:
            return ErrorContext(
                error: LLMError.apiError(statusCode: code, message: message),
                category: .unknown,
                userMessage: "API error (\(code))",
                isRetryable: code >= 500,
                technicalDetails: "HTTP \(code): \(message)",
                suggestedAction: "Please try again"
            )
        }
    }
    
    /// Analyze pipeline-specific errors.
    private static func analyzePipelineError(_ error: PipelineError) -> ErrorContext {
        switch error {
        case .noTextDetected:
            return ErrorContext(
                error: error,
                category: .userActionable,
                userMessage: "No text found in the image",
                isRetryable: false,
                technicalDetails: "OCR found no recognizable text",
                suggestedAction: "Try a clearer photo of the ingredient list or product label"
            )
            
        case .rateLimitReached(let message):
            return ErrorContext(
                error: error,
                category: .userActionable,
                userMessage: message,
                isRetryable: false,
                technicalDetails: "Usage quota exceeded",
                suggestedAction: "Enable offline mode or try again tomorrow"
            )
            
        case .analysisFailedWithFallback(_, let llmError):
            let llmContext = analyze(llmError)
            return ErrorContext(
                error: error,
                category: llmContext.category,
                userMessage: "Using offline results only",
                isRetryable: llmContext.isRetryable,
                technicalDetails: "LLM failed: \(llmContext.technicalDetails)",
                suggestedAction: "Showing local database results. Online analysis unavailable."
            )
        }
    }
    
    /// Analyze network errors.
    private static func analyzeNetworkError(_ error: NSError) -> ErrorContext {
        switch error.code {
        case NSURLErrorNotConnectedToInternet,
             NSURLErrorNetworkConnectionLost:
            return ErrorContext(
                error: error,
                category: .transient,
                userMessage: "No internet connection",
                isRetryable: true,
                technicalDetails: "Network unreachable: \(error.localizedDescription)",
                suggestedAction: "Check your connection or enable offline mode"
            )
            
        case NSURLErrorTimedOut:
            return ErrorContext(
                error: error,
                category: .transient,
                userMessage: "Request timed out",
                isRetryable: true,
                technicalDetails: "Timeout after 30s",
                suggestedAction: "Check your connection and try again"
            )
            
        case NSURLErrorCannotFindHost,
             NSURLErrorCannotConnectToHost:
            return ErrorContext(
                error: error,
                category: .transient,
                userMessage: "Cannot reach server",
                isRetryable: true,
                technicalDetails: "DNS or connection failure",
                suggestedAction: "Check your internet connection"
            )
            
        case NSURLErrorServerCertificateUntrusted,
             NSURLErrorSecureConnectionFailed:
            return ErrorContext(
                error: error,
                category: .permanent,
                userMessage: "Security error",
                isRetryable: false,
                technicalDetails: "SSL/TLS verification failed",
                suggestedAction: "Please contact support"
            )
            
        default:
            return ErrorContext(
                error: error,
                category: .transient,
                userMessage: "Network error",
                isRetryable: true,
                technicalDetails: "URLError code \(error.code): \(error.localizedDescription)",
                suggestedAction: "Please check your connection and try again"
            )
        }
    }
}

// MARK: - Retry Logic

/// Retry configuration for transient failures.
struct RetryConfig {
    /// Maximum number of retry attempts.
    let maxAttempts: Int
    
    /// Initial delay in seconds.
    let initialDelay: TimeInterval
    
    /// Multiplier for exponential backoff.
    let backoffMultiplier: Double
    
    /// Maximum delay between retries (caps exponential growth).
    let maxDelay: TimeInterval
    
    /// Default retry configuration (3 attempts with exponential backoff).
    static let `default` = RetryConfig(
        maxAttempts: 3,
        initialDelay: 1.0,
        backoffMultiplier: 2.0,
        maxDelay: 10.0
    )
    
    /// Aggressive retry for critical operations.
    static let aggressive = RetryConfig(
        maxAttempts: 5,
        initialDelay: 0.5,
        backoffMultiplier: 1.5,
        maxDelay: 5.0
    )
    
    /// Single retry only.
    static let once = RetryConfig(
        maxAttempts: 2,
        initialDelay: 2.0,
        backoffMultiplier: 1.0,
        maxDelay: 2.0
    )
}

/// Retry an async operation with exponential backoff.
///
/// - Parameters:
///   - config: Retry configuration (attempts, delays, etc.)
///   - operation: The async operation to retry
/// - Returns: The result of the operation if successful
/// - Throws: The last error if all retries fail
func withRetry<T>(
    config: RetryConfig = .default,
    operation: @escaping () async throws -> T
) async throws -> T {
    var lastError: Error?
    
    for attempt in 1...config.maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            
            // Analyze the error to see if we should retry
            let context = ErrorAnalyzer.analyze(error)
            
            // Don't retry permanent or user-actionable errors
            if !context.isRetryable {
                throw error
            }
            
            // Don't delay after the last attempt
            if attempt < config.maxAttempts {
                // Calculate delay with exponential backoff
                let delay = min(
                    config.initialDelay * pow(config.backoffMultiplier, Double(attempt - 1)),
                    config.maxDelay
                )
                
                print("[Retry] Attempt \(attempt) failed: \(context.technicalDetails). Retrying in \(delay)s...")
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
    
    // All retries exhausted
    throw lastError ?? NSError(
        domain: "RetryError",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Operation failed after \(config.maxAttempts) attempts"]
    )
}

// MARK: - Persistence Error Handling

/// Errors that can occur during data persistence.
enum PersistenceError: LocalizedError {
    case saveFailed(underlyingError: Error)
    case deleteFailed(underlyingError: Error)
    case contextNotAvailable
    case dataCorrupted
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete data: \(error.localizedDescription)"
        case .contextNotAvailable:
            return "Database not available"
        case .dataCorrupted:
            return "Data is corrupted and cannot be saved"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .saveFailed, .deleteFailed:
            return "Your scan was completed but couldn't be saved to history. You can still see the results."
        case .contextNotAvailable:
            return "Please restart the app and try again."
        case .dataCorrupted:
            return "This scan result appears to be invalid. Please scan again."
        }
    }
}
