#!/bin/bash
# Cut a new release: build the versioned .app, zip it, publish a GitHub Release.
# The installed app's auto-updater picks it up. Usage: ./scripts/release.sh 0.2.0
set -euo pipefail

VERSION="${1:?usage: release.sh X.Y.Z}"
REPO="infinitemeadow/recipe-box"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "› Building v$VERSION…"
./scripts/package.sh "$VERSION"

ZIP="dist/RecipeBox-$VERSION.zip"
rm -f "$ZIP"
# ditto makes a proper macOS archive (preserves the bundle + resource forks).
ditto -c -k --sequesterRsrc --keepParent dist/RecipeBox.app "$ZIP"

echo "› Publishing GitHub release v$VERSION…"
gh release create "v$VERSION" "$ZIP" \
    --repo "$REPO" \
    --title "Recipe Box v$VERSION" \
    --notes "Automated release of Recipe Box v$VERSION." \
    --target main

echo "✓ Released v$VERSION — installed apps will offer the update on next launch."
