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

# Create XCFramework
echo "Creating XCFramework..."
rm -rf OpaqueSwift.xcframework

# Create module maps for the headers
mkdir -p target/aarch64-apple-ios/release/include
mkdir -p target/ios-simulator-universal/release/include

cp generated/opaque_swiftFFI.h target/aarch64-apple-ios/release/include/
cp generated/opaque_swiftFFI.h target/ios-simulator-universal/release/include/

cat > target/aarch64-apple-ios/release/include/module.modulemap << 'EOF'
module opaque_swiftFFI {
    header "opaque_swiftFFI.h"
    export *
}
EOF

cp target/aarch64-apple-ios/release/include/module.modulemap target/ios-simulator-universal/release/include/

xcodebuild -create-xcframework \
    -library target/aarch64-apple-ios/release/libopaque_swift.a \
    -headers target/aarch64-apple-ios/release/include \
    -library target/ios-simulator-universal/release/libopaque_swift.a \
    -headers target/ios-simulator-universal/release/include \
    -output OpaqueSwift.xcframework

echo "Done! OpaqueSwift.xcframework created"
echo ""
echo "Contents:"
ls -la OpaqueSwift.xcframework/
