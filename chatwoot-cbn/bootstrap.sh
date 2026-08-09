#!/bin/bash
set -euo pipefail

ROOT="$(pwd)"
TMP_DIR="$(mktemp -d)"
PATCH_DIR="$TMP_DIR/cbn-patches"
SRC_DIR="$TMP_DIR/chatwoot"

mkdir -p "$PATCH_DIR"
cp -a "$ROOT/patches/." "$PATCH_DIR/"

echo "[CBN] Cloning Chatwoot v4.16.2..."
git clone --depth 1 --branch v4.16.2 https://github.com/chatwoot/chatwoot.git "$SRC_DIR"

# Replace bootstrap marker files with the exact official Chatwoot source.
find "$ROOT" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp -a "$SRC_DIR/." "$ROOT/"
rm -rf "$ROOT/.git"

mkdir -p "$ROOT/config/initializers"
cp "$PATCH_DIR/cbn_whatsapp_agent_name.rb" "$ROOT/config/initializers/cbn_whatsapp_agent_name.rb"
CHATWOOT_ROOT="$ROOT" ruby "$PATCH_DIR/patch_settings.rb"

echo "[CBN] Installing Ruby dependencies..."
gem install bundler -v 2.5.16 --no-document
bundle config set without 'development test'
bundle install -j 4 -r 3

echo "[CBN] Installing frontend dependencies..."
pnpm install --frozen-lockfile

echo "[CBN] Bootstrap completed."
