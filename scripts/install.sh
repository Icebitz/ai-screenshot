#!/bin/bash
set -e

APP_NAME="AiShot.app"
INSTALL_DIR="/Applications"
TMP_DIR="$(mktemp -d)"
ZIP_URL="https://github.com/Icebitz/ai-screenshot/releases/download/0.1.0/AiShot.zip"

echo "🚀 Installing AiShot..."

# macOS only
if [[ "$(uname)" != "Darwin" ]]; then
  echo "❌ macOS only."
  exit 1
fi

# Dependencies
for cmd in curl unzip; do
  if ! command -v "$cmd" >/dev/null; then
    echo "❌ Required command not found: $cmd"
    exit 1
  fi
done

echo "⬇️ Downloading AiShot..."
curl -fL "$ZIP_URL" -o "$TMP_DIR/AiShot.zip"

# Quick sanity check (avoid 404 HTML downloads)
if [[ $(wc -c < "$TMP_DIR/AiShot.zip") -lt 100000 ]]; then
  echo "❌ Downloaded file is too small. Check release asset."
  exit 1
fi

echo "📦 Extracting..."
unzip -q "$TMP_DIR/AiShot.zip" -d "$TMP_DIR"

# Find the app (robust against folder nesting)
APP_PATH="$(find "$TMP_DIR" -maxdepth 3 -name "$APP_NAME" -type d -print -quit)"

if [[ -z "$APP_PATH" ]]; then
  echo "❌ AiShot.app not found in ZIP."
  exit 1
fi

# Remove old version
if [[ -d "$INSTALL_DIR/$APP_NAME" ]]; then
  echo "🗑 Removing existing installation..."
  sudo rm -rf "$INSTALL_DIR/$APP_NAME"
fi

# Install
echo "📁 Installing to /Applications..."
sudo cp -R "$APP_PATH" "$INSTALL_DIR"

# Remove Gatekeeper quarantine (ZIP downloads add this)
echo "🔓 Removing Gatekeeper quarantine..."
sudo xattr -dr com.apple.quarantine "$INSTALL_DIR/$APP_NAME" || true

# Permissions
sudo chmod -R 755 "$INSTALL_DIR/$APP_NAME"

echo "✅ AiShot installed successfully!"
open "$INSTALL_DIR/$APP_NAME"
