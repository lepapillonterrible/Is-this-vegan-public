# Contributing to Is This Vegan?

Thank you for considering contributing to Is This Vegan! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Code Style](#code-style)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Issue Guidelines](#issue-guidelines)

---

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Welcome newcomers and help them learn
- Focus on constructive feedback
- Respect differing viewpoints and experiences

### Unacceptable Behavior

- Harassment, discriminatory language, or personal attacks
- Publishing others' private information
- Trolling or deliberately disruptive behavior

---

## Getting Started

### Prerequisites

- **macOS**: Monterey (12.0) or later
- **Xcode**: 15.0 or later
- **iOS Device/Simulator**: iOS 17.0+
- **Git**: For version control
- **Google Cloud Account**: For Gemini API access (development)

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR-USERNAME/Is-this-vegan.git
   cd Is-this-vegan
   ```
3. Add upstream remote:
   ```bash
   git remote add upstream https://github.com/lepapillonterrible/Is-this-vegan.git
   ```

---

## Development Setup

### 1. Install Xcode

Download from the Mac App Store or [Apple Developer](https://developer.apple.com/xcode/).

### 2. Install XcodeGen (Optional)

If you plan to modify `project.yml`:
```bash
brew install xcodegen
```

### 3. Configure API Key

Create a test API key for development:

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create a new API key
3. Update `App/IsThisVegan - Config.swift`:

```swift
enum Config {
    static let geminiAPIKey = "your-development-api-key"
    // ⚠️ DO NOT commit this file with real keys
}
```

**Important**: Add `Config.swift` to `.gitignore` if using real keys.

### 4. Build and Run

1. Open `IsThisVegan.xcodeproj` in Xcode
2. Select target: `IsThisVegan`
3. Choose simulator or device
4. Press `Cmd+R` to build and run

### 5. Run SwiftLint

```bash
# Install SwiftLint
brew install swiftlint

# Run linting
swiftlint lint

# Auto-fix issues
swiftlint lint --fix
```

---

## Making Changes

### Branch Naming

Use descriptive branch names:
- `feature/ingredient-database-update`
- `bugfix/crash-on-image-load`
- `docs/improve-readme`
- `refactor/extract-llm-service`

### Commit Messages

Follow conventional commit format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples**:
```
feat(ocr): Add support for Japanese text recognition

- Update OCRService to include Japanese language
- Add test images with Japanese ingredients
- Update documentation

Closes #42
```

```
fix(history): Prevent crash when deleting multiple items

The deletion logic didn't handle batch operations correctly,
causing an index out of bounds error.

Fixes #38
```

### Keep Commits Atomic

- One logical change per commit
- Commit messages explain "why" not just "what"
- Easy to review and revert if needed

---

## Code Style

### Swift Style Guide

We follow [Swift.org API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) and [Google Swift Style Guide](https://google.github.io/swift/).

### Key Principles

#### 1. Naming Conventions

```swift
// ✅ Good
func calculateVeganScore(from ingredients: [String]) -> Double
let isVeganFriendly: Bool
class IngredientAnalyzer

// ❌ Avoid
func calc(ing: [String]) -> Double  // Abbreviations
let vegan: Bool  // Unclear
class analyzer  // Not capitalized
```

#### 2. Type Safety

```swift
// ✅ Good - Use enums for fixed sets of values
enum VeganVerdict: String, Codable {
    case vegan
    case notVegan
    case uncertain
}

// ❌ Avoid - Magic strings
let verdict = "vegan"  // No compile-time safety
```

#### 3. Optionals

```swift
// ✅ Good - Guard for early returns
guard let imageData = result.imageData else {
    return nil
}

// ✅ Good - Nil coalescing for defaults
let text = result.ocrText ?? "No text detected"

// ❌ Avoid - Force unwrapping
let data = result.imageData!  // Crash risk
```

#### 4. Error Handling

```swift
// ✅ Good - Propagate errors
func analyzeIngredients(_ text: String) throws -> VeganVerdict {
    guard !text.isEmpty else {
        throw AnalysisError.emptyInput
    }
    // ...
}

// ❌ Avoid - Silent failures
func analyzeIngredients(_ text: String) -> VeganVerdict? {
    if text.isEmpty { return nil }  // Lost error context
}
```

#### 5. SwiftUI Best Practices

```swift
// ✅ Good - Extract subviews
struct ScanView: View {
    var body: some View {
        VStack {
            headerView
            resultView
            actionButtons
        }
    }
    
    private var headerView: some View {
        Text("Scan Result")
            .font(.title)
    }
}

// ❌ Avoid - Massive body
struct ScanView: View {
    var body: some View {
        VStack {
            // 100+ lines of view code
        }
    }
}
```

### SwiftLint Configuration

The project uses `.swiftlint.yml` for automated style enforcement:

```yaml
# Key rules
line_length: 120
function_body_length: 40
type_body_length: 300
file_length: 500
```

**Run before committing**:
```bash
swiftlint lint --strict
```

### Documentation Comments

Use Swift's documentation markup:

```swift
/// Analyzes an image to determine if the product is vegan.
///
/// This method performs a three-stage analysis:
/// 1. OCR text extraction
/// 2. Local ingredient database check
/// 3. AI-powered analysis (if needed)
///
/// - Parameter image: The product image to analyze
/// - Returns: A tuple containing verdict, reasoning, and detected ingredients
/// - Throws: `AnalysisError` if the image cannot be processed
func analyze(image: UIImage) async throws -> (VeganVerdict, String, [String]) {
    // Implementation
}
```

---

## Testing

### Current State

⚠️ **Note**: The project currently lacks comprehensive tests. Adding tests is a valuable contribution!

### Testing Guidelines

#### Unit Tests

Test business logic in isolation:

```swift
import XCTest
@testable import IsThisVegan

final class IngredientDatabaseTests: XCTestCase {
    var database: IngredientDatabase!
    
    override func setUp() {
        super.setUp()
        database = IngredientDatabase()
    }
    
    func testDetectsNonVeganIngredient() {
        let result = database.checkIngredients("Contains milk and eggs")
        XCTAssertEqual(result.verdict, .notVegan)
    }
    
    func testCaseInsensitiveMatching() {
        let result = database.checkIngredients("GELATIN")
        XCTAssertEqual(result.verdict, .notVegan)
    }
}
```

#### Integration Tests

Test service interactions:

```swift
func testAnalysisPipelineFullFlow() async throws {
    let pipeline = AnalysisPipeline()
    let testImage = UIImage(named: "test-label")!
    
    let (verdict, reasoning, ingredients) = try await pipeline.analyze(image: testImage)
    
    XCTAssertNotNil(verdict)
    XCTAssertFalse(reasoning.isEmpty)
}
```

#### UI Tests

Test critical user flows:

```swift
func testScanAndViewResult() {
    let app = XCUIApplication()
    app.launch()
    
    app.buttons["Scan"].tap()
    app.buttons["Photo Library"].tap()
    // Select test image
    // Assert result appears
}
```

### Running Tests

```bash
# Run all tests
xcodebuild test -scheme IsThisVegan -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test
xcodebuild test -scheme IsThisVegan -only-testing:IsThisVeganTests/IngredientDatabaseTests
```

---

## Submitting Changes

### Pull Request Process

1. **Update from upstream**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run quality checks**:
   ```bash
   swiftlint lint --strict
   # Run tests (when available)
   ```

3. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

4. **Create Pull Request**:
   - Go to GitHub and click "New Pull Request"
   - Select your feature branch
   - Fill out the PR template (see below)

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tested on iOS 17 simulator
- [ ] Tested on physical device
- [ ] Added unit tests
- [ ] Manual testing steps: [describe]

## Screenshots (if applicable)
[Add screenshots of UI changes]

## Checklist
- [ ] Code follows style guidelines
- [ ] SwiftLint passes
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] No new warnings in Xcode
- [ ] API key not committed

## Related Issues
Closes #[issue number]
```

### Review Process

1. **Automated Checks**: CI runs SwiftLint and builds project
2. **Code Review**: Maintainer reviews code quality and design
3. **Testing**: Changes tested on simulator and device
4. **Approval**: At least one maintainer approval required
5. **Merge**: Squash and merge to main branch

---

## Issue Guidelines

### Reporting Bugs

Use the bug report template:

```markdown
**Bug Description**
Clear description of the issue

**Steps to Reproduce**
1. Open app
2. Tap 'Scan'
3. Select image
4. Observe crash

**Expected Behavior**
What should happen

**Actual Behavior**
What actually happens

**Environment**
- iOS Version: 17.2
- Device: iPhone 15 Pro
- App Version: 1.0

**Screenshots/Logs**
[Attach if available]
```

### Feature Requests

Explain the use case and benefit:

```markdown
**Feature Description**
Support for scanning restaurant menus

**Use Case**
As a user, I want to scan a full restaurant menu to see which items are vegan

**Proposed Solution**
- Multi-item detection
- Menu layout understanding
- Summary view with all items

**Alternatives Considered**
- Manual item-by-item scanning (too slow)

**Additional Context**
This would help users make quick decisions when dining out
```

### Priority Labels

- `priority: critical` - Crashes, data loss, security issues
- `priority: high` - Major features broken, poor UX
- `priority: medium` - Minor bugs, nice-to-have features
- `priority: low` - Cosmetic issues, future enhancements

---

## Areas for Contribution

### High Priority

- [ ] **Unit Tests**: Add comprehensive test coverage
- [ ] **Error Handling**: Improve user-facing error messages
- [ ] **Performance**: Optimize history view for large datasets
- [ ] **Accessibility**: VoiceOver support and accessibility labels
- [ ] **Localization**: Multi-language support

### Medium Priority

- [ ] **Ingredient Database**: Expand and update ingredient list
- [ ] **Dark Mode**: Custom dark mode color scheme
- [ ] **Settings Screen**: User preferences and configuration
- [ ] **Export Feature**: Export scan history to CSV/JSON
- [ ] **Cloud Sync**: iCloud integration for cross-device history

### Nice to Have

- [ ] **Offline Mode**: Local LLM or expanded database
- [ ] **Nutritional Info**: Additional product information
- [ ] **Barcode Scanning**: Product lookup via barcode
- [ ] **Social Sharing**: Share to Instagram/Twitter
- [ ] **Widgets**: Additional widget sizes and styles

---

## Development Resources

### Documentation

- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [Vision Framework Guide](https://developer.apple.com/documentation/vision)
- [WidgetKit Documentation](https://developer.apple.com/documentation/widgetkit)

### Tools

- [SwiftLint](https://github.com/realm/SwiftLint) - Code linting
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) - Project generation
- [SF Symbols](https://developer.apple.com/sf-symbols/) - Icon library
- [Gemini API Docs](https://ai.google.dev/docs) - AI integration

### Community

- **Discussions**: Use GitHub Discussions for questions
- **Issues**: Report bugs and request features
- **Pull Requests**: Submit changes for review

---

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

## Questions?

If you have questions about contributing, please:
1. Check existing documentation
2. Search GitHub Issues
3. Open a new Discussion
4. Contact maintainers (see README.md)

Thank you for contributing to Is This Vegan! 🌱

---

**Document Version**: 1.0  
**Last Updated**: 2026-02-12
