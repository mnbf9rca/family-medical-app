#!/bin/bash
set -e

# Generate code coverage report from xcresult
cd ios/FamilyMedicalApp
xcrun xccov view --report --json test-results/TestResults.xcresult > test-results/coverage.json

# Extract coverage percentage for FamilyMedicalApp.app target only
COVERAGE=$(python3 -c "
import sys, json
data = json.load(sys.stdin)
app_target = next((t for t in data['targets'] if t['name'] == 'FamilyMedicalApp.app'), None)
if not app_target:
    print('Error: FamilyMedicalApp.app target not found', file=sys.stderr)
    sys.exit(1)
print(app_target['lineCoverage'] * 100)
" < test-results/coverage.json)
echo "Code coverage: ${COVERAGE}%"

# Enforce minimum coverage threshold
# Note: Will be increased to 90% as more application code is added
THRESHOLD=85
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
