# Backend Proxy - Quick Start

## What This Does

Protects your Gemini API key when releasing to the App Store and making the repo public.

## 5-Minute Setup

### 1. Install Wrangler (Cloudflare CLI)
```bash
npm install -g wrangler
```

### 2. Login to Cloudflare
```bash
wrangler login
```
This opens a browser - authorize the CLI.

### 3. Deploy the Worker
```bash
cd backend
wrangler deploy
```

You'll see output like:
```
Published is-this-vegan-proxy
  https://is-this-vegan-proxy.your-subdomain.workers.dev
```

**Copy this URL!** ⬆️

### 4. Set Your API Key (Secret)
```bash
wrangler secret put GEMINI_API_KEY
```
Paste your Gemini API key when prompted. This is encrypted and never exposed.

### 5. Update iOS App
Edit `App/IsThisVegan - Config.swift`:
```swift
static let backendProxyURL: String = "https://is-this-vegan-proxy.YOUR_SUBDOMAIN.workers.dev"
```

### 6. Test It
```bash
# Build in Release mode in Xcode
# Take a photo and analyze
# Check it works!
```

## How It Works

**Development (Debug builds)**:
```
iOS App → Direct to Gemini API (using your Secrets.plist key)
```

**Production (Release/App Store builds)**:
```
iOS App → Cloudflare Worker → Gemini API (using encrypted secret)
```

The app automatically switches based on build configuration!

## Cost

- **Cloudflare Workers**: FREE for up to 100,000 requests/day
- **Gemini API**: ~$0.0001 per image (~$6/month for 1000 daily users)

## Monitoring

View your worker stats:
```bash
wrangler tail
```

Or go to Cloudflare Dashboard → Workers & Pages → is-this-vegan-proxy

## Need Help?

See the full guide: `backend/README.md`

## Security Checklist

- [x] API key stored as encrypted secret (not in code)
- [x] Worker validates requests before forwarding
- [x] No secrets in git history
- [x] App Store binary has no hardcoded keys
- [ ] (Optional) Add rate limiting for abuse prevention

## What's Next?

1. Test in Release mode
2. Submit to App Store
3. Make repo public
4. Accept contributions!

See `APP_STORE_CHECKLIST.md` for complete release guide.
