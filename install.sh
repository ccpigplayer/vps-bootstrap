#!/usr/bin/env bash
set -euo pipefail

TMP_SCRIPT="/tmp/vps-bootstrap.sh"
SRC_URL="https://raw.githubusercontent.com/ccpigplayer/vps-bootstrap/main/server-bootstrap.sh"

download() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$SRC_URL" -o "$TMP_SCRIPT"
    return 0
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO "$TMP_SCRIPT" "$SRC_URL"
    return 0
  fi

  echo "[ERROR] 既没有 curl 也没有 wget，无法下载脚本。" >&2
  echo "请先安装 curl 或 wget 后重试。" >&2
  exit 1
}

download
chmod +x "$TMP_SCRIPT"

if [[ ! -r /dev/tty ]]; then
  echo "[ERROR] 当前环境没有可用终端（/dev/tty），无法进行交互式初始化。" >&2
  echo "请先下载脚本后，在可交互终端中执行：bash $TMP_SCRIPT" >&2
  exit 1
fi

if command -v sudo >/dev/null 2>&1; then
  sudo bash "$TMP_SCRIPT" "$@" </dev/tty
else
  bash "$TMP_SCRIPT" "$@" </dev/tty
fi
