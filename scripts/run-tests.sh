#!/bin/bash
set -e

# iOS Test Runner
# Runs unit tests with code coverage
# Usage: ./scripts/run-tests.sh [destination]
#
# Default destination: iPhone 17,OS=26.2 (matches local development)
# CI uses: iPhone 17 Pro,OS=26.2 (matches CI environment)

# Change to project directory
cd "$(dirname "$0")/../ios/FamilyMedicalApp"

# Default destination for local development
DESTINATION="${1:-platform=iOS Simulator,name=iPhone 17,OS=26.2}"

echo "Running tests with destination: $DESTINATION"

# Clean previous test results
rm -rf test-results* DerivedData/TestResults.xcresult

# Run tests
xcodebuild test \
  -project FamilyMedicalApp.xcodeproj \
  -scheme FamilyMedicalApp \
  -destination "$DESTINATION" \
  -testPlan FamilyMedicalApp \
  -enableCodeCoverage YES \
  -derivedDataPath DerivedData \
  -resultBundlePath test-results/TestResults.xcresult \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO

echo "✅ Tests completed"
