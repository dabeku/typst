#!/usr/bin/env bash
# Builds the iOS static libraries, regenerates the Swift UniFFI bindings, and
# packages both into swift/Typst/TypstFFI.xcframework + swift/Typst/Sources —
# a local Swift Package ready to add to an Xcode project.
set -euo pipefail
cd "$(dirname "$0")/.."

TARGETS=(aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios)
for t in "${TARGETS[@]}"; do
  rustup target add "$t" >/dev/null
done

echo "==> Building release static libs for ${TARGETS[*]}"
cargo build --release --lib "${TARGETS[@]/#/--target=}"

echo "==> Regenerating Swift bindings"
cargo build --lib
rm -rf bindings/swift
cargo run --bin uniffi-bindgen -- generate \
  --library target/debug/libtypst_uniffi.dylib \
  --language swift --out-dir bindings/swift

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "==> Assembling headers"
HEADERS_DIR="$WORK_DIR/Headers"
mkdir -p "$HEADERS_DIR"
cp bindings/swift/typst_uniffiFFI.h "$HEADERS_DIR/"
cp bindings/swift/typst_uniffiFFI.modulemap "$HEADERS_DIR/module.modulemap"

echo "==> Combining simulator archs (arm64 + x86_64) into one fat lib"
SIM_LIB="$WORK_DIR/libtypst_uniffi_sim.a"
lipo -create \
  target/aarch64-apple-ios-sim/release/libtypst_uniffi.a \
  target/x86_64-apple-ios/release/libtypst_uniffi.a \
  -output "$SIM_LIB"

echo "==> Creating XCFramework"
XCFRAMEWORK_OUT="swift/Typst/TypstFFI.xcframework"
rm -rf "$XCFRAMEWORK_OUT"
xcodebuild -create-xcframework \
  -library target/aarch64-apple-ios/release/libtypst_uniffi.a -headers "$HEADERS_DIR" \
  -library "$SIM_LIB" -headers "$HEADERS_DIR" \
  -output "$XCFRAMEWORK_OUT"

echo "==> Copying Swift bindings into the package"
mkdir -p swift/Typst/Sources/Typst
cp bindings/swift/typst_uniffi.swift swift/Typst/Sources/Typst/

echo "==> Done: swift/Typst is a local Swift Package, ${XCFRAMEWORK_OUT} is the compiled core"
