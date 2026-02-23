# Deployment Guide

## Overview

This guide covers deploying "Is This Vegan?" to TestFlight, the App Store, and managing production releases.

---

## Table of Contents

- [Pre-Deployment Checklist](#pre-deployment-checklist)
- [App Store Prerequisites](#app-store-prerequisites)
- [Build Configuration](#build-configuration)
- [Code Signing](#code-signing)
- [TestFlight Deployment](#testflight-deployment)
- [App Store Submission](#app-store-submission)
- [Post-Release](#post-release)
- [Continuous Deployment](#continuous-deployment)

---

## Pre-Deployment Checklist

### Critical Security Items

⚠️ **MUST BE COMPLETED BEFORE PRODUCTION**:

- [ ] **Remove hardcoded API key from source code**
  - Implement backend proxy for API calls, OR
  - Store API key in iOS Keychain, OR
  - Use environment variables with build-time injection
  - See [SECURITY.md](SECURITY.md) for detailed guidance

- [ ] **Review and fix thread safety issues**
  - Remove `@unchecked Sendable` from AnalysisPipeline
  - Implement proper actor isolation or @MainActor
  - Test concurrent scan scenarios

- [ ] **Implement proper error handling**
  - Replace silent failures with user feedback
  - Add retry logic for network errors
  - Provide actionable error messages

### Code Quality

- [ ] All SwiftLint warnings resolved
  ```bash
  swiftlint lint --strict
  ```

- [ ] Xcode static analyzer clean
  ```bash
  xcodebuild analyze -scheme IsThisVegan
  ```

- [ ] No force unwraps in production code paths
- [ ] All TODO/FIXME comments addressed or documented

### Testing

- [ ] Unit tests passing (when implemented)
- [ ] Manual testing on multiple devices
  - iPhone 15 Pro
  - iPhone SE (small screen)
  - iPad Pro (large screen)
- [ ] Widget tested on all widget sizes
- [ ] Camera permissions tested
- [ ] Photo library permissions tested
- [ ] Offline mode tested
- [ ] API rate limiting tested

### Privacy & Legal

- [ ] Privacy policy created and published
- [ ] App Store privacy questionnaire completed
- [ ] Terms of service (if needed)
- [ ] Data retention policy implemented
- [ ] Third-party service agreements reviewed (Gemini API)

---

## App Store Prerequisites

### Apple Developer Account

**Individual Account** ($99/year):
- Personal apps
- Single developer

**Organization Account** ($99/year):
- Team development
- Company/nonprofit apps

**Sign up**: https://developer.apple.com/programs/

### App Store Connect Setup

1. **Create App ID**
   - Log in to [App Store Connect](https://appstoreconnect.apple.com)
   - Go to "My Apps" → "+" → "New App"
   - Platform: iOS
   - Name: "Is This Vegan?"
   - Primary Language: English
   - Bundle ID: `com.IsThisVegan.com` (or your custom ID)
   - SKU: `is-this-vegan-001`

2. **Configure App Information**
   - Category: Food & Drink or Health & Fitness
   - Content Rights: Declare if contains third-party content
   - Age Rating: 4+ (no mature content)

3. **App Privacy**
   - Data Collection: Photos (for scanning)
   - Data Linked to User: None (no user accounts)
   - Data Used to Track User: None
   - Third-Party SDKs: Declare Gemini API usage

### Required Assets

#### App Icons
- 1024x1024 App Store icon (PNG, no transparency)
- Icon set in `Assets.xcassets/AppIcon`

Sizes needed:
- 20pt (1x, 2x, 3x)
- 29pt (1x, 2x, 3x)
- 40pt (2x, 3x)
- 60pt (2x, 3x)
- 76pt (1x, 2x) - iPad
- 83.5pt (2x) - iPad Pro

#### Screenshots

**iPhone 6.7" (required)**:
- 1290 x 2796 pixels
- Minimum 1 screenshot, up to 10

**iPhone 6.5"**:
- 1284 x 2778 pixels

**iPhone 5.5"**:
- 1242 x 2208 pixels

**iPad Pro 12.9"**:
- 2048 x 2732 pixels

**Recommended screenshots**:
1. Main scan screen with sample product
2. Vegan verdict result screen (green)
3. Not vegan result screen (red) with explanation
4. History view with multiple scans
5. Widget on home screen

#### Marketing Materials

- App Preview video (optional, recommended)
  - 15-30 seconds
  - Show core functionality: scan → result
  - Max file size: 500 MB

- App Description
  - Concise, benefit-focused
  - Highlight key features
  - Include keywords for App Store search

---

## Build Configuration

### Version Numbers

Edit in Xcode:
- **Marketing Version**: User-facing (e.g., "1.0", "1.1")
- **Build Number**: Incrementing integer (e.g., "1", "2", "3")

Or update in `project.yml`:
```yaml
settings:
  base:
    MARKETING_VERSION: "1.0"
    CURRENT_PROJECT_VERSION: "1"
```

### Build Configurations

**Debug** (default for development):
- Debugging enabled
- Optimization: None
- Asserts enabled

**Release** (for production):
- Debugging disabled
- Optimization: Aggressive (-O)
- Asserts disabled
- Symbols stripped

### Scheme Configuration

1. Open Xcode
2. Product → Scheme → Edit Scheme
3. Run → Info → Build Configuration: Debug
4. Archive → Info → Build Configuration: Release

### Build Settings

**Key settings for production**:

```yaml
ENABLE_BITCODE: NO  # Deprecated in Xcode 14+
SWIFT_COMPILATION_MODE: wholemodule  # Better optimization
SWIFT_OPTIMIZATION_LEVEL: -O  # Full optimization
DEAD_CODE_STRIPPING: YES
STRIP_INSTALLED_PRODUCT: YES
COPY_PHASE_STRIP: YES
DEBUG_INFORMATION_FORMAT: dwarf-with-dsym  # For crash symbolication
```

### API Configuration

**Before archiving, ensure**:

`Config.swift` does NOT contain real API key:
```swift
enum Config {
    static let geminiAPIKey: String {
        // Load from backend, keychain, or Info.plist
        guard let key = ... else {
            fatalError("API key not configured")
        }
        return key
    }
}
```

---

## Code Signing

### Automatic Signing (Recommended)

1. Select project in Xcode
2. Select target: "IsThisVegan"
3. Signing & Capabilities tab
4. Check "Automatically manage signing"
5. Team: Select your Apple Developer team
6. Repeat for "IsThisVeganWidget" target

Xcode will:
- Create/update App ID
- Create/update provisioning profiles
- Manage certificates

### Manual Signing

**If you need custom certificates**:

1. Create App ID in [Developer Portal](https://developer.apple.com/account/resources/identifiers)
2. Create Distribution Certificate
3. Create App Store Distribution Provisioning Profile
4. Download and install profiles
5. In Xcode, uncheck "Automatically manage signing"
6. Select provisioning profiles manually

### Entitlements

**Required entitlements** (already configured):

`IsThisVegan.entitlements`:
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.isthisvegan.shared</string>
</array>
```

`IsThisVeganWidget.entitlements`:
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.isthisvegan.shared</string>
</array>
```

**Additional entitlements to consider**:
- Push Notifications (if implementing cloud sync)
- HealthKit (if adding nutrition tracking)
- iCloud (for history sync)

---

## TestFlight Deployment

### Create Archive

1. **Clean build folder**
   ```bash
   # In Xcode: Product → Clean Build Folder
   # Or via command line:
   xcodebuild clean -scheme IsThisVegan
   ```

2. **Select "Any iOS Device" target**
   - In Xcode toolbar, change from simulator to "Any iOS Device (arm64)"

3. **Archive the app**
   - Product → Archive
   - Wait for build to complete (2-5 minutes)
   - Organizer window will appear

### Upload to App Store Connect

1. In Organizer, select your archive
2. Click "Distribute App"
3. Select "App Store Connect"
4. Click "Upload"
5. Distribution options:
   - ✅ Include bitcode (deprecated, skip)
   - ✅ Upload symbols (for crash reports)
   - ✅ Manage version and build number
6. Sign with automatic or manual signing
7. Click "Upload"
8. Wait for processing (10-30 minutes)

### Configure TestFlight

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. My Apps → Is This Vegan → TestFlight
3. Wait for "Processing" to complete
4. Add test information:
   - What to test: "Initial beta release"
   - Beta App Description: Brief description
   - Beta App Review Information: Contact details

5. **Internal Testing**:
   - Add team members (up to 100)
   - No review required
   - Builds available immediately

6. **External Testing**:
   - Add external testers (up to 10,000)
   - Requires App Store review (1-2 days)
   - Create test groups
   - Generate public link or invite via email

### Invite Testers

**Internal**:
1. TestFlight → Internal Group
2. Click "+" to add testers
3. Enter Apple IDs
4. Testers receive email invitation

**External**:
1. TestFlight → External Groups
2. Create new group
3. Add build to group
4. Submit for review
5. After approval, invite testers

**Public Link** (external only):
1. External Groups → Create public link
2. Share link (anyone can install)
3. Limit: 10,000 testers

---

## App Store Submission

### Prepare Submission

1. **App Information**
   - App Store Connect → App Information
   - Name: "Is This Vegan?"
   - Subtitle (optional): "AI-Powered Vegan Scanner"
   - Privacy Policy URL: Required
   - Category: Food & Drink
   - Age Rating: 4+

2. **Version Information**
   - App Store Connect → 1.0 Prepare for Submission
   - Screenshot uploads (6.7", 5.5", iPad)
   - Promotional text (170 chars)
   - Description (4000 chars max)
   - Keywords (100 chars): "vegan, scanner, ingredients, AI"
   - Support URL: GitHub repo or website
   - Marketing URL (optional)

3. **Build Selection**
   - Click "+" next to Build
   - Select TestFlight build to release

4. **App Review Information**
   - Sign-in required: No
   - Demo account: N/A
   - Contact information: Your details
   - Notes: "App requires camera permission for scanning product labels"

5. **Version Release**
   - Automatic: Release immediately after approval
   - Manual: Release when you're ready
   - Scheduled: Set specific date/time

### Submit for Review

1. Click "Submit for Review"
2. Export compliance: Does app use encryption?
   - Yes (HTTPS) → Select standard encryption
3. Content rights: No third-party content
4. Advertising identifier: Not using
5. Confirm and submit

### Review Timeline

- Initial review: 1-3 days (typically 24-48 hours)
- Re-submissions: 1-2 days
- Expedited review: Request in App Store Connect (rare circumstances)

### Common Rejection Reasons

**To avoid rejection**:
- ✅ Privacy policy must be accessible (URL works)
- ✅ App permissions clearly explained (camera, photos)
- ✅ No crashes on launch
- ✅ All features functional (don't submit broken builds)
- ✅ Metadata accurate (screenshots match actual app)
- ✅ Complies with App Store Review Guidelines
- ✅ Third-party terms accepted (Gemini API terms)

**If rejected**:
1. Read rejection message carefully
2. Address all issues mentioned
3. Update notes in Resolution Center
4. Submit updated build or resubmit

---

## Post-Release

### Monitor Metrics

**App Store Connect Analytics**:
- Downloads
- Impressions
- Conversion rate
- App Units (paid apps)
- In-app purchases (if added later)

**Crash Reports**:
- Xcode → Organizer → Crashes
- Filter by version
- Download .crash files for analysis
- Symbolicate with dSYM files

### Crash Symbolication

**Enable automatic upload**:
1. Build Settings → Debug Information Format: `dwarf-with-dsym`
2. Build Settings → Strip Debug Symbols: `YES` for Release
3. Archives automatically include dSYMs

**Manual symbolication**:
```bash
# Find dSYM file
cd ~/Library/Developer/Xcode/Archives

# Symbolicate crash log
atos -arch arm64 -o IsThisVegan.app.dSYM/Contents/Resources/DWARF/IsThisVegan -l <load_address> <crash_address>
```

### User Feedback

**App Store Reviews**:
- Monitor daily
- Respond to reviews (professional, helpful)
- Address common complaints in updates

**Support Channels**:
- GitHub Issues
- Email support
- In-app feedback (future feature)

### Analytics (Optional)

**Consider adding**:
- Firebase Analytics
- Mixpanel
- Custom backend analytics

**Always**:
- Respect user privacy
- Disclose data collection in Privacy Policy
- Provide opt-out mechanisms

---

## Continuous Deployment

### Automated Builds (CI/CD)

**Using GitHub Actions**:

`.github/workflows/build.yml`:
```yaml
name: Build and Test

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Select Xcode version
      run: sudo xcode-select -s /Applications/Xcode_15.2.app
    
    - name: Build
      run: xcodebuild -scheme IsThisVegan -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build
    
    - name: Test
      run: xcodebuild -scheme IsThisVegan -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' test
```

**Using Fastlane**:

`Fastfile`:
```ruby
default_platform(:ios)

platform :ios do
  desc "Build for TestFlight"
  lane :beta do
    increment_build_number
    build_app(scheme: "IsThisVegan")
    upload_to_testflight
    commit_version_bump(message: "Version bump")
    push_to_git_remote
  end

  desc "Build for App Store"
  lane :release do
    increment_version_number
    increment_build_number
    build_app(scheme: "IsThisVegan")
    upload_to_app_store
    commit_version_bump(message: "Release version bump")
    push_to_git_remote
  end
end
```

Install Fastlane:
```bash
brew install fastlane
fastlane init
```

Deploy:
```bash
fastlane beta    # TestFlight
fastlane release # App Store
```

### Versioning Strategy

**Semantic Versioning**:
- **Major** (1.0.0 → 2.0.0): Breaking changes, major redesign
- **Minor** (1.0.0 → 1.1.0): New features, backward compatible
- **Patch** (1.0.0 → 1.0.1): Bug fixes only

**Build Numbers**:
- Increment for every build (1, 2, 3, ...)
- Never reuse build numbers
- Can automate with Fastlane or scripts

### Release Checklist

For each release:

- [ ] Update CHANGELOG.md
- [ ] Increment version number
- [ ] Run all tests
- [ ] Run SwiftLint
- [ ] Test on physical devices
- [ ] Archive and upload to TestFlight
- [ ] Internal testing (1-2 days)
- [ ] External testing (optional, 1 week)
- [ ] Submit to App Store
- [ ] Monitor crash reports
- [ ] Respond to reviews
- [ ] Plan next release

---

## Troubleshooting

### Archive Upload Fails

**"Invalid Bundle" error**:
- Ensure Bundle ID matches App Store Connect
- Check provisioning profile includes device UDIDs
- Verify all targets have correct signing

**"Missing compliance" error**:
- Answer export compliance questions
- Add ITSAppUsesNonExemptEncryption key to Info.plist

### Code Signing Issues

**"No valid signing identity" error**:
1. Revoke old certificates in Developer Portal
2. Download new distribution certificate
3. Install in Keychain Access
4. Clean build folder and retry

**"Provisioning profile doesn't include app ID"**:
1. Ensure Bundle ID matches exactly
2. Regenerate provisioning profile
3. Download and install

### TestFlight Processing Stuck

**Build stuck on "Processing"**:
- Wait 30 minutes (sometimes takes longer)
- Check for email from App Store Connect
- Verify dSYM uploaded correctly
- Re-upload if stuck >2 hours

---

## Resources

### Apple Documentation
- [App Store Connect Guide](https://developer.apple.com/app-store-connect/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [TestFlight Beta Testing](https://developer.apple.com/testflight/)

### Tools
- [Fastlane](https://fastlane.tools/) - Automation
- [App Store Connect API](https://developer.apple.com/app-store-connect/api/) - Programmatic access
- [Xcode Cloud](https://developer.apple.com/xcode-cloud/) - Apple's CI/CD

### Communities
- [Apple Developer Forums](https://developer.apple.com/forums/)
- [Stack Overflow - iOS](https://stackoverflow.com/questions/tagged/ios)
- [r/iOSProgramming](https://www.reddit.com/r/iOSProgramming/)

---

**Document Version**: 1.0  
**Last Updated**: 2026-02-12  
**Next Review**: Before first production release
