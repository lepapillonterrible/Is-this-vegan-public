# Is This Vegan? 🌱

[![Swift Version](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

An iOS app and widget that lets you snap a photo of a product label or restaurant menu item and instantly find out if it's vegan. Powered by AI and local ingredient database for fast, accurate results.

## ✨ Features

### Core Functionality
- 📸 **Smart Image Analysis** - Scan product labels via camera or photo library
- 🔍 **Multi-Stage Detection** - OCR text extraction + local database + AI analysis
- 🟢🟡🔴 **Clear Verdicts** - Instant vegan/not-vegan/uncertain classification
- 💡 **Detailed Explanations** - AI-powered reasoning for each verdict
- 📊 **Ingredient Breakdown** - Complete list of detected ingredients

### User Experience
- 📱 **iOS Widget** - Quick access to last scan result from home screen
- 📋 **Scan History** - Review all past scans with timestamps
- 🔎 **History Search** - Find previous scans by product name or ingredients
- 💾 **Offline Database** - Common non-vegan ingredients detected locally
- ⚡ **Fast Results** - Average analysis time: 2-5 seconds

### Technical Features
- 🧠 **AI-Powered** - Google Gemini 2.0 Flash for advanced analysis
- 🔒 **Privacy-First** - All data stored locally on device
- 💰 **Cost Tracking** - Monitor API usage and estimated costs
- 🎯 **High Accuracy** - Multi-stage pipeline ensures reliable results

## 🛠 Tech Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **UI Framework** | SwiftUI | Modern declarative interface |
| **Data Persistence** | SwiftData | Type-safe local storage |
| **OCR Engine** | Apple Vision | Fast text extraction from images |
| **AI Analysis** | Google Gemini API | Ingredient analysis and reasoning |
| **Widget** | WidgetKit | Home screen widget integration |
| **Image Processing** | UIKit | Image optimization and handling |
| **Concurrency** | Swift Async/Await | Modern asynchronous operations |

## 📁 Project Structure

```
IsThisVegan/
├── App/
│   ├── IsThisVeganApp.swift          # App entry point & configuration
│   └── Config.swift                   # API keys & app settings
│
├── Models/
│   ├── ScanResult.swift               # SwiftData model for scan results
│   └── VeganVerdict.swift             # Verdict enum (vegan/not-vegan/uncertain)
│
├── Services/
│   ├── AnalysisPipeline.swift         # Orchestrates OCR → DB → AI flow
│   ├── OCRService.swift               # Apple Vision text recognition
│   ├── LLMService.swift               # Gemini API integration
│   ├── IngredientDatabase.swift       # Local non-vegan ingredients
│   ├── ImagePickerService.swift       # Camera/photo library access
│   └── UsageTracker.swift             # API usage and cost monitoring
│
├── ViewModels/
│   └── ScannerViewModel.swift         # Main business logic and state
│
├── Views/
│   ├── ContentView.swift              # Main tab navigation
│   ├── ScanView.swift                 # Camera/photo selection screen
│   ├── ResultView.swift               # Verdict display with details
│   ├── HistoryView.swift              # Past scans list with search
│   └── CameraView.swift               # Custom camera interface
│
├── Widget/
│   ├── IsThisVeganWidget.swift        # Widget timeline provider
│   ├── IsThisVeganWidgetBundle.swift  # Widget bundle configuration
│   └── WidgetViews.swift              # Widget UI components
│
└── Resources/
    └── Assets.xcassets/               # App icons, colors, images
```

## 🚀 Getting Started

### Prerequisites

- **macOS**: Monterey (12.0) or later
- **Xcode**: 15.0 or later
- **iOS Device/Simulator**: iOS 17.0+
- **Google Cloud Account**: For Gemini API access (free tier available)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/lepapillonterrible/Is-this-vegan.git
   cd Is-this-vegan
   ```

2. **Get API Key**
   - Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
   - Sign in and create a new API key
   - Copy the generated key

3. **Configure API Key**
   
   Open `App/IsThisVegan - Config.swift` and update:
   ```swift
   enum Config {
       static let geminiAPIKey = "your-actual-api-key-here"
       
       // Optional: Adjust rate limits
       static let dailyAPICallLimit = 50
       static let monthlyAPICallLimit = 1000
   }
   ```

   ⚠️ **Important**: Do NOT commit your real API key to version control

4. **Open in Xcode**
   ```bash
   open IsThisVegan.xcodeproj
   ```

5. **Build and Run**
   - Select target: `IsThisVegan`
   - Choose iOS Simulator or physical device
   - Press `Cmd+R` to build and run

### First Launch

1. Grant camera and photo library permissions when prompted
2. Take a photo or select an image of a product label
3. Wait 2-5 seconds for analysis
4. View verdict and detailed explanation

## 📖 How It Works

### Analysis Pipeline

```
┌─────────────┐
│ User scans  │
│    image    │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────┐
│  1. OCR Text Extraction             │
│  (Apple Vision Framework)           │
│  • Fast, on-device processing       │
│  • Multi-language support           │
└──────┬──────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│  2. Local Database Check            │
│  (Ingredient Database)              │
│  • 100+ known non-vegan ingredients │
│  • Instant results, no API cost     │
└──────┬──────────────────────────────┘
       │
       ▼ (if uncertain)
┌─────────────────────────────────────┐
│  3. AI Analysis                     │
│  (Google Gemini API)                │
│  • Comprehensive ingredient review  │
│  • Context-aware reasoning          │
│  • Handles edge cases               │
└──────┬──────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│  Result: Verdict + Explanation      │
│  • Vegan / Not Vegan / Uncertain    │
│  • Ingredient list                  │
│  • Reasoning                        │
└─────────────────────────────────────┘
```

### Key Features

- **Early Exit Optimization**: Pipeline stops at first definitive result
- **Cost Efficiency**: Local database handles ~60% of queries
- **Graceful Degradation**: Falls back through stages if one fails
- **Offline Support**: OCR and local database work without internet

## ⚙️ Configuration

### App Settings

Edit `App/IsThisVegan - Config.swift`:

```swift
enum Config {
    // API Configuration
    static let geminiAPIKey = "your-api-key"
    static let modelName = "gemini-2.0-flash-exp"
    
    // Rate Limiting
    static let dailyAPICallLimit = 50      // Max calls per day
    static let monthlyAPICallLimit = 1000  // Max calls per month
    
    // App Group (for widget data sharing)
    static let appGroupIdentifier = "group.com.isthisvegan.shared"
    
    // Analysis Settings
    static let maxImageDimension: CGFloat = 1024  // Resize large images
    static let analysisTimeout: TimeInterval = 30  // API timeout
}
```

### Widget Configuration

The widget automatically displays your most recent scan. To add:

1. Long-press home screen
2. Tap "+" in top-left
3. Search for "Is This Vegan?"
4. Select widget size and add

Updates every 15 minutes or when app is opened.

## 💰 Cost Management

### API Pricing

**Google Gemini API** (Approximate costs):
- Free Tier: 60 requests/minute
- Cost per request: ~$0.0001-0.0003 (varies by usage)
- 50 scans/day ≈ $0.015/day or $0.45/month

### Cost Tracking

The app tracks:
- Daily and monthly API calls
- Token usage per request
- Estimated costs in real-time

View usage in the app (feature to be added) or check `UsageTracker` logs.

### Reducing Costs

1. **Use Local Database First**: ~60% of queries answered locally
2. **Enable Rate Limits**: Configure max daily/monthly calls
3. **Cache Results**: Duplicate scans retrieve from history (not yet implemented)
4. **Optimize Images**: Images auto-resized to reduce API payload

## 🧪 Development

### Running Tests

```bash
# Unit tests (to be added)
xcodebuild test -scheme IsThisVegan -destination 'platform=iOS Simulator,name=iPhone 15'

# SwiftLint (code quality)
swiftlint lint --strict
```

### Code Style

This project follows the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) and uses SwiftLint for enforcement.

Run linter before committing:
```bash
swiftlint lint --fix  # Auto-fix issues
swiftlint lint        # Check for violations
```

### Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Code of conduct
- Development setup
- Coding standards
- Pull request process
- Issue guidelines

## 📚 Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System design and technical architecture
- **[API.md](API.md)** - Gemini API integration details
- **[SECURITY.md](SECURITY.md)** - Security considerations and best practices
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - How to contribute to this project

## 🔒 Security & Privacy

### Data Privacy

- ✅ All scans stored **locally on device**
- ✅ No user accounts or authentication required
- ✅ Images sent to Gemini API only for analysis
- ✅ No data shared with third parties (except API provider)
- ❌ No cloud backup (yet)

### Security Considerations

⚠️ **Before Production Release**:
- [ ] Secure API key (use backend proxy or keychain)
- [ ] Implement certificate pinning
- [ ] Add data retention policy
- [ ] Enable data encryption for images

See [SECURITY.md](SECURITY.md) for full security documentation.

## ⚠️ Known Limitations

### Current Constraints

1. **Language Support**: OCR optimized for English and Thai only
2. **API Dependency**: AI analysis requires internet connection
3. **Image Quality**: Poor lighting or blurry images affect accuracy
4. **Rate Limits**: Free API tier limits daily scans
5. **Ingredient Database**: Local database needs periodic updates

### Future Enhancements

- [ ] Multi-language OCR support
- [ ] Offline AI model option
- [ ] Barcode scanning
- [ ] Nutritional information display
- [ ] Cloud sync for scan history
- [ ] Social sharing features
- [ ] Allergen detection
- [ ] Custom ingredient preferences

## 🐛 Troubleshooting

### Common Issues

**"Invalid API Key" Error**
```
Solution: Verify API key is correctly set in Config.swift
Check: Google AI Studio → API Keys → Key enabled
```

**"Rate Limit Exceeded"**
```
Solution: Wait for quota reset or upgrade API tier
Check: Current usage in app or Google Cloud Console
```

**"No text detected" on clear labels**
```
Solution: Ensure good lighting and focus
Try: Retake photo with better angle/lighting
```

**Widget not updating**
```
Solution: iOS updates widgets every 15 minutes
Force refresh: Open app to trigger immediate update
```

**App crashes on image selection**
```
Solution: Grant photo library permissions in Settings
Check: Settings → Privacy → Photos → Is This Vegan
```

### Debug Mode

Enable verbose logging in `Config.swift`:
```swift
static let debugMode = true  // Print detailed logs
```

Then check Xcode console for detailed error messages.

## 📱 Screenshots

(Screenshots to be added)

## 🗺 Roadmap

### Version 1.1 (Next Release)
- [ ] Settings screen for configuration
- [ ] Export scan history to CSV
- [ ] Dark mode color scheme
- [ ] Accessibility improvements (VoiceOver)

### Version 1.2
- [ ] Cloud sync via iCloud
- [ ] Ingredient database auto-updates
- [ ] Multiple language support
- [ ] Barcode scanning

### Version 2.0
- [ ] Local on-device AI model
- [ ] Nutritional information
- [ ] Social features (share scans)
- [ ] Restaurant menu scanning

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md).

Quick start:
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2026 Andreea Papillon

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

## 🙏 Acknowledgments

- **Google Gemini AI** - For powerful ingredient analysis
- **Apple Vision Framework** - For OCR capabilities
- **SwiftUI Community** - For excellent resources and support
- **Vegan Community** - For testing and feedback

## 📧 Contact

**Project Maintainer**: Andreea Papillon  
**Repository**: [https://github.com/lepapillonterrible/Is-this-vegan](https://github.com/lepapillonterrible/Is-this-vegan)  
**Issues**: [https://github.com/lepapillonterrible/Is-this-vegan/issues](https://github.com/lepapillonterrible/Is-this-vegan/issues)

---

**Made with 💚 for the vegan community**

*If this project helped you, please consider giving it a ⭐ on GitHub!*
