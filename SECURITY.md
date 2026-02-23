# Security Documentation

## Overview

This document outlines the security considerations, vulnerabilities, and best practices for the Is This Vegan? iOS application.

## Security Status

⚠️ **Current Security Level**: Development/Testing Only  
🔒 **Production Ready**: NO - Critical issues must be addressed

---

## 🔴 Critical Security Issues

### 1. Exposed API Key

**Location**: `App/IsThisVegan - Config.swift`

**Issue**: 
- Gemini API key is hardcoded in source code as a string literal
- Currently set to placeholder value, but pattern is dangerous
- If real key committed to version control, it becomes permanently exposed in Git history

**Risk Level**: 🔴 CRITICAL

**Attack Vector**:
- Anyone with repository access can extract API key
- Reverse engineering iOS binary can reveal key
- Git history permanently stores committed keys
- Costs could be incurred by malicious actors

**Current Code**:
```swift
enum Config {
    static let geminiAPIKey = "your-api-key-here" // ⚠️ DO NOT COMMIT REAL KEY
}
```

**Remediation (Choose One)**:

#### Option 1: Backend Proxy (Recommended)
```swift
// App makes request to your backend
let response = try await URLSession.shared.data(from: URL(string: "https://yourapi.com/analyze"))
// Backend stores API key securely and forwards to Gemini
```

**Pros**: Complete key isolation, usage monitoring, rate limiting  
**Cons**: Requires backend infrastructure

#### Option 2: iOS Keychain
```swift
enum Config {
    static var geminiAPIKey: String {
        get throws {
            try KeychainHelper.retrieve(key: "gemini_api_key")
        }
    }
}
```

**Pros**: Encrypted storage on device  
**Cons**: Key still bundled with app, reverse-engineerable

#### Option 3: Environment Variables (Build Time)
```bash
# .env file (gitignored)
GEMINI_API_KEY=actual-key-here
```

```swift
// Read from Info.plist injected during build
let key = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String
```

**Pros**: Not in source code  
**Cons**: Visible in compiled app bundle

**Action Required**: Implement Option 1 before production release

---

### 2. Thread Safety Violation

**Location**: `Services/AnalysisPipeline.swift`

**Issue**:
```swift
final class AnalysisPipeline: @unchecked Sendable {
    func analyze(image: UIImage) async throws -> (VeganVerdict, String, [String]) {
        let ocrService = OCRService()  // ⚠️ New instance on each call
        let database = IngredientDatabase()
        let llmService = LLMService()
        // ... operations without synchronization
    }
}
```

**Risk Level**: 🔴 CRITICAL

**Issue**: 
- Marked `@unchecked Sendable` but creates mutable state without synchronization
- Multiple concurrent calls could race on service initialization
- Swift 6 strict concurrency will flag this as error

**Impact**:
- Race conditions during simultaneous scans
- Undefined behavior with concurrent API calls
- Potential crashes or data corruption

**Remediation**:
```swift
@MainActor
final class AnalysisPipeline {
    private let ocrService: OCRService
    private let database: IngredientDatabase
    private let llmService: LLMService
    
    init() {
        self.ocrService = OCRService()
        self.database = IngredientDatabase()
        self.llmService = LLMService()
    }
    
    func analyze(image: UIImage) async throws -> (VeganVerdict, String, [String]) {
        // Thread-safe: guaranteed to run on main actor
    }
}
```

**Action Required**: Remove `@unchecked Sendable` or implement proper synchronization

---

### 3. Silent Data Persistence Failures

**Location**: `Services/UsageTracker.swift`, `Views/IsThisVegan - HistoryView.swift`

**Issue**:
```swift
do {
    try modelContext.save()
} catch {
    print("Error: \(error)")  // ⚠️ Silent failure
}
```

**Risk Level**: 🟠 HIGH

**Impact**:
- Users believe data is saved but it's not
- No feedback on storage failures (disk full, permission issues)
- Usage tracking silently fails, breaking cost estimates

**Remediation**:
```swift
do {
    try modelContext.save()
} catch {
    // Propagate to UI
    await showErrorAlert("Failed to save scan: \(error.localizedDescription)")
    // Log for diagnostics
    Logger.error("Persistence failed", metadata: ["error": "\(error)"])
}
```

**Action Required**: Implement proper error propagation to UI

---

## 🟡 Moderate Security Issues

### 4. Image Privacy

**Location**: `Models/IsThisVegan - ScanResult.swift`

**Issue**:
- Full-resolution images stored unencrypted in SwiftData
- Images may contain sensitive information (credit cards visible in photo, etc.)
- App Group storage accessible by other apps in group (if any added)

**Risk Level**: 🟡 MODERATE

**Mitigation Options**:
1. **Data Protection**: Enable file encryption via entitlements
2. **Blur Sensitive Regions**: Detect and redact PII before storage
3. **User Consent**: Inform users about image storage
4. **Auto-Delete**: Implement retention policy (30 days)

**Current Protection**: iOS Data Protection API (baseline)

**Recommended**:
```swift
@Model
class ScanResult {
    @Attribute(.externalStorage, .allowsCloudEncryption)
    var imageData: Data?
}
```

---

### 5. Network Request Validation

**Location**: `Services/LLMService.swift`

**Issue**:
- No certificate pinning for API requests
- Vulnerable to man-in-the-middle attacks on compromised networks
- API response validation uses string matching (fragile)

**Risk Level**: 🟡 MODERATE

**Current**:
```swift
if error.localizedDescription.contains("quota") ||
   error.localizedDescription.contains("RESOURCE_EXHAUSTED") {
    throw LLMError.rateLimitExceeded  // ⚠️ String-based detection
}
```

**Recommended**:
```swift
// Certificate pinning
let session = URLSession(
    configuration: .default,
    delegate: CertificatePinner(),
    delegateQueue: nil
)

// Structured error parsing
guard let errorCode = httpResponse.value(forHTTPHeaderField: "X-Error-Code") else {
    // Parse actual error structure from API
}
```

---

### 6. Input Sanitization

**Location**: `Views/IsThisVegan - ResultView.swift`

**Issue**:
- Share functionality includes OCR text without sanitization
- Could leak sensitive data if user accidentally shares
- No content policy enforcement

**Risk Level**: 🟡 MODERATE

**Current**:
```swift
let shareText = """
Is This Vegan? Result
Verdict: \(result.verdict.rawValue)
\(result.reasoning)
"""
// ⚠️ Could contain PII from OCR
```

**Recommended**:
```swift
let shareText = """
Is This Vegan? Result
Verdict: \(result.verdict.description)
Analysis: \(sanitize(result.reasoning))
"""

func sanitize(_ text: String) -> String {
    // Remove potential PII (emails, phone numbers, etc.)
}
```

---

## 🔵 Low Risk Issues

### 7. No Rate Limiting Enforcement

**Issue**: Client-side rate limiting can be bypassed

**Mitigation**: Move to backend proxy with server-side rate limiting

### 8. Logging Sensitive Data

**Issue**: `print()` statements may log sensitive data to console

**Mitigation**: Implement structured logging with automatic PII redaction

### 9. App Group Data Exposure

**Issue**: Any app added to `group.com.isthisvegan.shared` can read scan history

**Mitigation**: Minimize App Group membership, document security boundary

---

## Security Best Practices

### API Security

- ✅ Use HTTPS for all network requests
- ❌ No certificate pinning (consider for production)
- ❌ API key in source code (must fix)
- ✅ Request timeouts configured (30s)
- ⚠️ Error handling reveals rate limit details (info disclosure)

### Data Security

- ✅ SwiftData encryption at rest (iOS default)
- ⚠️ Images stored without additional encryption
- ❌ No data retention policy
- ✅ App Sandbox isolation
- ⚠️ App Group shared container (controlled exposure)

### Authentication & Authorization

- N/A - No user accounts
- N/A - No server-side authentication
- ✅ Camera/photo library permissions requested
- ⚠️ No explicit permission denied handling

### Code Security

- ❌ No code obfuscation
- ✅ Swift type safety prevents many vulnerabilities
- ⚠️ Some force unwraps could cause crashes
- ⚠️ Thread safety issues (see Critical Issues)

---

## Privacy Compliance

### Data Collection

**What data is collected**:
- Product images (stored locally)
- OCR-extracted text
- Scan timestamps
- API usage statistics

**What data is sent externally**:
- Images sent to Google Gemini API
- API requests with image data

**User Rights**:
- ✅ Data stored locally (user owns device)
- ⚠️ No explicit data deletion UI (manual app removal)
- ❌ No data export functionality

### GDPR/CCPA Compliance Checklist

- [ ] Privacy policy published
- [ ] User consent for data processing
- [ ] Data export functionality
- [ ] Data deletion functionality
- [ ] Third-party data sharing disclosure (Gemini API)
- [ ] Data breach notification process

---

## Incident Response Plan

### If API Key Compromised

1. **Immediately**: Revoke key in Google Cloud Console
2. **Generate**: New API key with restricted permissions
3. **Rotate**: Update all production deployments
4. **Monitor**: Check API usage for suspicious activity
5. **Notify**: Users to update app (if necessary)

### If Vulnerability Discovered

1. **Assess**: Severity and exploitability
2. **Patch**: Develop and test fix
3. **Release**: Emergency update via TestFlight/App Store
4. **Disclose**: Responsible disclosure (if public)
5. **Document**: Post-mortem and prevention

---

## Security Testing Checklist

### Before Production Release

- [ ] Static analysis (SwiftLint security rules)
- [ ] Dependency vulnerability scan
- [ ] Code review for sensitive operations
- [ ] API key rotation verified
- [ ] Certificate pinning implemented (if needed)
- [ ] Error handling audit (no silent failures)
- [ ] Thread safety validation (Swift 6 mode)
- [ ] Penetration testing (optional)

### Continuous Monitoring

- [ ] API usage monitoring for anomalies
- [ ] Crash reporting for security-related crashes
- [ ] App Store review compliance
- [ ] Quarterly dependency updates

---

## Secure Development Lifecycle

### Code Review Requirements

All PRs must verify:
1. No hardcoded secrets (API keys, passwords)
2. Proper error handling (no silent failures)
3. Input validation on external data
4. Thread-safe concurrent access
5. Secure data storage patterns

### Pre-commit Hooks

Recommended:
```bash
#!/bin/bash
# Check for exposed secrets
if git diff --cached | grep -i "api.*key.*="; then
    echo "⚠️  Potential API key in commit"
    exit 1
fi
```

### CI/CD Security

- Run static analysis on every commit
- Automated security scanning (Snyk, Dependabot)
- Fail builds on high/critical vulnerabilities
- Signed builds for production

---

## Security Contact

**Reporting Vulnerabilities**: 
Please report security issues to [security contact - TO BE ADDED]

**Response SLA**:
- Critical: 24 hours
- High: 72 hours  
- Medium/Low: 1 week

**Responsible Disclosure Policy**: [TO BE CREATED]

---

## Appendix: Security Tools

### Recommended Tools

1. **SwiftLint**: Code quality and security rules
2. **Xcode Static Analyzer**: Built-in security checks
3. **Hopper/Ghidra**: Binary analysis (test reverse engineering resistance)
4. **MobSF**: Mobile security testing
5. **OWASP ZAP**: API security testing

### Running Security Scans

```bash
# SwiftLint security rules
swiftlint lint --strict --config .swiftlint.yml

# Xcode static analysis
xcodebuild analyze -project IsThisVegan.xcodeproj -scheme IsThisVegan
```

---

**Document Version**: 1.0  
**Last Updated**: 2026-02-12  
**Next Review**: 2026-05-12  
**Classification**: Internal Use
