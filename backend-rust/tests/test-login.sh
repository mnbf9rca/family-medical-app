#!/bin/bash
# Test login endpoint
curl -s -w "\nHTTP: %{http_code}\n" -X POST https://api.recordwell.app/auth/opaque/login/start \
  -H "Content-Type: application/json" \
  -d '{"clientIdentifier":"0000000000000000000000000000000000000000000000000000000000000000","startLoginRequest":"dGVzdA=="}'
