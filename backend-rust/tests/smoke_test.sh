#!/bin/bash
set -e

BASE_URL="${1:-https://api.recordwell.app}"

echo "Testing OPAQUE endpoints at $BASE_URL"

# Test CORS preflight
echo -n "OPTIONS /auth/opaque/register/start... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X OPTIONS "$BASE_URL/auth/opaque/register/start")
if [ "$STATUS" = "200" ]; then
  echo "OK"
else
  echo "FAIL ($STATUS)"
  exit 1
fi

# Test invalid client identifier
echo -n "POST /auth/opaque/register/start (invalid)... "
RESPONSE=$(curl -s -X POST "$BASE_URL/auth/opaque/register/start" \
  -H "Content-Type: application/json" \
  -d '{"clientIdentifier":"short","registrationRequest":"dGVzdA=="}')
if echo "$RESPONSE" | grep -q '"error"'; then
  echo "OK (got error)"
else
  echo "FAIL"
  exit 1
fi

# Test unknown user login
echo -n "POST /auth/opaque/login/start (unknown user)... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/auth/opaque/login/start" \
  -H "Content-Type: application/json" \
  -d '{"clientIdentifier":"0000000000000000000000000000000000000000000000000000000000000000","startLoginRequest":"dGVzdA=="}')
if [ "$STATUS" = "401" ]; then
  echo "OK (401)"
else
  echo "FAIL ($STATUS)"
  exit 1
fi

# Test 404
echo -n "GET /nonexistent... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/nonexistent")
if [ "$STATUS" = "404" ]; then
  echo "OK (404)"
else
  echo "FAIL ($STATUS)"
  exit 1
fi

# Test expired/invalid login state (stateKey doesn't exist)
echo -n "POST /auth/opaque/login/finish (expired session)... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/auth/opaque/login/finish" \
  -H "Content-Type: application/json" \
  -d '{"clientIdentifier":"0000000000000000000000000000000000000000000000000000000000000000","stateKey":"nonexistent:state:key","finishLoginRequest":"dGVzdA=="}')
if [ "$STATUS" = "401" ]; then
  echo "OK (401 - session expired/invalid)"
else
  echo "FAIL ($STATUS)"
  exit 1
fi

# Test malformed JSON (parse error)
# parse_json() returns 400 for JSON parse errors
echo -n "POST /auth/opaque/register/start (malformed JSON)... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/auth/opaque/register/start" \
  -H "Content-Type: application/json" \
  -d '{invalid json}')
if [ "$STATUS" = "400" ]; then
  echo "OK (400 - bad request)"
else
  echo "FAIL ($STATUS)"
  exit 1
fi

# Test missing required fields
# parse_json() returns 400 for deserialization errors (missing fields)
echo -n "POST /auth/opaque/register/start (missing fields)... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/auth/opaque/register/start" \
  -H "Content-Type: application/json" \
  -d '{}')
if [ "$STATUS" = "400" ]; then
  echo "OK (400 - bad request)"
else
  echo "FAIL ($STATUS)"
  exit 1
fi

echo ""
echo "All smoke tests passed!"
