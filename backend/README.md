# RecordWell API

Cloudflare Workers backend for RecordWell app OPAQUE zero-knowledge authentication.

## Architecture

- **Cloudflare Workers** - Serverless API endpoints
- **Cloudflare KV** - OPAQUE password files, encrypted bundles, login state
- **@serenity-kit/opaque** - OPAQUE protocol (RFC 9807) implementation

## API Endpoints

### OPAQUE Authentication

| Method | Path | Description |
|--------|------|-------------|
| POST | `/auth/opaque/register/start` | Begin registration |
| POST | `/auth/opaque/register/finish` | Complete registration |
| POST | `/auth/opaque/login/start` | Begin login |
| POST | `/auth/opaque/login/finish` | Complete login |

## Development

```bash
npm install
npm run dev        # Local development
npm run typecheck  # Type checking
npm run deploy     # Deploy to production
```

## Environment Variables

| Name | Description |
|------|-------------|
| `OPAQUE_SERVER_SETUP` | Secret: OPAQUE server setup string |

## KV Namespaces

| Binding | Purpose |
|---------|---------|
| `CREDENTIALS` | OPAQUE password files |
| `BUNDLES` | Encrypted user data bundles |
| `LOGIN_STATES` | Temporary login state (60s TTL) |
| `RATE_LIMITS` | Rate limit counters |
