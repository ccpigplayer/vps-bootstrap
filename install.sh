#!/usr/bin/env bash
set -euo pipefail

TMP_SCRIPT="/tmp/vps-bootstrap.sh"
SRC_URL="https://raw.githubusercontent.com/ccpigplayer/vps-bootstrap/main/server-bootstrap.sh"

curl -fsSL "$SRC_URL" -o "$TMP_SCRIPT"
chmod +x "$TMP_SCRIPT"

if command -v sudo >/dev/null 2>&1; then
  sudo bash "$TMP_SCRIPT" "$@"
else
  bash "$TMP_SCRIPT" "$@"
fi
