# API Integration Documentation

## Overview

Is This Vegan? integrates with the Google Gemini AI API for advanced ingredient analysis. This document covers API integration details, request/response formats, error handling, and cost management.

---

## API Provider

**Service**: Google Gemini AI  
**Model**: `gemini-2.0-flash-exp`  
**Endpoint**: `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`  
**Documentation**: https://ai.google.dev/docs

---

## Authentication

### API Key Setup

**Location**: `App/IsThisVegan - Config.swift`

```swift
enum Config {
    static let geminiAPIKey = "YOUR_API_KEY_HERE"
}
```

⚠️ **Security Warning**: See [SECURITY.md](SECURITY.md) for proper API key management in production.

### Obtaining an API Key

1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Click "Create API Key"
4. Copy the generated key
5. Update `Config.swift` (DO NOT commit)

### Rate Limits

**Default Quotas**:
- Free Tier: 60 requests per minute
- Paid Tier: Custom limits

**Application Limits** (configurable in `Config.swift`):
- Daily: 50 API calls
- Monthly: 1,000 API calls

---

## Request Format

### HTTP Method
`POST`

### Headers
```http
Content-Type: application/json
```

### Request Structure

```json
{
  "contents": [
    {
      "parts": [
        {
          "text": "Analyze this product label image. Is it vegan? List all ingredients..."
        },
        {
          "inline_data": {
            "mime_type": "image/jpeg",
            "data": "<base64_encoded_image>"
          }
        }
      ]
    }
  ],
  "generationConfig": {
    "temperature": 0.1,
    "topK": 32,
    "topP": 1,
    "maxOutputTokens": 1000,
    "responseMimeType": "application/json",
    "responseSchema": {
      "type": "object",
      "properties": {
        "verdict": {
          "type": "string",
          "enum": ["vegan", "not_vegan", "uncertain"]
        },
        "reasoning": {
          "type": "string"
        },
        "ingredients": {
          "type": "array",
          "items": { "type": "string" }
        },
        "confidence": {
          "type": "string",
          "enum": ["high", "medium", "low"]
        }
      },
      "required": ["verdict", "reasoning", "ingredients", "confidence"]
    }
  }
}
```

### Prompt Template

**Location**: `Services/LLMService.swift`

```swift
private let systemPrompt = """
Analyze this product label image. Is it vegan?

Instructions:
1. List ALL visible ingredients
2. Identify non-vegan ingredients (dairy, eggs, meat, fish, gelatin, honey, etc.)
3. Mark uncertain ingredients
4. Provide verdict: vegan / not_vegan / uncertain

Response format (JSON):
{
  "verdict": "vegan|not_vegan|uncertain",
  "reasoning": "Brief explanation",
  "ingredients": ["ingredient1", "ingredient2", ...],
  "confidence": "high|medium|low"
}

Be strict: if uncertain, mark as "uncertain" not "vegan".
"""
```

### Image Preprocessing

Before sending to API, images are optimized:

```swift
func resizeImage(_ image: UIImage, maxDimension: CGFloat = 1024) -> UIImage {
    // Calculate scaling to fit within maxDimension
    let scale = maxDimension / max(image.size.width, image.size.height)
    let newSize = CGSize(
        width: image.size.width * scale,
        height: image.size.height * scale
    )
    
    // Render resized image
    let renderer = UIGraphicsImageRenderer(size: newSize)
    return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: newSize))
    }
}
```

**Compression**: JPEG quality 0.7 (balances size vs. quality)

---

## Response Format

### Success Response

**HTTP Status**: `200 OK`

**Body**:
```json
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "{\"verdict\":\"not_vegan\",\"reasoning\":\"Contains milk powder (dairy product)\",\"ingredients\":[\"wheat flour\",\"sugar\",\"milk powder\",\"salt\"],\"confidence\":\"high\"}"
          }
        ]
      },
      "finishReason": "STOP",
      "safetyRatings": [...]
    }
  ],
  "usageMetadata": {
    "promptTokenCount": 245,
    "candidatesTokenCount": 87,
    "totalTokenCount": 332
  }
}
```

### Response Model

**Swift Structure**:

```swift
struct GeminiResponse: Codable {
    let candidates: [Candidate]
    let usageMetadata: UsageMetadata?
    
    struct Candidate: Codable {
        let content: Content
        let finishReason: String
    }
    
    struct Content: Codable {
        let parts: [Part]
    }
    
    struct Part: Codable {
        let text: String
    }
    
    struct UsageMetadata: Codable {
        let promptTokenCount: Int
        let candidatesTokenCount: Int
        let totalTokenCount: Int
    }
}

struct GeminiVeganAnalysis: Codable {
    let verdict: String
    let reasoning: String
    let ingredients: [String]
    let confidence: String
}
```

### Parsing Logic

```swift
func parseAnalysis(from response: GeminiResponse) throws -> GeminiVeganAnalysis {
    guard let firstCandidate = response.candidates.first,
          let text = firstCandidate.content.parts.first?.text else {
        throw LLMError.invalidResponse
    }
    
    // Remove markdown code blocks if present
    let jsonText = text
        .replacingOccurrences(of: "```json\n", with: "")
        .replacingOccurrences(of: "```", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    
    let decoder = JSONDecoder()
    return try decoder.decode(GeminiVeganAnalysis.self, from: jsonText.data(using: .utf8)!)
}
```

---

## Error Handling

### Error Types

```swift
enum LLMError: LocalizedError {
    case invalidAPIKey
    case rateLimitExceeded
    case networkError(Error)
    case invalidResponse
    case imageProcessingFailed
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key. Please check your configuration."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Received invalid response from API."
        case .imageProcessingFailed:
            return "Failed to process image for analysis."
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}
```

### HTTP Status Codes

| Code | Meaning | Handling |
|------|---------|----------|
| `200` | Success | Parse response |
| `400` | Bad Request | Invalid request format, check payload |
| `401` | Unauthorized | Invalid API key |
| `403` | Forbidden | API key lacks permissions |
| `429` | Too Many Requests | Rate limit exceeded, back off |
| `500` | Server Error | Retry with exponential backoff |
| `503` | Service Unavailable | Temporary outage, retry later |

### Error Detection

```swift
func handleAPIError(response: HTTPURLResponse, data: Data) throws {
    guard (200...299).contains(response.statusCode) else {
        // Parse error response
        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            throw LLMError.apiError(errorResponse.error.message)
        }
        
        // Status-specific handling
        switch response.statusCode {
        case 401:
            throw LLMError.invalidAPIKey
        case 429:
            throw LLMError.rateLimitExceeded
        default:
            throw LLMError.apiError("HTTP \(response.statusCode)")
        }
    }
}
```

### Retry Strategy

**Current Implementation**: No automatic retries

**Recommended**:
```swift
func analyzeWithRetry(image: UIImage, maxRetries: Int = 3) async throws -> GeminiVeganAnalysis {
    var lastError: Error?
    
    for attempt in 1...maxRetries {
        do {
            return try await analyze(image: image)
        } catch LLMError.rateLimitExceeded {
            // Exponential backoff: 2^attempt seconds
            let delay = pow(2.0, Double(attempt))
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            lastError = LLMError.rateLimitExceeded
        } catch {
            throw error  // Non-retryable error
        }
    }
    
    throw lastError ?? LLMError.networkError(URLError(.unknown))
}
```

---

## Cost Management

### Pricing Model

**Gemini API Pricing** (as of 2024):
- Free tier: Limited requests per minute
- Pay-as-you-go: Based on token usage

**Estimated Costs**:
- Input: ~245 tokens per request (prompt + image metadata)
- Output: ~50-150 tokens per response
- Total: ~300-400 tokens per scan

### Cost Estimation

**Location**: `Services/UsageTracker.swift`

```swift
func estimateCost(for tokenCount: Int) -> Double {
    // Gemini 2.0 Flash pricing (example)
    let inputCostPerToken = 0.000001  // $0.001 per 1K tokens
    let outputCostPerToken = 0.000002
    
    let estimatedInputTokens = Double(tokenCount) * 0.7
    let estimatedOutputTokens = Double(tokenCount) * 0.3
    
    return (estimatedInputTokens * inputCostPerToken) + 
           (estimatedOutputTokens * outputCostPerToken)
}
```

### Usage Tracking

```swift
struct UsageRecord: Codable {
    let timestamp: Date
    let apiCalls: Int
    let tokensUsed: Int
    let estimatedCost: Double
}

func recordUsage(tokens: Int) {
    let record = UsageRecord(
        timestamp: Date(),
        apiCalls: 1,
        tokensUsed: tokens,
        estimatedCost: estimateCost(for: tokens)
    )
    // Save to UserDefaults or SwiftData
}
```

### Rate Limiting

**Implementation**: Client-side enforcement

```swift
func canMakeAPICall() async -> Bool {
    let today = Calendar.current.startOfDay(for: Date())
    let dailyCount = await getDailyUsage(since: today)
    
    guard dailyCount < Config.dailyAPICallLimit else {
        return false
    }
    
    let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    let monthlyCount = await getMonthlyUsage(since: monthStart)
    
    return monthlyCount < Config.monthlyAPICallLimit
}
```

---

## Performance Optimization

### Image Optimization

**Current**: Resize to 1024x1024 max, JPEG quality 0.7

**Impact**:
- Original 4K image: ~8MB
- Optimized image: ~200KB (97.5% reduction)
- API upload time: <1 second vs. 10+ seconds

### Request Timeout

```swift
var request = URLRequest(url: url)
request.timeoutInterval = 30  // 30 seconds
```

**Considerations**:
- Average response time: 2-5 seconds
- 95th percentile: <10 seconds
- Timeout at 30 seconds prevents hanging

### Caching Strategy

**Current**: No response caching

**Future Enhancement**:
```swift
// Cache identical image analyses
struct CacheKey: Hashable {
    let imageHash: String  // SHA256 of image data
}

var responseCache: [CacheKey: GeminiVeganAnalysis] = [:]
```

**Benefits**:
- Instant results for duplicate scans
- Reduced API costs
- Works offline for cached items

---

## Testing

### Mock API Responses

```swift
class MockLLMService: LLMService {
    override func analyze(image: UIImage) async throws -> GeminiVeganAnalysis {
        return GeminiVeganAnalysis(
            verdict: "vegan",
            reasoning: "All ingredients are plant-based",
            ingredients: ["flour", "water", "salt"],
            confidence: "high"
        )
    }
}
```

### Test Cases

1. **Successful Analysis**
   - Input: Product label image
   - Expected: Valid JSON response with verdict

2. **Rate Limit**
   - Simulate 429 response
   - Verify error handling and user feedback

3. **Network Error**
   - Disconnect network
   - Verify graceful degradation

4. **Invalid Response**
   - Mock malformed JSON
   - Verify error recovery

5. **Large Image**
   - 10MB+ image
   - Verify resizing and upload

### Example Test

```swift
func testGeminiAPIIntegration() async throws {
    let service = LLMService()
    let testImage = UIImage(named: "vegan-label-test")!
    
    let analysis = try await service.analyze(image: testImage)
    
    XCTAssertTrue(["vegan", "not_vegan", "uncertain"].contains(analysis.verdict))
    XCTAssertFalse(analysis.reasoning.isEmpty)
    XCTAssertGreaterThan(analysis.ingredients.count, 0)
}
```

---

## Monitoring

### Metrics to Track

1. **API Usage**
   - Requests per day/month
   - Token consumption
   - Cost tracking

2. **Performance**
   - Response time (p50, p95, p99)
   - Success rate
   - Error rate by type

3. **Quality**
   - Verdict accuracy (user feedback)
   - Confidence level distribution
   - Ingredients detected count

### Logging

```swift
func logAPICall(duration: TimeInterval, tokens: Int, success: Bool) {
    print("""
    [API] Gemini Call
    - Duration: \(duration)s
    - Tokens: \(tokens)
    - Success: \(success)
    - Timestamp: \(Date())
    """)
}
```

**Production**: Replace `print()` with proper logging framework (OSLog, etc.)

---

## API Updates

### Version Management

**Current**: `gemini-2.0-flash-exp` (experimental)

**Future**: Monitor for stable release

**Update Strategy**:
1. Test new model version in development
2. Compare accuracy and cost
3. Update `Config.modelName` if beneficial
4. Maintain backward compatibility

### Deprecation Handling

```swift
enum Config {
    static let modelName = "gemini-2.0-flash-exp"
    static let fallbackModel = "gemini-1.5-pro"  // If primary fails
}
```

---

## Alternative APIs (Future)

### OpenAI GPT-4 Vision

**Pros**: High accuracy, well-documented  
**Cons**: Higher cost, rate limits

### Anthropic Claude

**Pros**: Strong reasoning, safety features  
**Cons**: Pricing, availability

### Local Models

**Pros**: No API costs, privacy  
**Cons**: Device limitations, accuracy

### Abstraction Layer

```swift
protocol VeganAnalysisAPI {
    func analyze(image: UIImage) async throws -> VeganAnalysis
}

class GeminiAPI: VeganAnalysisAPI { }
class OpenAIAPI: VeganAnalysisAPI { }
class LocalModelAPI: VeganAnalysisAPI { }
```

**Configuration**:
```swift
let selectedAPI: VeganAnalysisAPI = {
    switch Config.apiProvider {
    case .gemini: return GeminiAPI()
    case .openai: return OpenAIAPI()
    case .local: return LocalModelAPI()
    }
}()
```

---

## Troubleshooting

### Common Issues

**1. "Invalid API Key"**
- Verify key in Google AI Studio
- Check key copied correctly (no spaces)
- Ensure API enabled in Google Cloud Console

**2. "Rate Limit Exceeded"**
- Check daily/monthly usage
- Wait for quota reset
- Upgrade to paid tier if needed

**3. "Invalid Response"**
- Check network connectivity
- Verify API endpoint URL
- Inspect raw response for malformation

**4. "Image Too Large"**
- Ensure resizeImage() is called
- Check max dimension setting (1024)
- Verify JPEG compression

### Debug Mode

```swift
enum Config {
    static let debugMode = true  // Enable verbose logging
}

// In LLMService
if Config.debugMode {
    print("Request: \(String(data: requestData, encoding: .utf8)!)")
    print("Response: \(String(data: responseData, encoding: .utf8)!)")
}
```

---

## References

- [Gemini API Documentation](https://ai.google.dev/docs)
- [API Pricing](https://ai.google.dev/pricing)
- [Best Practices](https://ai.google.dev/docs/best_practices)
- [Safety Settings](https://ai.google.dev/docs/safety_settings)

---

**Document Version**: 1.0  
**API Version**: Gemini 2.0 Flash Experimental  
**Last Updated**: 2026-02-12  
**Next Review**: 2026-05-12
