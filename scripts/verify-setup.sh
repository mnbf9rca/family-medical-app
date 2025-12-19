#!/bin/bash
# Verify iOS development environment setup

set -e

echo "🔍 Verifying iOS Development Environment..."
echo ""

# Track if any checks fail
FAILED=0

# Check macOS version
echo "📱 macOS Version:"
sw_vers -productVersion
echo ""

# Check Xcode installation
echo "🛠️  Xcode:"
if command -v xcodebuild &> /dev/null; then
    xcodebuild -version
    echo "✅ Xcode installed"
else
    echo "❌ Xcode not found - install from App Store"
    FAILED=1
fi
echo ""

# Check Swift
echo "🔷 Swift:"
if command -v swift &> /dev/null; then
    swift --version
    echo "✅ Swift installed"
else
    echo "❌ Swift not found - install Xcode command line tools"
    FAILED=1
fi
echo ""

# Check Command Line Tools
echo "🔧 Command Line Tools:"
if xcode-select -p &> /dev/null; then
    echo "Path: $(xcode-select -p)"
    echo "✅ Command line tools configured"
else
    echo "❌ Command line tools not configured"
    echo "Run: xcode-select --install"
    FAILED=1
fi
echo ""

# Check optional tools
echo "🧰 Optional Tools:"

if command -v brew &> /dev/null; then
    echo "✅ Homebrew installed ($(brew --version | head -n1))"
else
    echo "⚠️  Homebrew not installed (optional but recommended)"
fi

if command -v swiftlint &> /dev/null; then
    echo "✅ SwiftLint installed ($(swiftlint version))"
else
    echo "⚠️  SwiftLint not installed (optional)"
fi

if command -v swiftformat &> /dev/null; then
    echo "✅ SwiftFormat installed"
else
    echo "⚠️  SwiftFormat not installed (optional)"
fi

if command -v gh &> /dev/null; then
    echo "✅ GitHub CLI installed ($(gh --version | head -n1))"
else
    echo "⚠️  GitHub CLI not installed (optional)"
fi

echo ""

# Check if we can list simulators (requires Xcode to be properly set up)
echo "📲 iOS Simulators:"
if xcrun simctl list devices available 2>/dev/null | head -n 5; then
    echo "✅ Simulators available"
else
    echo "⚠️  Could not list simulators - Xcode may need to finish installing"
fi

echo ""
echo "════════════════════════════════════════"

if [ $FAILED -eq 0 ]; then
    echo "✅ All required tools installed!"
    echo ""
    echo "Next steps:"
    echo "1. Review SETUP.md for Swift/SwiftUI learning resources"
    echo "2. Start with issue #3 (Set up iOS project structure)"
    echo "3. Follow Phase 1 issues for implementation"
else
    echo "❌ Some required tools are missing"
    echo "Please refer to SETUP.md for installation instructions"
    exit 1
fi
