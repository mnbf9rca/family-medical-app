#!/usr/bin/env bash
# Block XCTest usage in unit test files — project convention is Swift Testing
# (@Suite/@Test/#expect). UI tests under FamilyMedicalAppUITests/ may still use
# XCTest because UI testing support in Swift Testing is limited.
set -euo pipefail

violations=()
for file in "$@"; do
    if grep -q -E "^import XCTest|: XCTestCase" "$file"; then
        violations+=("$file")
    fi
done

if [ ${#violations[@]} -gt 0 ]; then
    echo "Error: The following unit test files use XCTest, but this project uses Swift Testing:"
    printf '  %s\n' "${violations[@]}"
    echo ""
    echo "Convert to Swift Testing:"
    echo "  import Testing"
    echo "  @Suite(\"...\") struct MyTests { @Test func foo() { #expect(...) } }"
    echo ""
    echo "UI tests under FamilyMedicalAppUITests/ are exempt — they may continue to use XCTest."
    exit 1
fi
