# Backend Proxy for Is This Vegan?

This serverless backend protects the Gemini API key and adds rate limiting.

## Why a Backend?

- ✅ **Security**: API key never exposed in the iOS app
- ✅ **Cost Control**: Rate limiting prevents abuse
- ✅ **Open Source**: Contributors can fork without needing your API key
- ✅ **Analytics**: Track usage patterns

## Deployment Options

### Option 1: Cloudflare Workers (Recommended)

**Pros**: Free tier (100k requests/day), fast global edge network, easy setup

#### Setup

1. **Install Wrangler CLI**
   ```bash
   npm install -g wrangler
   wrangler login
   ```

2. **Deploy**
   ```bash
   cd backend
   wrangler deploy
   ```

3. **Set API Key Secret**
   ```bash
   wrangler secret put GEMINI_API_KEY
   # Paste your Gemini API key when prompted
   ```

4. **Get Your Worker URL**
   ```
   https://is-this-vegan-proxy.YOUR_SUBDOMAIN.workers.dev
   ```

5. **Update iOS App**
   - Edit `Config.swift`
   - Set `geminiBaseURL` to your worker URL
   - Remove `geminiAPIKey` (not needed anymore)

### Option 2: Vercel Edge Functions

Create `api/gemini.ts`:
```typescript
export const config = { runtime: 'edge' };

export default async function handler(req: Request) {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const body = await req.json();
  
  const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${process.env.GEMINI_MODEL}:generateContent?key=${process.env.GEMINI_API_KEY}`;
  
  const response = await fetch(geminiUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  return new Response(await response.text(), {
    status: response.status,
    headers: { 'Content-Type': 'application/json' },
  });
}
```

Deploy with:
```bash
vercel --prod
vercel env add GEMINI_API_KEY
```

### Option 3: Google Cloud Functions

Good if you're already using Google Cloud.

```bash
gcloud functions deploy gemini-proxy \
  --runtime nodejs20 \
  --trigger-http \
  --allow-unauthenticated \
  --set-env-vars GEMINI_MODEL=gemini-2.0-flash-lite \
  --set-secrets GEMINI_API_KEY=projects/YOUR_PROJECT/secrets/gemini-api-key:latest
```

## Rate Limiting (Optional)

### Cloudflare KV-based Rate Limiting

Add to `worker.js`:

```javascript
async function checkRateLimit(clientId, env) {
  const key = `ratelimit:${clientId}`;
  const limit = 100; // requests per day
  const now = Date.now();
  const windowStart = Math.floor(now / 86400000) * 86400000; // Start of day
  
  const stored = await env.RATE_LIMIT.get(key, 'json');
  
  if (stored && stored.window === windowStart) {
    if (stored.count >= limit) {
      throw new Error('Rate limit exceeded. Try again tomorrow.');
    }
    await env.RATE_LIMIT.put(key, JSON.stringify({
      window: windowStart,
      count: stored.count + 1,
    }), { expirationTtl: 86400 });
  } else {
    await env.RATE_LIMIT.put(key, JSON.stringify({
      window: windowStart,
      count: 1,
    }), { expirationTtl: 86400 });
  }
}
```

Create KV namespace:
```bash
wrangler kv:namespace create RATE_LIMIT
```

Add to `wrangler.toml`:
```toml
[[kv_namespaces]]
binding = "RATE_LIMIT"
id = "your-namespace-id-from-above-command"
```

## Monitoring

### Cloudflare Dashboard
- View request count, errors, latency
- Set up alerts for quota usage

### Custom Analytics
Add to worker:
```javascript
// Log to external service (e.g., Axiom, Datadog)
await fetch('https://api.axiom.co/v1/datasets/gemini-logs/ingest', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${env.AXIOM_TOKEN}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    timestamp: Date.now(),
    ip: request.headers.get('CF-Connecting-IP'),
    model: env.GEMINI_MODEL,
    status: geminiResponse.status,
  }),
});
```

## Cost Estimation

- **Cloudflare Workers**: Free for 100k requests/day, then $5/10M requests
- **Gemini API**: ~$0.0001 per image (flash-lite model)
- **Estimated cost**: 1000 daily users × 2 requests = $0.20/day = $6/month

## Security Checklist

- [ ] API key stored as secret (not in code)
- [ ] CORS restricted to your app domain (optional)
- [ ] Rate limiting enabled
- [ ] Request validation (image size, format)
- [ ] Error messages don't leak sensitive info
- [ ] Monitoring/alerting set up

## Open Source Considerations

### For App Store Version
- Use this backend proxy
- API key secured on Cloudflare/Vercel
- Rate limiting prevents abuse

### For Contributors
- Keep `Secrets.plist` approach for local development
- Contributors use their own API keys
- README explains both approaches

Update main README:
```markdown
## Development Setup

### Option 1: Use Your Own API Key (Recommended for Contributors)
1. Get a free Gemini API key from https://makersuite.google.com/app/apikey
2. Copy `Secrets.plist.example` to `Resources/Secrets.plist`
3. Add your API key

### Option 2: Use the Production Backend (App Store Version)
No setup needed - uses the public proxy server.
```

## Testing

Test your proxy:
```bash
curl -X POST https://is-this-vegan-proxy.YOUR_SUBDOMAIN.workers.dev \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{
      "parts": [{
        "text": "Is this vegan?"
      }, {
        "inline_data": {
          "mime_type": "image/jpeg",
          "data": "BASE64_IMAGE_DATA_HERE"
        }
      }]
    }],
    "generationConfig": {
      "temperature": 0.4,
      "topK": 32,
      "topP": 1,
      "maxOutputTokens": 2048
    }
  }'
```

## Troubleshooting

**"Worker not found"**: Check `wrangler.toml` name matches deployment
**CORS errors**: Verify `Access-Control-Allow-Origin` header
**Rate limit errors**: Check KV namespace configuration
**Gemini API errors**: Verify secret is set correctly

## License

Same as main project (MIT)
