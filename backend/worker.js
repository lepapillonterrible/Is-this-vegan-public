// Cloudflare Worker - Proxy for Gemini API
// Protects API key and adds rate limiting

export default {
  async fetch(request, env) {
    // CORS headers for iOS app
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*', // Replace with your app's domain in production
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    // Handle preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Only allow POST
    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    try {
      // Get request body from iOS app
      const body = await request.json();
      
      // Basic validation
      if (!body.contents || !Array.isArray(body.contents)) {
        return new Response(
          JSON.stringify({ error: 'Invalid request format' }),
          { status: 400, headers: corsHeaders }
        );
      }

      // Rate limiting (approx 50 requests/day per IP)
      const clientId = request.headers.get('CF-Connecting-IP') || 'unknown';
      await checkRateLimit(clientId, env);

      // Forward to Gemini API with your secret key
      const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${env.GEMINI_MODEL}:generateContent?key=${env.GEMINI_API_KEY}`;
      
      const geminiResponse = await fetch(geminiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
      });

      const data = await geminiResponse.json();

      // Return response to iOS app
      return new Response(JSON.stringify(data), {
        status: geminiResponse.status,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      });

    } catch (error) {
      if (error.message === 'Rate limit exceeded. Try again tomorrow.') {
          return new Response(
            JSON.stringify({ error: error.message }),
            { status: 429, headers: corsHeaders }
          );
      }
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: corsHeaders }
      );
    }
  },
};

async function checkRateLimit(clientId, env) {
  const key = `ratelimit:${clientId}`;
  const limit = 50; // requests per day
  const now = Date.now();
  const windowStart = Math.floor(now / 86400000) * 86400000; // Start of day (UTC)
  
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
