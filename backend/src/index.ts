// backend/src/index.ts
// TypeScript backend - placeholder for future sync endpoints
// OPAQUE authentication is handled by backend-rust/

export interface Env {
  // Future sync functionality will use these
  RATE_LIMITS: KVNamespace;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
          'Access-Control-Max-Age': '86400'
        }
      });
    }

    // OPAQUE auth routes are handled by Rust worker at /auth/opaque/*
    if (url.pathname.startsWith('/auth/opaque/')) {
      return jsonResponse({ error: 'OPAQUE auth moved to Rust worker' }, 410);
    }

    return jsonResponse({ error: 'Not found' }, 404);
  }
};

function jsonResponse(data: object, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    }
  });
}
