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

# Check for xcpretty (optional but recommended for cleaner output)
XCPRETTY_AVAILABLE=false
if command -v xcpretty >/dev/null 2>&1; then
    XCPRETTY_AVAILABLE=true
fi

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
            if [[ $# -lt 2 || -z "$2" || "$2" == -* ]]; then
                echo "Error: --limit requires a non-negative integer argument"
                exit 1
            fi
            LIMIT="$2"
            shift 2
            ;;
        --destination)
            if [[ $# -lt 2 || -z "$2" || "$2" == -* ]]; then
                echo "Error: --destination requires a destination argument"
                exit 1
            fi
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

# Validate --limit is a non-negative integer
if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
    echo "Error: --limit must be a non-negative integer, got: $LIMIT"
    exit 1
fi

# Apply default destination if not set
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=26.2}"

# Capture start time for duration tracking
START_TIME=$(date +%s)

# Helper function to print duration
print_duration() {
    local END_TIME
    END_TIME=$(date +%s)
    local DURATION=$((END_TIME - START_TIME))
    local MINUTES=$((DURATION / 60))
    local SECONDS=$((DURATION % 60))
    echo "⏱️  Duration: ${MINUTES}m ${SECONDS}s"
}

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

# Extract device name from destination (e.g., "iPhone 17 Pro" from "platform=iOS Simulator,name=iPhone 17 Pro")
DEVICE_NAME=$(echo "$DESTINATION" | sed -n 's/.*name=\([^,]*\).*/\1/p')

# Find UDID for the device from simctl list
if [ -n "$DEVICE_NAME" ]; then
  # Match exact device name with " (" suffix to avoid "iPhone 17 Pro" matching "iPhone 17 Pro Max"
  # Uses last match since devices are listed oldest iOS first, newest last
  UDID=$(xcrun simctl list devices available 2>/dev/null | grep -F "$DEVICE_NAME (" | tail -1 | sed 's/.*(\([A-F0-9-]*\)).*/\1/' || echo "")
fi

# If still no UDID, try reading from simulator preferences (works when simulator was previously launched)
if [ -z "$UDID" ]; then
  UDID=$(defaults read com.apple.iphonesimulator CurrentDeviceUDID 2>/dev/null || echo "")
fi

if [ -n "$UDID" ]; then
  /usr/libexec/PlistBuddy -c "Set :DevicePreferences:$UDID:ConnectHardwareKeyboard false" \
    ~/Library/Preferences/com.apple.iphonesimulator.plist 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :DevicePreferences:$UDID:ConnectHardwareKeyboard bool false" \
    ~/Library/Preferences/com.apple.iphonesimulator.plist
  echo "  ✓ Hardware keyboard disabled for simulator $UDID ($DEVICE_NAME)"
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
    "${TEST_CMD[@]}" > "$TEMP_OUTPUT" 2>&1
    BUILD_EXIT_CODE=$?

    # Check if xcresult exists (indicates tests ran, even if some failed)
    if [[ ! -d "test-results/TestResults.xcresult" ]]; then
        # Build failed before tests could run
        echo "${RED}${BOLD}BUILD FAILED${NC} (exit code: $BUILD_EXIT_CODE)"
        echo ""
        echo "${BOLD}Build Output:${NC}"
        cat "$TEMP_OUTPUT"
        rm -f "$TEMP_OUTPUT"
        print_duration
        exit 2
    fi
    rm -f "$TEMP_OUTPUT"
else
    # Show output so user can see progress (default)
    # Use xcpretty if available for cleaner output, otherwise raw xcodebuild
    if [[ "$XCPRETTY_AVAILABLE" == "true" ]]; then
        "${TEST_CMD[@]}" 2>&1 | xcpretty || true
    else
        echo "${YELLOW}💡 Tip: Install xcpretty for cleaner output (gem install xcpretty)${NC}"
        "${TEST_CMD[@]}" || true
    fi

    # Check if xcresult exists (indicates tests ran, even if some failed)
    if [[ ! -d "test-results/TestResults.xcresult" ]]; then
        # Build failed before tests could run
        echo "${RED}${BOLD}BUILD FAILED${NC}"
        print_duration
        exit 2
    fi
fi
echo "✅ Tests completed"

# Parse and display test summary
echo ""
echo "${BOLD}Test Results${NC}"
echo "============================================================"

# Get test counts from summary - save to temp file
TEMP_SUMMARY=$(mktemp)
TEMP_LEGACY=$(mktemp)

# Ensure temp files are cleaned up on exit (even if script fails)
trap 'rm -f "$TEMP_SUMMARY" "$TEMP_LEGACY"' EXIT

if ! xcrun xcresulttool get test-results summary --path test-results/TestResults.xcresult --compact > "$TEMP_SUMMARY" 2>&1; then
    echo "${RED}${BOLD}ERROR: Failed to extract test summary${NC}"
    print_duration
    exit 2
fi

# Get failure details from legacy format - save to temp file
if ! xcrun xcresulttool get --path test-results/TestResults.xcresult --format json --legacy > "$TEMP_LEGACY" 2>&1; then
    echo "${RED}${BOLD}ERROR: Failed to extract test details${NC}"
    print_duration
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
try:
    LIMIT = int(os.environ.get('LIMIT', '0'))
except ValueError:
    print(f"{YELLOW}WARNING: Invalid LIMIT value; defaulting to 0{NC}", file=sys.stderr)
    LIMIT = 0
TEMP_SUMMARY = os.environ.get('TEMP_SUMMARY', '')
TEMP_LEGACY = os.environ.get('TEMP_LEGACY', '')

# Read summary JSON from temp file
try:
    with open(TEMP_SUMMARY, 'r', encoding='utf-8') as f:
        summary = json.load(f)
except (IOError, OSError) as e:
    print(f"{RED}{BOLD}ERROR: Failed to read test summary file{NC}", file=sys.stderr)
    print(f"  File: {TEMP_SUMMARY}", file=sys.stderr)
    print(f"  Error: {e}", file=sys.stderr)
    sys.exit(2)
except json.JSONDecodeError as e:
    print(f"{RED}{BOLD}ERROR: Failed to parse test summary JSON{NC}", file=sys.stderr)
    print(f"  File: {TEMP_SUMMARY}", file=sys.stderr)
    print(f"  Error: {e}", file=sys.stderr)
    sys.exit(2)

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
try:
    with open(TEMP_LEGACY, 'r', encoding='utf-8') as f:
        legacy = json.load(f)
except (IOError, OSError) as e:
    print(f"{RED}{BOLD}ERROR: Failed to read test details file{NC}", file=sys.stderr)
    print(f"  File: {TEMP_LEGACY}", file=sys.stderr)
    print(f"  Error: {e}", file=sys.stderr)
    sys.exit(2)
except json.JSONDecodeError as e:
    print(f"{RED}{BOLD}ERROR: Failed to parse test details JSON{NC}", file=sys.stderr)
    print(f"  File: {TEMP_LEGACY}", file=sys.stderr)
    print(f"  Error: {e}", file=sys.stderr)
    sys.exit(2)

# Navigate to test failure summaries
failures_with_location = []
try:
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
                path_match = re.search(r'^file://([^#]+)', url)
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
except (KeyError, AttributeError, TypeError) as e:
    print(f"{YELLOW}⚠️  Warning: Failed to parse some failure details (JSON structure unexpected){NC}", file=sys.stderr)
    print(f"  Error: {e}", file=sys.stderr)
    # Continue with whatever failures we managed to parse

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

# Print duration and return the summary exit code (temp files cleaned by trap)
print_duration
exit $SUMMARY_EXIT
