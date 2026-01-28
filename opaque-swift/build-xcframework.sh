#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# Build for all iOS targets
echo "Building for iOS device (aarch64)..."
cargo build --release --target aarch64-apple-ios

echo "Building for iOS simulator (aarch64)..."
cargo build --release --target aarch64-apple-ios-sim

echo "Building for iOS simulator (x86_64)..."
cargo build --release --target x86_64-apple-ios

# Generate Swift bindings
echo "Generating Swift bindings..."
mkdir -p generated
cargo run --bin uniffi-bindgen generate \
    --library target/aarch64-apple-ios/release/libopaque_swift.a \
    --language swift \
    --out-dir generated

# Create fat library for simulators (combines arm64 and x86_64)
echo "Creating fat library for simulators..."
mkdir -p target/ios-simulator-universal/release
lipo -create \
    target/aarch64-apple-ios-sim/release/libopaque_swift.a \
    target/x86_64-apple-ios/release/libopaque_swift.a \
    -output target/ios-simulator-universal/release/libopaque_swift.a

# Create XCFramework (library only, no headers to avoid conflicts)
echo "Creating XCFramework..."
rm -rf OpaqueSwift.xcframework

xcodebuild -create-xcframework \
    -library target/aarch64-apple-ios/release/libopaque_swift.a \
    -library target/ios-simulator-universal/release/libopaque_swift.a \
    -output OpaqueSwift.xcframework

# Set up the FFI module for Swift Package
echo "Setting up FFI module..."
mkdir -p Sources/OpaqueSwiftFFI
cp generated/opaque_swiftFFI.h Sources/OpaqueSwiftFFI/
cat > Sources/OpaqueSwiftFFI/module.modulemap << 'EOF'
module opaque_swiftFFI {
    header "opaque_swiftFFI.h"
    link "opaque_swift"
    export *
}
EOF

# Copy Swift bindings
mkdir -p Sources/OpaqueSwift
cp generated/opaque_swift.swift Sources/OpaqueSwift/

echo "Done! OpaqueSwift.xcframework created"
echo ""
echo "Contents:"
ls -la OpaqueSwift.xcframework/
