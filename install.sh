#!/bin/bash
# Installs cgp-ai into ~/.cgp-ai/app and starts the setup.
# It downloads a tagged release from GitHub, links the command into
# ~/.local/bin and then runs `cgp-ai setup`, which shows its plan and
# asks before it installs anything. Running it again updates cgp-ai.
set -eu

REPO=crypto-gameplan/cgp-ai
REF=${CGP_AI_REF:-}
DEST="$HOME/.cgp-ai/app"
BIN_DIR="$HOME/.local/bin"

[ "$(uname -s)" = "Darwin" ] || { echo "cgp-ai runs on macOS for now. Windows follows." >&2; exit 1; }

if [ -z "$REF" ]; then
  REF=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)
  [ -n "$REF" ] || { echo "Could not find a cgp-ai release." >&2; exit 1; }
fi

echo "Downloading cgp-ai $REF ..."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "https://codeload.github.com/$REPO/tar.gz/$REF" | tar -xz -C "$tmp"
src=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n 1)
[ -f "$src/manifest.json" ] || { echo "The download does not look like cgp-ai." >&2; exit 1; }

rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")" "$BIN_DIR"
mv "$src" "$DEST"
ln -sf "$DEST/bin/cgp-ai" "$BIN_DIR/cgp-ai"

# New terminal windows should find cgp-ai and the tools installed into ~/.local/bin.
if ! grep -qs '\.local/bin' "$HOME/.zprofile" "$HOME/.zshrc"; then
  # shellcheck disable=SC2016 # the line is written literally, for the shell to expand later
  printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.zprofile"
fi

echo "cgp-ai $REF installed. Starting the setup ..."
exec "$DEST/bin/cgp-ai" setup "$@"
