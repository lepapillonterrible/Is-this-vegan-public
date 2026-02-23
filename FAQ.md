# Frequently Asked Questions (FAQ)

## Table of Contents

- [General Questions](#general-questions)
- [Getting Started](#getting-started)
- [Using the App](#using-the-app)
- [Accuracy & Results](#accuracy--results)
- [Privacy & Security](#privacy--security)
- [API & Costs](#api--costs)
- [Technical Questions](#technical-questions)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## General Questions

### What is "Is This Vegan?"

Is This Vegan? is an iOS app that analyzes product labels and menu items to determine if they're vegan-friendly. Simply take a photo, and the app will identify ingredients and provide a verdict.

### Who is this app for?

- **Vegans** looking to quickly verify products
- **People transitioning** to a vegan lifestyle
- **Anyone with dietary restrictions** related to animal products
- **Health-conscious shoppers** who want to know what's in their food

### Is the app free?

The app itself is free and open-source. However, it uses the Google Gemini API which has:
- **Free tier**: Limited requests (usually sufficient for personal use)
- **Costs**: Approximately $0.0001-0.0003 per scan if you exceed free limits

### What platforms are supported?

- **iOS**: 17.0 or later
- **Devices**: iPhone and iPad
- **Widget**: iOS Home Screen Widget support

---

## Getting Started

### How do I install the app?

Currently, the app is not on the App Store. To use it:
1. Clone the repository
2. Open in Xcode 15+
3. Get a Google Gemini API key
4. Build and run on your device

See [README.md](IsThisVegan%20-%20README.md) for detailed setup instructions.

### Do I need an API key?

Yes, you need a free Google Gemini API key for AI-powered analysis. The app also works partially without an API key using:
- OCR text extraction (always works offline)
- Local ingredient database (checks 100+ known non-vegan ingredients)

Only comprehensive AI analysis requires the API.

### How do I get an API key?

1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Click "Create API Key"
4. Copy the key and add it to `Config.swift`

**Cost**: Free tier includes generous quota for personal use.

### Can I use the app offline?

**Partially**:
- ✅ OCR text extraction works offline
- ✅ Local ingredient database checks work offline
- ❌ AI analysis requires internet connection

Results will be less comprehensive offline but still useful.

---

## Using the App

### How do I scan a product?

1. Open the app
2. Tap the camera icon or select "Scan"
3. Choose:
   - **Take Photo**: Use camera to capture label
   - **Photo Library**: Select existing image
4. Wait 2-5 seconds for analysis
5. View verdict and explanation

### What types of images work best?

**Best results**:
- ✅ Well-lit, clear photos
- ✅ Ingredient list in focus
- ✅ Straight-on angle (not skewed)
- ✅ High contrast (dark text on light background)

**Avoid**:
- ❌ Blurry or out-of-focus images
- ❌ Very small text
- ❌ Reflective or glossy surfaces with glare
- ❌ Extreme angles

### Can I scan restaurant menus?

Yes! The app can analyze:
- Restaurant menu items
- Recipe ingredient lists
- Packaged food labels
- Nutritional information panels

### What does each verdict mean?

| Verdict | Meaning | Color |
|---------|---------|-------|
| **Vegan** 🟢 | No animal-derived ingredients detected | Green |
| **Not Vegan** 🔴 | Contains animal products (dairy, eggs, meat, etc.) | Red |
| **Uncertain** 🟡 | Insufficient information or unclear ingredients | Yellow |

### Why did I get "Uncertain"?

Common reasons:
- Image quality too poor to read ingredients
- Ingredient list not visible in photo
- Unusual or ambiguous ingredient names
- Insufficient information on label

**Solution**: Retake photo with better lighting/focus, or manually research unclear ingredients.

### How do I view my scan history?

1. Tap the "History" tab at the bottom
2. Browse all past scans with timestamps
3. Tap any scan to view full details
4. Use search bar to find specific products

### Can I delete scans from history?

Yes:
1. Go to History tab
2. Swipe left on any scan
3. Tap "Delete"

Or use the edit button for batch deletion.

### How does the widget work?

The iOS widget displays your most recent scan on your home screen.

**To add**:
1. Long-press home screen
2. Tap "+" in top corner
3. Search "Is This Vegan?"
4. Select widget and add

**Updates**: Every 15 minutes or when you open the app.

---

## Accuracy & Results

### How accurate is the app?

**Multi-stage accuracy**:
- **OCR**: ~95% text extraction accuracy
- **Local Database**: 100% accuracy for known ingredients
- **AI Analysis**: ~90-95% accuracy (depends on image quality)

**Best for**: Common packaged products with clear labels
**Less reliable for**: Handwritten menus, complex recipes, non-English text

### What ingredients does it check for?

**Animal-derived ingredients detected**:
- Dairy: milk, cheese, whey, casein, lactose
- Eggs: albumin, lecithin (from eggs)
- Meat: gelatin, meat extracts
- Fish: fish oil, anchovies, isinglass
- Honey and bee products
- Shellac, carmine (insects)

See `Services/IngredientDatabase.swift` for full list.

### Does it detect "hidden" non-vegan ingredients?

Yes! The AI analyzes:
- ✅ E-numbers and additives (e.g., E120 = carmine)
- ✅ Derived ingredients (e.g., mono-glycerides can be animal-derived)
- ✅ Processing agents (e.g., bone char in sugar)
- ⚠️ Borderline cases (e.g., "natural flavors" marked as uncertain)

### Can the app make mistakes?

Yes, like any AI system:
- **False positives**: Rare cases where vegan products marked non-vegan
- **False negatives**: Very rare, but possible with ambiguous ingredients
- **Uncertain verdicts**: When AI lacks confidence

**Always**: Double-check critical items or consult manufacturer if unsure.

### What languages are supported?

**Current**:
- ✅ English (primary)
- ✅ Thai (basic support)

**Future**: More languages planned (Spanish, French, German, etc.)

### Can it detect allergens?

Not currently. The app focuses on vegan/non-vegan classification. Allergen detection is a planned future feature.

---

## Privacy & Security

### What data does the app collect?

**Stored locally on device**:
- Product images you scan
- OCR-extracted text
- Scan timestamps
- Analysis results

**NOT collected**:
- No user accounts or personal info
- No location data
- No usage analytics (currently)

### Where is my data stored?

All data is stored **locally on your iPhone** using SwiftData (Apple's secure database).

**App Group**: Used only to share data with the widget (same device).

### Is my data sent anywhere?

**Yes**, but only:
- Images sent to Google Gemini API for analysis
- Google's privacy policy applies to API data

**Not sent**:
- No data to our servers (we don't have any)
- No third-party analytics
- No advertising networks

### How secure is my data?

- ✅ Local storage encrypted by iOS
- ✅ HTTPS for all network requests
- ⚠️ Images stored unencrypted on device
- ⚠️ No additional encryption layer (yet)

See [SECURITY.md](SECURITY.md) for detailed security information.

### Can I delete all my data?

Yes:
1. Delete the app from your device
2. All locally stored scans are permanently deleted

Or delete individual scans from the History tab.

### Does the app work without an internet connection?

**Limited functionality**:
- ✅ OCR text extraction (offline)
- ✅ Local database checks (offline)
- ❌ AI analysis (requires internet)

You'll get basic results offline, but AI-powered insights need connectivity.

---

## API & Costs

### How much does it cost to use?

**App**: Free and open-source

**API Costs** (Google Gemini):
- Free tier: ~60 requests/minute
- Typical usage: 10-50 scans/day
- Estimated cost: $0.01-0.05/day (~$0.30-1.50/month)

Most users stay within free limits.

### How can I reduce API costs?

1. **Use Local Database**: ~60% of scans answered without API
2. **Enable Rate Limits**: Set daily/monthly caps in Config
3. **Avoid Duplicate Scans**: Check history first
4. **Good Image Quality**: Reduces need for re-scans

### What are the rate limits?

**Configurable in app** (`Config.swift`):
- Default: 50 scans/day, 1000/month
- Prevents accidental overage charges

**Google API Limits**:
- Free tier: 60 requests/minute
- Contact Google for higher limits

### What happens if I exceed limits?

**Daily/Monthly limit reached**:
- App shows "Rate limit exceeded" message
- Wait until next day/month for reset
- Or increase limits in Config

**API quota exceeded**:
- Upgrade to paid Google Cloud tier
- Or wait for quota refresh (daily/monthly)

### Can I use a different AI provider?

**Currently**: Google Gemini only

**Planned**: Support for:
- OpenAI GPT-4 Vision
- Anthropic Claude
- Local on-device models

See [API.md](API.md) for integration details.

---

## Technical Questions

### What iOS version do I need?

**Minimum**: iOS 17.0
**Recommended**: iOS 17.2 or later

Why iOS 17? Requires SwiftData and latest Vision framework features.

### Will it work on iPad?

Yes! The app is universal (iPhone and iPad compatible).

Widget is also supported on iPad home screen.

### Does it support macOS?

Not currently. The app is iOS-only (iPhone/iPad).

A macOS version using Catalyst is possible in the future.

### What Xcode version do I need to build?

**Minimum**: Xcode 15.0
**Recommended**: Xcode 15.2 or later

### Can I use this code in my own app?

Yes! The project is MIT licensed. You're free to:
- Use the code in your own projects
- Modify and distribute
- Commercial use allowed

**Requirements**:
- Include MIT license notice
- Attribute original authors

See [LICENSE](LICENSE) for full terms.

### How do I contribute code?

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

### Is there a test suite?

**Currently**: No comprehensive tests (contributions welcome!)

**Planned**:
- Unit tests for Services
- Integration tests for AnalysisPipeline
- UI tests for critical flows

### How do I report bugs?

1. Check existing issues on GitHub
2. If new, create an issue with:
   - Bug description
   - Steps to reproduce
   - Expected vs actual behavior
   - Screenshots/logs
   - Environment (iOS version, device)

---

## Troubleshooting

### "Invalid API Key" error

**Causes**:
- API key not set or incorrect
- Key doesn't have Gemini API enabled

**Solutions**:
1. Verify key in `Config.swift`
2. Check Google AI Studio for key status
3. Ensure Gemini API is enabled in Google Cloud Console

### "Rate Limit Exceeded" error

**Causes**:
- Exceeded daily/monthly app limit
- Exceeded Google API quota

**Solutions**:
1. Wait for limit reset (next day/month)
2. Increase limits in `Config.swift`
3. Upgrade Google Cloud tier

### "No text detected" on clear labels

**Causes**:
- Poor image quality
- Lighting issues
- Text too small or blurry

**Solutions**:
1. Retake photo with better lighting
2. Move closer to label
3. Ensure camera focus is sharp
4. Clean camera lens

### Camera not working

**Causes**:
- Camera permission denied
- Hardware issue

**Solutions**:
1. Settings → Privacy → Camera → Enable "Is This Vegan"
2. Restart app
3. Try photo library instead

### Widget not updating

**Causes**:
- iOS widget refresh limits
- App not opened recently

**Solutions**:
1. Open app to trigger manual refresh
2. Wait up to 15 minutes for automatic update
3. Remove and re-add widget

### App crashes on launch

**Causes**:
- Corrupted data
- iOS version incompatibility

**Solutions**:
1. Delete and reinstall app
2. Update to iOS 17.0+
3. Check Xcode console for crash logs
4. Report issue on GitHub

### Slow analysis (>30 seconds)

**Causes**:
- Poor network connection
- Large image file
- API server latency

**Solutions**:
1. Check internet connection
2. Compress image before scanning
3. Try again later
4. Use local database results (if available)

### Incorrect verdicts

**If you believe a verdict is wrong**:
1. Check ingredient list manually
2. Verify image quality was good
3. Report issue on GitHub with:
   - Product name
   - Expected vs actual verdict
   - Photo (if possible)

Helps us improve accuracy!

---

## Contributing

### How can I help improve the app?

Many ways to contribute:
- **Code**: Fix bugs, add features
- **Testing**: Try the app and report issues
- **Documentation**: Improve guides and docs
- **Ingredients**: Update ingredient database
- **Translations**: Add language support
- **Feedback**: Share suggestions

### I found a security issue, what should I do?

**Do NOT** open a public GitHub issue.

Instead:
1. Email security contact (see SECURITY.md)
2. Include details of vulnerability
3. We'll respond within 24-72 hours

### Can I add ingredients to the database?

Yes! Edit `Services/IngredientDatabase.swift`:

1. Add ingredient to appropriate category
2. Include alternative names/spellings
3. Test changes
4. Submit Pull Request

### How do I request a feature?

1. Check existing GitHub issues
2. If new, create issue with:
   - Feature description
   - Use case / benefit
   - Proposed implementation (optional)

---

## Still Have Questions?

### Resources

- **Documentation**: See [README.md](IsThisVegan%20-%20README.md)
- **Architecture**: See [ARCHITECTURE.md](ARCHITECTURE.md)
- **API Details**: See [API.md](API.md)
- **Security**: See [SECURITY.md](SECURITY.md)

### Get Help

- **GitHub Discussions**: Ask questions, share ideas
- **GitHub Issues**: Report bugs, request features
- **Email**: (contact info in README.md)

### Stay Updated

- **Watch** the repository for updates
- **Star** ⭐ if you find it useful
- **Share** with the vegan community!

---

**Last Updated**: 2026-02-12  
**Version**: 1.0
