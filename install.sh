#!/bin/bash
# Recipe Box — one-time setup for a new Mac.
# Prereqs: GitHub CLI installed & signed in  (brew install gh && gh auth login).
# Run:  bash <(curl -fsSL https://raw.githubusercontent.com/infinitemeadow/recipe-box/main/install.sh)
set -euo pipefail

OWNER="infinitemeadow"
APP_REPO="$OWNER/recipe-box"
RECIPES_REPO="$OWNER/recipes"
RECIPES_DIR="$HOME/Recipes"

echo "🍳 Recipe Box setup"

# 1) GitHub CLI present + authenticated
if ! command -v gh >/dev/null 2>&1; then
  echo "✗ GitHub CLI not found. Install it, then re-run this:"
  echo "    brew install gh        (or download from https://cli.github.com)"
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "✗ Not signed in to GitHub. Run this, then re-run this installer:"
  echo "    gh auth login          (GitHub.com → HTTPS → login with a web browser)"
  exit 1
fi

# 2) Shared recipes (private repo) → ~/Recipes
if [ -d "$RECIPES_DIR/.git" ]; then
  echo "• Recipes already set up — pulling latest…"
  git -C "$RECIPES_DIR" pull --rebase --autostash || true
else
  if [ -e "$RECIPES_DIR" ] && [ -n "$(ls -A "$RECIPES_DIR" 2>/dev/null)" ]; then
    echo "✗ $RECIPES_DIR already exists and isn't empty. Move it aside, then re-run."
    exit 1
  fi
  rm -rf "$RECIPES_DIR"
  echo "• Cloning shared recipes → $RECIPES_DIR"
  gh repo clone "$RECIPES_REPO" "$RECIPES_DIR"
fi

# 3) Install the latest app release
echo "• Downloading the latest Recipe Box…"
TMP="$(mktemp -d)"
URL="$(gh api "repos/$APP_REPO/releases/latest" -q '.assets[] | select(.name|endswith(".zip")) | .browser_download_url')"
curl -fsSL "$URL" -o "$TMP/app.zip"
ditto -x -k "$TMP/app.zip" "$TMP"
[ -d "$TMP/RecipeBox.app" ] || { echo "✗ Download looked malformed."; exit 1; }
rm -rf /Applications/RecipeBox.app
cp -R "$TMP/RecipeBox.app" /Applications/RecipeBox.app
xattr -dr com.apple.quarantine /Applications/RecipeBox.app 2>/dev/null || true
codesign --force --sign - /Applications/RecipeBox.app >/dev/null 2>&1 || true
rm -rf "$TMP"

open /Applications/RecipeBox.app
echo "✓ Done — Recipe Box is in your Applications, shared recipes are in ~/Recipes."
echo "  If macOS blocks the first launch: right-click the app → Open."
echo "  If a keychain prompt appears (git wanting github.com): click Always Allow."
