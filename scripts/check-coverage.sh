#!/bin/bash
set -e

# Generate code coverage report from xcresult
cd ios/FamilyMedicalApp
xcrun xccov view --report --json test-results/TestResults.xcresult > test-results/coverage.json

# Extract coverage percentage
COVERAGE=$(cat test-results/coverage.json | python3 -c "import sys, json; print(json.load(sys.stdin)['lineCoverage'] * 100)")
echo "Code coverage: ${COVERAGE}%"

# Enforce minimum coverage threshold
THRESHOLD=90
echo "Required minimum coverage: ${THRESHOLD}%"

# Use floor division to avoid rounding up (89.6% should fail, not pass)
# Compare as integers by multiplying by 100: 89.6 * 100 = 8960, threshold * 100 = 9000
COVERAGE_SCALED=$(echo "$COVERAGE * 100" | bc | cut -d. -f1)
THRESHOLD_SCALED=$((THRESHOLD * 100))

if (( COVERAGE_SCALED < THRESHOLD_SCALED )); then
  echo "❌ Coverage check failed: ${COVERAGE}% is below the required ${THRESHOLD}%."
  exit 1
else
  echo "✅ Coverage check passed: ${COVERAGE}% meets or exceeds ${THRESHOLD}%."
fi
