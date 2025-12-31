#!/bin/bash
set -u

# iOS Test Runner with Enhanced Output
# Runs unit tests with code coverage and provides a concise summary
#
# Usage: ./scripts/run-tests.sh [options]
#
# Options:
#   --results-only         Hide xcodebuild output, show only test summary
#   --unit-tests-only      Only run unit tests (skip UI tests)
#   --limit N              Limit displayed failures (0 = unlimited, default: unlimited)
#   --destination DEST     Simulator destination (defaults to iPhone 17,OS=26.2)
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed
#   2 - Build failed (tests did not run)

# Prerequisites check
command -v python3 >/dev/null 2>&1 || { echo "Error: python3 is required"; exit 2; }
command -v xcrun >/dev/null 2>&1 || { echo "Error: xcrun is required"; exit 2; }

# Parse arguments
RESULTS_ONLY=false
UNIT_TESTS_ONLY=false
LIMIT=0
DESTINATION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --results-only)
            RESULTS_ONLY=true
            shift
            ;;
        --unit-tests-only)
            UNIT_TESTS_ONLY=true
            shift
            ;;
        --limit)
            LIMIT="$2"
            shift 2
            ;;
        --destination)
            DESTINATION="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Usage: $0 [--results-only] [--unit-tests-only] [--limit N] [--destination DEST]"
            exit 1
            ;;
        *)
            echo "Unexpected positional argument: $1"
            echo "Use --destination to specify the destination"
            exit 1
            ;;
    esac
done

# Apply default destination if not set
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=26.2}"

# Color support (check if stdout is a terminal and supports color)
if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    BOLD=$'\033[1m'
    NC=$'\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BOLD=''
    NC=''
fi

# Change to project directory
cd "$(dirname "$0")/../ios/FamilyMedicalApp" || { echo "Error: Cannot change to project directory"; exit 2; }

echo "Running tests with destination: $DESTINATION"
if [[ "$UNIT_TESTS_ONLY" == "true" ]]; then
    echo "  Mode: Unit tests only (skipping UI tests)"
fi

# Clean previous test results
rm -rf test-results* DerivedData/TestResults.xcresult

# Configure simulator for UI testing
# Disable hardware keyboard to prevent password autofill prompts from blocking XCUITest automation
echo "Configuring simulator for UI testing..."
UDID=$(defaults read com.apple.iphonesimulator CurrentDeviceUDID 2>/dev/null || echo "")
if [ -n "$UDID" ]; then
  /usr/libexec/PlistBuddy -c "Set :DevicePreferences:$UDID:ConnectHardwareKeyboard false" \
    ~/Library/Preferences/com.apple.iphonesimulator.plist 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :DevicePreferences:$UDID:ConnectHardwareKeyboard bool false" \
    ~/Library/Preferences/com.apple.iphonesimulator.plist
  echo "  ✓ Hardware keyboard disabled for simulator $UDID"
else
  echo "  ⚠ Could not determine simulator UDID, hardware keyboard setting not changed"
fi

# Build test command
TEST_CMD=(xcodebuild test
  -project FamilyMedicalApp.xcodeproj
  -scheme FamilyMedicalApp
  -destination "$DESTINATION"
  -testPlan FamilyMedicalApp
  -enableCodeCoverage YES
  -derivedDataPath DerivedData
  -resultBundlePath test-results/TestResults.xcresult
  CODE_SIGN_IDENTITY=""
  CODE_SIGNING_REQUIRED=NO)

if [[ "$UNIT_TESTS_ONLY" == "true" ]]; then
    TEST_CMD+=(-skip-testing:FamilyMedicalAppUITests)
fi

# Run xcodebuild
echo "Running tests..."
if [[ "$RESULTS_ONLY" == "true" ]]; then
    # Hide output, show only summary
    TEMP_OUTPUT=$(mktemp)
    "${TEST_CMD[@]}" > "$TEMP_OUTPUT" 2>&1 || true

    # Check if xcresult exists (indicates tests ran, even if some failed)
    if [[ ! -d "test-results/TestResults.xcresult" ]]; then
        # Build failed before tests could run
        echo -e "${RED}${BOLD}BUILD FAILED${NC}"
        cat "$TEMP_OUTPUT"
        rm -f "$TEMP_OUTPUT"
        exit 2
    fi
    rm -f "$TEMP_OUTPUT"
else
    # Show output so user can see progress (default)
    "${TEST_CMD[@]}" || true

    # Check if xcresult exists (indicates tests ran, even if some failed)
    if [[ ! -d "test-results/TestResults.xcresult" ]]; then
        # Build failed before tests could run
        echo -e "${RED}${BOLD}BUILD FAILED${NC}"
        exit 2
    fi
fi
echo "✅ Tests completed"

# Parse and display test summary
echo ""
echo -e "${BOLD}Test Results${NC}"
echo "============================================================"

# Get test counts from summary - save to temp file
TEMP_SUMMARY=$(mktemp)
if ! xcrun xcresulttool get test-results summary --path test-results/TestResults.xcresult --compact > "$TEMP_SUMMARY" 2>&1; then
    echo -e "${RED}${BOLD}ERROR: Failed to extract test summary${NC}"
    rm -f "$TEMP_SUMMARY"
    exit 2
fi

# Get failure details from legacy format - save to temp file
TEMP_LEGACY=$(mktemp)
if ! xcrun xcresulttool get --path test-results/TestResults.xcresult --format json --legacy > "$TEMP_LEGACY" 2>&1; then
    echo -e "${RED}${BOLD}ERROR: Failed to extract test details${NC}"
    rm -f "$TEMP_SUMMARY" "$TEMP_LEGACY"
    exit 2
fi

# Export variables for Python script
export RED GREEN YELLOW BOLD NC LIMIT TEMP_SUMMARY TEMP_LEGACY

# Parse and display using Python
python3 << 'PYEOF'
import json
import sys
import re

# Terminal colors from bash (passed via environment)
import os
RED = os.environ.get('RED', '')
GREEN = os.environ.get('GREEN', '')
YELLOW = os.environ.get('YELLOW', '')
BOLD = os.environ.get('BOLD', '')
NC = os.environ.get('NC', '')
LIMIT = int(os.environ.get('LIMIT', '0'))
TEMP_SUMMARY = os.environ.get('TEMP_SUMMARY', '')
TEMP_LEGACY = os.environ.get('TEMP_LEGACY', '')

# Read summary JSON from temp file
with open(TEMP_SUMMARY, 'r') as f:
    summary = json.load(f)

total = summary.get('totalTestCount', 0)
passed = summary.get('passedTests', 0)
failed = summary.get('failedTests', 0)
skipped = summary.get('skippedTests', 0)

# Overall summary with color
if failed == 0:
    print(f"{GREEN}✅ {passed}/{total} tests passed{NC}")
else:
    print(f"{RED}❌ {passed}/{total} tests passed, {failed} failed{NC}")

if skipped > 0:
    print(f"{YELLOW}⏭️  {skipped} tests skipped{NC}")

# Read legacy format from temp file
with open(TEMP_LEGACY, 'r') as f:
    legacy = json.load(f)

# Navigate to test failure summaries
failures_with_location = []
actions = legacy.get('actions', {}).get('_values', [])
for action in actions:
    result = action.get('actionResult', {})
    issues = result.get('issues', {})
    test_failures = issues.get('testFailureSummaries', {}).get('_values', [])

    for failure in test_failures:
        test_name = failure.get('testCaseName', {}).get('_value', 'unknown')
        message = failure.get('message', {}).get('_value', '')
        doc_loc = failure.get('documentLocationInCreatingWorkspace', {})
        url = doc_loc.get('url', {}).get('_value', '')

        # Parse the URL to extract file and line
        file_name = ''
        line_num = ''
        if url:
            # Extract file path (use raw string to avoid escape warnings)
            path_match = re.search(r'file://(.+?)#', url)
            if path_match:
                file_path = path_match.group(1)
                file_name = file_path.split('/')[-1]

            # Extract line number
            line_match = re.search(r'StartingLineNumber=(\d+)', url)
            if line_match:
                line_num = line_match.group(1)

        location = f"{file_name}:{line_num}" if file_name and line_num else "unknown location"

        # Extract just the test method name (remove class prefix if present)
        method_name = test_name.split('.')[-1] if '.' in test_name else test_name

        failures_with_location.append({
            'method': method_name,
            'location': location,
            'message': message
        })

# Display failed tests
if failures_with_location:
    print(f"\n{RED}{BOLD}Failed Tests:{NC}")

    # Apply limit if specified (0 = unlimited)
    display_failures = failures_with_location
    truncated = False
    if LIMIT > 0 and len(failures_with_location) > LIMIT:
        display_failures = failures_with_location[:LIMIT]
        truncated = True

    for f in display_failures:
        method = f['method']
        location = f['location']
        message = f['message']

        print(f"  {RED}•{NC} {method} ({location})")
        if message:
            # Truncate long failure messages
            if len(message) > 100:
                message = message[:97] + "..."
            print(f"    {message}")

    if truncated:
        print(f"\n{YELLOW}⚠️  Showing {LIMIT} of {len(failures_with_location)} failures (use --limit 0 to show all){NC}")

print("============================================================")

# Exit with appropriate code
sys.exit(1 if failed > 0 else 0)
PYEOF

SUMMARY_EXIT=$?

# Clean up temp files
rm -f "$TEMP_SUMMARY" "$TEMP_LEGACY"

# Return the summary exit code
exit $SUMMARY_EXIT
