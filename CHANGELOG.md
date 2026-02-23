# Changelog

All notable changes to "Is This Vegan?" will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned Features
- Settings screen for user preferences
- Export scan history to CSV/JSON
- Cloud sync via iCloud
- Barcode scanning for quick product lookup
- Nutritional information display
- Multi-language support (Spanish, French, German)
- Allergen detection
- Local on-device AI model option
- Social sharing features

### Known Issues
- See [GitHub Issues](https://github.com/lepapillonterrible/Is-this-vegan/issues) for current bugs

---

## [1.0.0] - 2026-02-12

### Initial Release

#### Added
- 📸 **Image Scanning**
  - Camera capture for product labels
  - Photo library selection
  - Image preprocessing and optimization
  
- 🔍 **Multi-Stage Analysis Pipeline**
  - OCR text extraction using Apple Vision framework
  - Local ingredient database with 100+ non-vegan ingredients
  - AI-powered analysis using Google Gemini API
  - Smart early-exit optimization to minimize API costs
  
- 📊 **Verdict System**
  - Three-level classification: Vegan / Not Vegan / Uncertain
  - Detailed explanations and reasoning
  - Ingredient breakdown with flagged items
  - Confidence scoring
  
- 📋 **Scan History**
  - SwiftData persistence for all scans
  - Timestamp tracking
  - Image storage with compression
  - Search functionality
  - Swipe-to-delete
  
- 📱 **iOS Widget**
  - Home screen widget displaying latest scan
  - Automatic refresh every 15 minutes
  - App Group data sharing
  - Multiple widget sizes support
  
- 💰 **Cost Management**
  - API usage tracking (daily/monthly)
  - Token consumption monitoring
  - Cost estimation per scan
  - Configurable rate limits
  - Offline-first architecture to minimize costs
  
- 🎨 **User Interface**
  - SwiftUI-based modern interface
  - Tab-based navigation (Scan / History)
  - Color-coded verdicts (Green/Red/Yellow)
  - Gradient backgrounds
  - SF Symbols icons
  - Dark mode support (automatic)
  
- 🔒 **Privacy & Security**
  - Local-only data storage
  - No user accounts required
  - HTTPS for all network requests
  - Camera and photo library permission handling
  
#### Technical Implementation
- **Language**: Swift 5.0
- **Minimum iOS**: 17.0
- **Architecture**: MVVM pattern
- **Frameworks**: SwiftUI, SwiftData, Vision, WidgetKit
- **API Integration**: Google Gemini 2.0 Flash
- **Project Management**: XcodeGen with project.yml

#### Documentation
- Comprehensive README with setup instructions
- ARCHITECTURE.md documenting system design
- SECURITY.md with security best practices
- CONTRIBUTING.md for developer guidelines
- API.md with integration details
- FAQ.md for common questions
- DEPLOYMENT.md for release process
- Inline code documentation throughout codebase

#### Code Quality
- SwiftLint integration for code style
- Well-documented Swift code with comments
- Type-safe models and enums
- Error handling with custom error types
- Async/await concurrency model
- @MainActor for UI thread safety

---

## Version History

### Legend
- `Added` - New features
- `Changed` - Changes to existing functionality
- `Deprecated` - Soon-to-be removed features
- `Removed` - Removed features
- `Fixed` - Bug fixes
- `Security` - Security improvements

---

## [Future Versions]

### [1.1.0] - TBD

**Planned Features**:
- Settings screen with user preferences
- Export history to CSV/JSON
- Enhanced dark mode customization
- VoiceOver accessibility improvements
- Widget configuration options
- Ingredient database auto-updates

**Bug Fixes**:
- TBD based on user feedback

### [1.2.0] - TBD

**Planned Features**:
- Cloud sync via iCloud
- Barcode scanning
- Multi-language OCR support
- Restaurant menu scanning optimization
- Offline AI model option
- Advanced filtering in history

### [2.0.0] - TBD

**Major Changes**:
- Complete UI redesign
- Nutritional information integration
- Social features (share scans)
- Custom dietary preferences
- Advanced allergen detection
- Recipe analysis

---

## Maintenance

### Version Support Policy
- **Current version**: Full support with updates and bug fixes
- **Previous minor version**: Security updates only for 6 months
- **Older versions**: No support (please upgrade)

### Update Frequency
- **Major releases**: 1-2 per year (significant new features)
- **Minor releases**: 2-4 per year (new features, improvements)
- **Patch releases**: As needed (critical bug fixes, security)

### Beta Program
- TestFlight beta releases before each major/minor version
- Early access for testers (sign up on GitHub)
- 1-2 week beta period for feedback

---

## Migration Guides

### Migrating to 1.1.0 (Future)
- No breaking changes expected
- SwiftData schema compatible
- Settings will be auto-initialized with defaults

### Migrating to 2.0.0 (Future)
- May require fresh install due to data model changes
- Export history before upgrading (if breaking changes needed)
- iCloud sync will preserve data across devices

---

## Acknowledgments

### Contributors
- Andreea Papillon - Project creator and maintainer
- [Contributors list to be added]

### Third-Party Services
- Google Gemini AI - Ingredient analysis API
- Apple - Vision framework, SwiftUI, SwiftData

### Inspiration
- Vegan community feedback and testing
- Open-source iOS projects
- Apple's design guidelines

---

## Links

- **Repository**: [https://github.com/lepapillonterrible/Is-this-vegan](https://github.com/lepapillonterrible/Is-this-vegan)
- **Issues**: [https://github.com/lepapillonterrible/Is-this-vegan/issues](https://github.com/lepapillonterrible/Is-this-vegan/issues)
- **Releases**: [https://github.com/lepapillonterrible/Is-this-vegan/releases](https://github.com/lepapillonterrible/Is-this-vegan/releases)
- **Documentation**: See docs/ directory in repository

---

**Note**: This changelog is maintained manually. For automated build changes, see Git commit history.

Last Updated: 2026-02-12
