#!/bin/bash
set -e

# Generate code coverage report from xcresult
cd ios/FamilyMedicalApp
xcrun xccov view --report --json test-results/TestResults.xcresult > test-results/coverage.json

# Enforce minimum coverage threshold
# Note: Will be increased to 90% as more application code is added
THRESHOLD=85

# Extract and display coverage with per-file breakdown
python3 << 'EOF'
import sys
import json

THRESHOLD = 85

# Load coverage data
with open('test-results/coverage.json') as f:
    data = json.load(f)

# Find FamilyMedicalApp.app target
app_target = next((t for t in data['targets'] if t['name'] == 'FamilyMedicalApp.app'), None)
if not app_target:
    print('Error: FamilyMedicalApp.app target not found', file=sys.stderr)
    sys.exit(1)

# Overall coverage
overall_coverage = app_target['lineCoverage'] * 100

# Per-file coverage
print("\n📊 Per-File Coverage Report")
print("=" * 80)
print(f"{'File':<60} {'Coverage':>10} {'Status':>8}")
print("-" * 80)

failed_files = []
for file_data in app_target['files']:
    file_path = file_data['path']
    # Extract just the filename for readability
    file_name = file_path.split('/')[-1]
    coverage = file_data['lineCoverage'] * 100

    # Determine pass/fail
    if coverage >= THRESHOLD:
        status = "✅ PASS"
    else:
        status = "❌ FAIL"
        failed_files.append((file_name, coverage))

    print(f"{file_name:<60} {coverage:>9.2f}% {status:>8}")

print("=" * 80)

# Overall summary
print(f"\n📈 Overall Coverage: {overall_coverage:.2f}%")
print(f"🎯 Required Minimum: {THRESHOLD}%")

# Use floor division to avoid rounding up
coverage_scaled = int(overall_coverage * 100)
threshold_scaled = THRESHOLD * 100

if coverage_scaled < threshold_scaled:
    print(f"\n❌ Coverage check FAILED: {overall_coverage:.2f}% is below the required {THRESHOLD}%")
    if failed_files:
        print(f"\n📋 Files below threshold ({len(failed_files)}):")
        for file_name, coverage in sorted(failed_files, key=lambda x: x[1]):
            print(f"  • {file_name}: {coverage:.2f}%")
    sys.exit(1)
else:
    print(f"\n✅ Coverage check PASSED: {overall_coverage:.2f}% meets or exceeds {THRESHOLD}%")
    if failed_files:
        print(f"\n⚠️  Warning: {len(failed_files)} file(s) below threshold but overall coverage passes:")
        for file_name, coverage in sorted(failed_files, key=lambda x: x[1]):
            print(f"  • {file_name}: {coverage:.2f}%")
    sys.exit(0)
EOF
