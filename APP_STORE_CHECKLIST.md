# App Store + Open Source Release Checklist

## 🎯 Goal
- ✅ Release app to App Store
- ✅ Make repository public on GitHub
- ✅ Protect API key using backend proxy
- ✅ Allow contributors to use their own API keys

## 📋 Pre-Release Checklist

### 1. Backend Deployment (Required for App Store)

- [ ] **Deploy backend proxy**
  ```bash
  cd backend
  npm install -g wrangler
  wrangler login
  wrangler deploy
  ```

- [ ] **Set API key secret**
  ```bash
  wrangler secret put GEMINI_API_KEY
  # Paste your Gemini API key when prompted
  ```

- [ ] **Get your Worker URL**
  - Copy the URL from deployment output (e.g., `https://is-this-vegan-proxy.YOUR_SUBDOMAIN.workers.dev`)

- [ ] **Update Config.swift**
  ```swift
  static let backendProxyURL: String = "https://YOUR_ACTUAL_WORKER_URL"
  ```

- [ ] **Test the proxy**
  ```bash
  # See backend/README.md for curl test command
  ```

### 2. iOS App Configuration

- [ ] **Verify build configuration**
  - Release builds use `useBackendProxy = true` (check Config.swift)
  - Debug builds use `useBackendProxy = false` for development

- [ ] **Test with proxy in Release mode**
  - Build in Release mode
  - Verify API calls go through backend
  - Check no API key is embedded in the binary

- [ ] **Update App Store metadata**
  - Privacy policy (mention Gemini API usage)
  - Terms of service (if applicable)
  - Support URL

### 3. Repository Preparation

- [ ] **Update README.md**
  - Add "App Store" and "Open Source" badges
  - Add development setup instructions for both modes:
    - **Option 1**: Use your own API key (for contributors)
    - **Option 2**: Use production backend (for App Store version)

- [ ] **Add LICENSE file** (if not already present)
  ```bash
  # MIT License recommended for open source
  ```

- [ ] **Update .gitignore**
  - Ensure `Secrets.plist` is ignored ✅ (already done)
  - Add `backend/node_modules/` if using local dev
  - Add `.env` files

- [ ] **Add CONTRIBUTING.md guidelines** ✅ (already done)

- [ ] **Add CODE_OF_CONDUCT.md** (optional but recommended)

### 4. Security Review

- [ ] **Verify no secrets in git history**
  ```bash
  git log --all --full-history --source -- '*Secrets.plist'
  # Should be empty or only show example file
  ```

- [ ] **Check for hardcoded keys**
  ```bash
  git grep -i "AIzaSy"  # Gemini API keys start with this
  git grep -i "api.key"
  ```

- [ ] **Review backend security**
  - Rate limiting enabled (optional but recommended)
  - CORS configured properly
  - Error messages don't leak sensitive info

### 5. App Store Submission

- [ ] **Build for App Store**
  - Archive in Xcode
  - Upload to App Store Connect
  - Submit for review

- [ ] **App Store metadata**
  - Screenshots
  - Description
  - Keywords
  - Privacy policy URL
  - Support URL

- [ ] **App Review notes**
  - Mention that app uses Gemini API via backend proxy
  - Provide test account if needed (not required for this app)

### 6. Go Public on GitHub

⚠️ **WAIT until App Store submission is approved** (recommended)

- [ ] **Final security check**
  - Run `git log --all --full-history` and search for any API keys
  - Review all files in the repo

- [ ] **Make repository public**
  - Go to GitHub → Settings → Danger Zone
  - Change visibility to Public

- [ ] **Add GitHub topics/tags**
  - `swift`, `ios`, `vegan`, `computer-vision`, `gemini-api`

- [ ] **Create first release**
  ```bash
  git tag -a v1.0.0 -m "Initial App Store release"
  git push origin v1.0.0
  ```

- [ ] **Add GitHub shields/badges to README**
  - App Store download badge
  - Swift version
  - License
  - Build status (if using CI/CD)

## 🔄 Dual Setup Documentation

Add this to your main README.md:

```markdown
## 🛠️ Development Setup

### For Contributors (Recommended)

Use your own Gemini API key for local development:

1. **Get a free Gemini API key**
   - Go to https://makersuite.google.com/app/apikey
   - Create a new API key (free tier: 60 requests/minute)

2. **Configure the app**
   ```bash
   cp Secrets.plist.example Resources/Secrets.plist
   # Edit Resources/Secrets.plist and add your API key
   ```

3. **Build and run**
   - Open `IsThisVegan.xcodeproj` in Xcode
   - Build in Debug mode (uses your API key)
   - Run on simulator or device

### For App Store Build (Maintainers Only)

Production builds use the secure backend proxy:

1. **Deploy backend** (see `backend/README.md`)
2. **Update `Config.swift`** with your worker URL
3. **Build in Release mode** (uses backend proxy)
4. **Test before submission**

The app automatically switches between modes:
- **Debug builds**: Direct API (your key)
- **Release builds**: Backend proxy (secured)
```

## 📊 Cost Monitoring

After going live:

- [ ] **Set up Cloudflare alerts**
  - Alert when requests > 10k/day
  - Alert when errors > 5%

- [ ] **Monitor Gemini API usage**
  - Check quota usage in Google Cloud Console
  - Set budget alerts

- [ ] **Track App Store metrics**
  - Downloads
  - Crash reports
  - User reviews

## 🚨 Rollback Plan

If something goes wrong:

1. **Backend issues**
   - Roll back Cloudflare Worker to previous version
   - Or temporarily switch to direct API (requires app update)

2. **App issues**
   - Submit hotfix to App Store
   - May take 1-2 days for review

3. **Cost issues**
   - Add aggressive rate limiting in backend
   - Or disable backend temporarily (users see error)

## ✅ Post-Launch

- [ ] Monitor for first 48 hours
- [ ] Respond to GitHub issues
- [ ] Update documentation based on feedback
- [ ] Consider adding analytics (optional)
- [ ] Plan v1.1 features

## 📝 Notes

- Backend proxy is **free** for up to 100k requests/day on Cloudflare Workers
- Gemini API costs ~$0.0001 per image with flash-lite model
- Expected cost: $5-10/month for 1000 daily active users
- Can always add rate limiting or BYOK in future updates

## 🎉 You're Ready!

Once all checkboxes are complete, you're ready to:
1. Submit to App Store
2. Make repo public
3. Announce on social media
4. Accept contributions

Good luck! 🚀
