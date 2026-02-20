#!/usr/bin/env bash
set -euo pipefail

TMP_SCRIPT="/tmp/vps-bootstrap.sh"
SRC_URL="https://raw.githubusercontent.com/ccpigplayer/vps-bootstrap/main/server-bootstrap.sh"

C_RESET='\033[0m'; C_BOLD='\033[1m'; C_BLUE='\033[1;34m'; C_GREEN='\033[1;32m'; C_YELLOW='\033[1;33m'; C_RED='\033[1;31m'; C_CYAN='\033[1;36m'

line(){ echo -e "${C_CYAN}============================================================${C_RESET}"; }
info(){ echo -e "${C_CYAN}•${C_RESET} $*"; }
ok(){ echo -e "${C_GREEN}✔${C_RESET} $*"; }
warn(){ echo -e "${C_YELLOW}⚠${C_RESET} $*"; }
err(){ echo -e "${C_RED}✖${C_RESET} $*" >&2; }

ui_title(){
  line
  echo -e "${C_BOLD}${C_BLUE}VPS Bootstrap Pro Installer${C_RESET}"
  echo -e "${C_CYAN}一键下载安装并进入交互式初始化${C_RESET}"
  line
}

cleanup(){
  [[ -f "$TMP_SCRIPT" ]] && chmod +x "$TMP_SCRIPT" >/dev/null 2>&1 || true
}
trap cleanup EXIT

download(){
  step_msg="下载初始化脚本"
  info "$step_msg"

  if command -v curl >/dev/null 2>&1; then
    if curl -fL --progress-bar "$SRC_URL" -o "$TMP_SCRIPT"; then
      ok "下载完成（curl）"
      return 0
    fi
    warn "curl 下载失败，尝试 wget..."
  fi

  if command -v wget >/dev/null 2>&1; then
    if wget --show-progress -qO "$TMP_SCRIPT" "$SRC_URL"; then
      ok "下载完成（wget）"
      return 0
    fi
  fi

  err "下载失败：请检查网络或 GitHub 访问。"
  exit 1
}

run_bootstrap(){
  if [[ ! -r /dev/tty ]]; then
    err "当前环境没有可用终端（/dev/tty），无法进行交互式初始化。"
    echo "请先下载脚本后，在可交互终端中执行：bash $TMP_SCRIPT" >&2
    exit 1
  fi

  line
  info "即将启动交互式初始化"
  line

  if command -v sudo >/dev/null 2>&1; then
    sudo bash "$TMP_SCRIPT" "$@" </dev/tty
  else
    bash "$TMP_SCRIPT" "$@" </dev/tty
  fi
}

main(){
  ui_title
  download
  run_bootstrap "$@"
}

main "$@"
