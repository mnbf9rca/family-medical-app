# Backend Service

**Status**: Phase 2 - Not yet implemented

This directory will contain the sync backend service for cross-device synchronization.

## Phase 2 Implementation

Backend development begins in **Phase 2** after Phase 1 (local iOS app) is complete.

See Issue #14 for backend technology research and selection.

## Planned Features

- Encrypted blob storage
- User authentication (for sync, not data decryption)
- Sync coordination
- Zero-knowledge architecture (server cannot decrypt data)

## Development Environment

When implementation begins, this directory will include:
- `.devcontainer/` - VS Code devcontainer configuration
- `docker-compose.yml` - Local development services
- Backend API code (Python/FastAPI, Node.js, or chosen stack)
- Database migrations
- API documentation

## For Now

Focus on Phase 1 (iOS app) first. Backend setup will be documented when Phase 2 begins.
