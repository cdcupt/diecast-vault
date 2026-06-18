#!/usr/bin/env bash
# Regenerate the bundled sample USDZ from the procedural Model I/O source.
#
#   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer tools/usdz-gen/build.sh
#
# Emits app/Sources/Resources/Models3D/SampleCar.usdz. Model I/O exports binary
# USD (.usdc); `usdzip` (shipped in the Xcode SDK) wraps it into the .usdz the
# app bundles. Idempotent: safe to re-run after editing generate.swift.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="$ROOT/app/Sources/Resources/Models3D"
USDC="$OUT_DIR/SampleCar.usdc"
USDZ="$OUT_DIR/SampleCar.usdz"

mkdir -p "$OUT_DIR"
swift "$ROOT/tools/usdz-gen/generate.swift" "$USDC"
rm -f "$USDZ"
# usdzip requires the asset paths to be reachable; cd into the dir so the
# archived path is just the bare filename.
( cd "$OUT_DIR" && usdzip "SampleCar.usdz" "SampleCar.usdc" )
rm -f "$USDC"
echo "Bundled $USDZ"
