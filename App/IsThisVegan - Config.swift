// Config.swift
// IsThisVegan
//
// Central configuration for API keys, model settings, and usage limits.
// TODO: Move API key to a backend proxy before App Store release.

import Foundation

enum Config {

    // MARK: - App Group

    /// App Group identifier shared between the main app and the widget extension.
    /// Used for SwiftData container, UserDefaults, and shared file storage.
    static let appGroupIdentifier: String = "group.com.isthisvegan.shared"

    // MARK: - Gemini API

    /// Whether to use the backend proxy (true) or direct API calls (false).
    /// App Store builds should use the proxy to protect the API key.
    /// Development builds can use direct API for easier debugging.
    #if DEBUG
    static let useBackendProxy: Bool = false
    #else
    static let useBackendProxy: Bool = true
    #endif

    /// Backend proxy URL (used when useBackendProxy = true).
    /// Loaded at runtime from Resources/Secrets.plist (gitignored).
    /// See Secrets.plist.example for setup instructions.
    static let backendProxyURL: String = {
        // If not using backend proxy, the URL is not needed
        guard useBackendProxy else { 
            return "https://is-this-vegan-proxy.YOUR_SUBDOMAIN.workers.dev" 
        }
        
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let url = dict["BACKEND_PROXY_URL"] as? String,
              !url.isEmpty,
              url != "https://is-this-vegan-proxy.YOUR_SUBDOMAIN.workers.dev" else {
            fatalError("""
                Missing or invalid BACKEND_PROXY_URL.
                1. Copy Secrets.plist.example → Resources/Secrets.plist
                2. Replace the BACKEND_PROXY_URL placeholder with your actual worker URL
                
                OR disable the proxy by setting useBackendProxy = false
                """)
        }
        return url
    }()

    /// Google Gemini API key (only used in development when useBackendProxy = false).
    /// Loaded at runtime from Resources/Secrets.plist (gitignored).
    /// See Secrets.plist.example for setup instructions.
    static let geminiAPIKey: String? = {
        // If using backend proxy, API key is not needed
        guard !useBackendProxy else { return nil }
        
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key = dict["GEMINI_API_KEY"] as? String,
              !key.isEmpty,
              key != "YOUR_KEY_HERE",
              key != "YOUR_GEMINI_API_KEY_HERE" else {
            fatalError("""
                Missing or invalid GEMINI_API_KEY.
                1. Copy Secrets.plist.example → Resources/Secrets.plist
                2. Replace YOUR_KEY_HERE with your actual API key
                
                OR use the backend proxy by setting useBackendProxy = true
                """)
        }
        return key
    }()

    /// The Gemini model to use for analysis.
    /// "gemini-2.5-flash" is the current stable model (fast + capable).
    /// Note: gemini-2.0-flash is being retired March 31, 2026.
    static let geminiModel: String = "gemini-2.5-flash"

    /// Base URL for the Gemini API (only used when useBackendProxy = false).
    static let geminiBaseURL: String = "https://generativelanguage.googleapis.com/v1beta"

    // MARK: - Usage Limits

    /// Maximum number of API calls allowed per day (0 = unlimited).
    static let dailyAPICallLimit: Int = 50

    /// Maximum number of API calls allowed per month (0 = unlimited).
    static let monthlyAPICallLimit: Int = 1000

    /// Maximum tokens per month before warning the user (0 = unlimited).
    static let monthlyTokenLimit: Int = 500_000

    // MARK: - Analysis Settings

    /// Maximum image dimension (pixels) before resizing for API upload.
    /// Smaller images = fewer tokens = lower cost.
    static let maxImageDimension: CGFloat = 1024

    /// JPEG compression quality for images sent to the API (0.0 - 1.0).
    /// Lower = smaller payload = faster + cheaper, but less detail.
    static let imageCompressionQuality: CGFloat = 0.8

    /// JPEG compression quality for images stored locally in SwiftData (0.0 - 1.0).
    /// Can be lower than the API quality since stored images are only used for history/display.
    static let storedImageCompressionQuality: CGFloat = 0.7

    /// Whether to run Apple Vision OCR before sending to the LLM.
    /// When true, extracted text is sent alongside the image for better accuracy.
    /// When false, the LLM reads the image directly (simpler but uses more tokens).
    static let useOCRPreProcessing: Bool = true
}
