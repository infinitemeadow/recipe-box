#!/bin/bash
# Generates Resources/AppIcon.icns from the kanji renderer.
# Usage: ./scripts/make-icon.sh   (run from the app/ directory)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET" "$ROOT/Resources"

swift "$ROOT/scripts/render_icon.swift" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$ROOT/Resources/AppIcon.icns"

echo "✓ Wrote $ROOT/Resources/AppIcon.icns"
