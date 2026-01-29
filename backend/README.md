# RecordWell TypeScript Backend

> **Note:** OPAQUE authentication has been moved to the Rust backend at `backend-rust/`.
> This TypeScript worker is a placeholder for future sync functionality.

## Architecture

RecordWell uses a split backend architecture:

| Component | Location | Purpose |
|-----------|----------|---------|
| **Rust Worker** | `backend-rust/` | OPAQUE authentication (opaque-ke v4) |
| **TypeScript Worker** | `backend/` | Future sync endpoints |

## Why Rust for OPAQUE?

The original TypeScript implementation using `@serenity-kit/opaque` failed on Cloudflare Workers because the library uses dynamic WASM compilation (`WebAssembly.compile()`), which Workers blocks for security.

The Rust implementation using `opaque-ke` compiles WASM ahead of time, avoiding this issue. It also ensures protocol compatibility with the iOS client (OpaqueSwift), since both use the same `opaque-ke` crate.

## Development

```bash
npm install
npm run dev        # Local development
npm run typecheck  # Type checking
```

## See Also

- `backend-rust/README.md` - Rust OPAQUE worker documentation
