# Architecture Documentation

## Overview

Is This Vegan? is an iOS application built using SwiftUI and modern Apple frameworks. The app follows an MVVM (Model-View-ViewModel) architecture pattern with a clear separation of concerns.

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Presentation Layer                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐ │
│  │ScanView  │  │ResultView│  │HistoryView│ │ Widget  │ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬────┘ │
│       └─────────────┼─────────────┼─────────────┘      │
└─────────────────────┼─────────────┼────────────────────┘
                      │             │
┌─────────────────────┼─────────────┼────────────────────┐
│                ViewModel Layer     │                    │
│              ┌──────▼──────┐      │                    │
│              │ScannerViewModel     │                    │
│              └──────┬──────┘      │                    │
└─────────────────────┼─────────────┼────────────────────┘
                      │             │
┌─────────────────────┼─────────────┼────────────────────┐
│                Service Layer       │                    │
│  ┌────────────────▼─┴─────────────▼──────┐            │
│  │        AnalysisPipeline                │            │
│  │  (Orchestrates the analysis flow)      │            │
│  └────┬──────────┬──────────┬─────────────┘            │
│       │          │          │                           │
│  ┌────▼────┐ ┌──▼──────┐ ┌─▼───────────┐              │
│  │OCRService│ │Ingredient│ │LLMService  │              │
│  │(Vision) │ │Database  │ │(Gemini API)│              │
│  └─────────┘ └──────────┘ └────────────┘              │
│                                                         │
│  ┌────────────────┐  ┌──────────────────┐             │
│  │ImagePicker     │  │UsageTracker      │             │
│  │Service         │  │                  │             │
│  └────────────────┘  └──────────────────┘             │
└─────────────────────────────────────────────────────────┘
                      │
┌─────────────────────┼─────────────────────────────────┐
│                  Data Layer                            │
│  ┌────────────────▼────────────────┐                  │
│  │         SwiftData                │                  │
│  │  - ScanResult (with image data)  │                  │
│  │  - Persisted in App Group        │                  │
│  │  - Shared with Widget            │                  │
│  └─────────────────────────────────┘                  │
└────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Analysis Pipeline

**Location**: `Services/AnalysisPipeline.swift`

The central orchestrator for ingredient analysis. Implements a three-stage pipeline:

1. **OCR Stage**: Extract text from image using Apple Vision framework
2. **Local Database Check**: Search for known non-vegan ingredients
3. **AI Analysis**: Use Gemini API for comprehensive ingredient analysis

**Key Features**:
- Early exit optimization (stops at first non-vegan finding)
- Cost estimation before API calls
- Fallback mechanisms for each stage

**Flow**:
```
Image → OCR → Text Extraction
             ↓
      Ingredient Database Check
             ↓ (if needed)
      Gemini AI Analysis
             ↓
      VeganVerdict + Explanation
```

### 2. OCR Service

**Location**: `Services/IsThisVegan - OCRService.swift`

Handles text extraction from images using Apple's Vision framework.

**Features**:
- Multi-language support (English, Thai)
- Fast recognition level optimization
- Automatic language detection
- Confidence threshold filtering

**Technology**: VNRecognizeTextRequest with custom configuration

### 3. LLM Service

**Location**: `Services/LLMService.swift`

Integrates with Google's Gemini API for AI-powered ingredient analysis.

**Key Responsibilities**:
- Image resizing and optimization for API
- JSON-based structured responses
- Error handling and rate limiting detection
- Response parsing and validation

**API Integration**:
- Model: `gemini-2.0-flash-exp`
- Response format: JSON with verdict, reasoning, and ingredient details
- Image format: JPEG with quality optimization

### 4. Ingredient Database

**Location**: `Services/IngredientDatabase.swift`

Local database of known non-vegan ingredients for fast lookups.

**Data Structure**:
- JSON-based ingredient list
- Case-insensitive fuzzy matching
- Alternative names support
- Categorization (dairy, meat, eggs, etc.)

**Performance**: O(n) scan with early exit on match

### 5. Scanner ViewModel

**Location**: `ViewModels/ScannerViewModel.swift`

Central state management for the scanning workflow.

**State Management**:
- `@Published` properties for reactive UI updates
- `@MainActor` for thread safety
- Task cancellation support
- Error state handling

**Key Methods**:
- `processImage()`: Main entry point for analysis
- `saveScan()`: Persist results to SwiftData
- `loadHistory()`: Fetch past scans

### 6. Data Models

#### ScanResult
**Location**: `Models/IsThisVegan - ScanResult.swift`

SwiftData model for persisted scan results.

**Properties**:
- `id`: Unique identifier
- `timestamp`: Scan date/time
- `imageData`: Original image (external storage)
- `ocrText`: Extracted text
- `verdict`: Vegan status
- `reasoning`: AI explanation
- `ingredients`: Detected ingredients

**Storage**: External storage for images to optimize database size

#### VeganVerdict
**Location**: `Models/IsThisVegan - VeganVerdict.swift`

Type-safe enum for vegan status.

**Values**:
- `vegan`: Confirmed vegan-friendly
- `notVegan`: Contains non-vegan ingredients
- `uncertain`: Insufficient information

**Features**:
- Color-coded display properties
- Icon representations
- Localized descriptions

## Data Flow

### Scan Flow

1. User selects image (camera or library)
2. `ScannerViewModel.processImage()` called
3. Image sent to `AnalysisPipeline.analyze()`
4. OCR extracts text
5. Local database checked for known ingredients
6. If uncertain, Gemini API analyzes image
7. Result returned to ViewModel
8. ViewModel saves to SwiftData
9. UI updates with result

### Widget Flow

1. Widget requests timeline update
2. `VeganWidgetDataProvider.fetchLastScan()` queries SwiftData
3. Latest scan result retrieved from App Group container
4. Widget displays cached result
5. Refresh every 15 minutes or on app launch

## Concurrency Model

### Actor Isolation

- **@MainActor**: ViewModels and Views for UI updates
- **@unchecked Sendable**: AnalysisPipeline (⚠️ needs review)
- **async/await**: All service methods for non-blocking operations

### Thread Safety

- SwiftData operations on background context
- Image processing on background threads
- UI updates guaranteed on main thread via `@MainActor`

## Data Persistence

### SwiftData Configuration

**Container**: Shared across app and widget via App Group

**App Group ID**: `group.com.isthisvegan.shared`

**Schema**:
```swift
@Model
class ScanResult {
    var id: UUID
    var timestamp: Date
    var imageData: Data?  // @Attribute(.externalStorage)
    var ocrText: String
    var verdict: VeganVerdict
    // ... other fields
}
```

**Benefits**:
- Type-safe queries with `@Query` macro
- Automatic relationship management
- iCloud sync capability (future)

## Error Handling Strategy

### Service Layer

- Custom error enums for each service
- Error propagation via `throws`
- Graceful degradation (local DB fallback)

### ViewModel Layer

- Error state captured in `@Published` properties
- User-friendly error messages
- Retry mechanisms where appropriate

### UI Layer

- Error alerts with actionable messages
- Loading states during async operations
- Fallback UI for missing data

## Performance Considerations

### Optimization Strategies

1. **Early Exit**: Pipeline stops at first definitive result
2. **Image Resizing**: Reduce API payload size
3. **External Storage**: Images stored outside SwiftData database
4. **Lazy Loading**: History view loads on-demand
5. **Debouncing**: Search in history view could benefit from debouncing

### Known Bottlenecks

1. **Large History**: In-memory filtering in HistoryView
2. **Image Processing**: No async loading for large images
3. **Widget Refresh**: 15-minute polling could be stale
4. **LLM API Latency**: 2-5 second response time

## Security Architecture

### API Key Management

⚠️ **Current Implementation**: API key in `Config.swift`
- **Risk**: Exposure if committed or reverse-engineered
- **Recommended**: Move to backend proxy or keychain

### Data Privacy

- Images stored locally without encryption
- No user authentication required
- No data sent to external servers (except Gemini API)
- App Group data readable by apps in same group

### Network Security

- HTTPS for all API calls
- No certificate pinning (consider for production)
- Rate limiting enforced by API quota

## Testing Strategy

### Current State
- No visible unit tests in codebase
- SwiftUI previews for visual testing
- Sample data for development

### Recommended Coverage
- [ ] Unit tests for Services layer
- [ ] Integration tests for AnalysisPipeline
- [ ] UI tests for critical user flows
- [ ] Snapshot tests for Views
- [ ] Widget tests

## Deployment Architecture

### Build Configuration

**XcodeGen**: Project generation from `project.yml`

**Targets**:
1. **IsThisVegan** (Main App)
   - Bundle ID: `com.IsThisVegan.com`
   - Deployment Target: iOS 17.0+
   - Swift Version: 5.0

2. **IsThisVeganWidget** (Widget Extension)
   - Bundle ID: `com.IsThisVegan.com.Widget`
   - Depends on main app target
   - Shares models via source inclusion

### App Store Considerations

- [ ] API key must be removed/secured
- [ ] Privacy policy required (camera, photo library)
- [ ] Rate limiting for cost control
- [ ] App size optimization (image compression)

## Future Architecture Considerations

### Scalability

1. **Backend Service**: Move API calls to dedicated backend
2. **Cloud Sync**: iCloud integration for cross-device history
3. **Offline Mode**: Local LLM or expanded ingredient database
4. **Multi-language**: Localization for international users

### Modularity

1. **Swift Packages**: Extract services into reusable modules
2. **Dependency Injection**: Improve testability
3. **Feature Flags**: Enable/disable features dynamically
4. **Analytics**: Track usage patterns and errors

## Design Patterns Used

| Pattern | Location | Purpose |
|---------|----------|---------|
| **MVVM** | ViewModels + Views | Separation of business logic and UI |
| **Repository** | AnalysisPipeline | Abstract data access |
| **Strategy** | Service protocols | Interchangeable algorithms |
| **Observer** | @Published properties | Reactive state updates |
| **Factory** | UsageTracker | Create tracking records |
| **Singleton** | UsageTracker (attempted) | Shared state management |

## Dependencies

### Apple Frameworks
- **SwiftUI**: Declarative UI framework
- **SwiftData**: Data persistence
- **Vision**: OCR and text recognition
- **WidgetKit**: Home screen widget
- **UIKit**: Image handling (PhotosUI)

### External APIs
- **Google Gemini API**: AI-powered ingredient analysis
  - Version: `gemini-2.0-flash-exp`
  - Endpoint: `generativelanguage.googleapis.com`

### No Third-Party Libraries
All functionality implemented using native Apple frameworks.

## Configuration

### Environment Variables

**Current**: Hardcoded in `Config.swift`

**Future Recommendation**: 
- Use `.xcconfig` files for environment-specific settings
- Separate dev/staging/production configurations
- Secure API keys in keychain or backend

### Feature Flags

**Suggested Implementation**:
```swift
enum FeatureFlags {
    static let enableLocalDatabase = true
    static let enableGeminiAPI = true
    static let enableWidgetRefresh = true
    static let enableCostTracking = true
}
```

## Monitoring and Observability

### Current State
- Print statements for debugging
- No centralized logging
- No analytics

### Recommended Additions
- [ ] Structured logging framework (OSLog)
- [ ] Error reporting (Sentry, Crashlytics)
- [ ] Analytics (Firebase, Mixpanel)
- [ ] Performance monitoring (MetricKit)

---

**Document Version**: 1.0  
**Last Updated**: 2026-02-12  
**Maintainer**: Development Team
