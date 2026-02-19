#!/usr/bin/env bash
set -euo pipefail

# ==============================================
#  VPS Bootstrap Pro (No-Firewall Edition)
#  - 美化交互
#  - 两阶段 SSH 安全切换（防锁死）
#  - 智能验证流程 + 审计日志
#  - Ubuntu/Debian + RHEL系基础支持
# ==============================================

SSH_PORT="22"
ENABLE_KEY_ONLY="true"
TARGET_USER=""
PUBKEY=""
TIMEZONE="Asia/Shanghai"
NEW_HOSTNAME=""

LOG_DIR="/var/log/vps-bootstrap"
RUN_ID="$(date +%F-%H%M%S)"
LOG_FILE="$LOG_DIR/bootstrap-$RUN_ID.log"
SUMMARY_FILE="$LOG_DIR/bootstrap-summary-$RUN_ID.txt"

OS_ID=""
OS_VER=""
PKG_MGR=""
SSH_SERVICE="sshd"

C_RESET='\033[0m'; C_BOLD='\033[1m'; C_BLUE='\033[1;34m'; C_GREEN='\033[1;32m'; C_YELLOW='\033[1;33m'; C_RED='\033[1;31m'; C_CYAN='\033[1;36m'

ui_line(){ echo -e "${C_CYAN}============================================================${C_RESET}"; }
ui_title(){ ui_line; echo -e "${C_BOLD}${C_BLUE}VPS Bootstrap Pro${C_RESET}"; echo -e "${C_CYAN}安全初始化（无防火墙版）${C_RESET}"; ui_line; }
step(){ echo -e "\n${C_BOLD}${C_BLUE}▶ $*${C_RESET}"; }
ok(){ echo -e "${C_GREEN}✔ $*${C_RESET}"; }
warn(){ echo -e "${C_YELLOW}⚠ $*${C_RESET}"; }
err(){ echo -e "${C_RED}✖ $*${C_RESET}"; }
info(){ echo -e "${C_CYAN}• $*${C_RESET}"; }

need_root(){ [[ $EUID -eq 0 ]] || { err "请使用 root 或 sudo 执行。"; exit 1; }; }
backup_file(){ local f="$1"; cp "$f" "${f}.bak.$(date +%F-%H%M%S)"; }
restart_ssh(){ systemctl restart "$SSH_SERVICE"; }

init_logging(){
  mkdir -p "$LOG_DIR"; touch "$LOG_FILE"; chmod 600 "$LOG_FILE"
  exec > >(tee -a "$LOG_FILE") 2>&1
  info "日志文件: $LOG_FILE"
}

detect_os(){
  step "检测系统环境"
  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_VER="${VERSION_ID:-unknown}"
  else
    err "无法识别系统（缺少 /etc/os-release）"
    exit 1
  fi

  case "$OS_ID" in
    ubuntu|debian)
      PKG_MGR="apt"
      SSH_SERVICE="ssh"
      ;;
    rocky|almalinux|centos|rhel|fedora)
      if command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
      elif command -v yum >/dev/null 2>&1; then
        PKG_MGR="yum"
      else
        err "RHEL 系系统未找到 dnf/yum"
        exit 1
      fi
      SSH_SERVICE="sshd"
      ;;
    *)
      err "当前暂不支持系统: $OS_ID $OS_VER"
      err "目前支持: Ubuntu/Debian, Rocky/Alma/CentOS/RHEL/Fedora"
      exit 1
      ;;
  esac
  ok "检测到系统: $OS_ID $OS_VER (包管理器: $PKG_MGR, SSH服务: $SSH_SERVICE)"
}

ask_timezone(){
  step "选择时区"
  cat <<'EOF'
  1) 上海       Asia/Shanghai  (默认)
  2) 香港       Asia/Hong_Kong
  3) 新加坡     Asia/Singapore
  4) 韩国首尔   Asia/Seoul
  5) 美西洛杉矶 America/Los_Angeles
  6) 东京       Asia/Tokyo
EOF
  read -r -p "输入编号 [1-6] (默认1): " tz_choice
  case "${tz_choice:-1}" in
    1) TIMEZONE="Asia/Shanghai" ;;
    2) TIMEZONE="Asia/Hong_Kong" ;;
    3) TIMEZONE="Asia/Singapore" ;;
    4) TIMEZONE="Asia/Seoul" ;;
    5) TIMEZONE="America/Los_Angeles" ;;
    6) TIMEZONE="Asia/Tokyo" ;;
    *) warn "输入无效，使用默认上海"; TIMEZONE="Asia/Shanghai" ;;
  esac
  ok "时区设置为: $TIMEZONE"
}

ask_hostname(){
  step "主机名（Hostname）设置"
  local current_host
  current_host="$(hostnamectl --static 2>/dev/null || hostname)"
  info "当前主机名: $current_host"
  read -r -p "请输入新主机名（留空=不修改）: " NEW_HOSTNAME

  if [[ -z "${NEW_HOSTNAME:-}" ]]; then
    info "保持当前主机名不变"
    return 0
  fi

  if [[ ! "$NEW_HOSTNAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]]; then
    err "主机名不合法。仅支持字母/数字/中横线，长度 1-63，且不能以中横线开头。"
    exit 1
  fi

  ok "将主机名设置为: $NEW_HOSTNAME"
}

ask_ssh_port(){
  step "配置 SSH 端口"
  read -r -p "请输入新的 SSH 端口（1024-65535，回车默认22）: " input_port
  if [[ -z "${input_port:-}" ]]; then
    SSH_PORT="22"
  else
    if ! [[ "$input_port" =~ ^[0-9]+$ ]] || (( input_port < 1024 || input_port > 65535 )); then
      err "端口无效，必须是 1024-65535 的数字。"; exit 1
    fi
    SSH_PORT="$input_port"
  fi
  ok "SSH 端口将设置为: $SSH_PORT"
}

ask_key_only(){
  step "登录方式策略"
  cat <<'EOF'
  1) 仅秘钥登录（推荐，更安全）
  2) 保留密码登录（兼容优先）
EOF
  read -r -p "输入编号 [1-2] (默认1): " key_choice
  case "${key_choice:-1}" in
    1) ENABLE_KEY_ONLY="true" ;;
    2) ENABLE_KEY_ONLY="false" ;;
    *) ENABLE_KEY_ONLY="true" ;;
  esac

  if [[ "$ENABLE_KEY_ONLY" == "true" ]]; then
    read -r -p "请输入要写入公钥的用户名（例如 cc）: " TARGET_USER
    [[ -n "$TARGET_USER" ]] || { err "你选择了仅秘钥登录，用户名不能为空。"; exit 1; }
    read -r -p "粘贴该用户 SSH 公钥（ssh-ed25519/ssh-rsa...）: " PUBKEY
    [[ -n "$PUBKEY" ]] || { err "你选择了仅秘钥登录，但未提供公钥。"; exit 1; }
    ok "已启用仅秘钥登录（两阶段防锁死流程）"
  else
    warn "将保留密码登录。"
  fi
}

system_update_and_cleanup(){
  step "系统更新与清理"
  case "$PKG_MGR" in
    apt)
      apt-get update -y
      DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
      DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y
      apt-get autoremove -y
      apt-get autoclean -y
      ;;
    dnf)
      dnf -y makecache
      dnf -y upgrade --refresh
      dnf -y autoremove || true
      dnf -y clean all
      ;;
    yum)
      yum -y makecache
      yum -y update
      yum -y autoremove || true
      yum -y clean all
      ;;
  esac
  ok "系统更新与清理完成"
}

install_base_tools(){
  step "安装常用软件"
  case "$PKG_MGR" in
    apt)
      apt-get install -y curl wget unzip nano vim git jq htop ca-certificates gnupg lsb-release openssh-server fail2ban
      ;;
    dnf|yum)
      $PKG_MGR install -y curl wget unzip nano vim git jq htop ca-certificates openssh-server fail2ban
      ;;
  esac

  # sudo 在某些精简镜像可能不存在/仓库异常，做容错安装
  if ! command -v sudo >/dev/null 2>&1; then
    warn "未检测到 sudo，尝试安装..."
    case "$PKG_MGR" in
      apt) apt-get install -y sudo || warn "sudo 安装失败，继续执行（当前 root 会话不受影响）" ;;
      dnf|yum) $PKG_MGR install -y sudo || warn "sudo 安装失败，继续执行（当前 root 会话不受影响）" ;;
    esac
  fi

  systemctl enable fail2ban --now
  ok "基础软件安装完成"
}

set_timezone(){ step "应用时区"; timedatectl set-timezone "$TIMEZONE"; ok "时区已生效: $TIMEZONE"; }

apply_hostname(){
  [[ -n "${NEW_HOSTNAME:-}" ]] || return 0
  step "应用主机名"

  hostnamectl set-hostname "$NEW_HOSTNAME"

  # 尝试同步 /etc/hosts 中 127.0.1.1 的主机名（Debian/Ubuntu 常见）
  if [[ -f /etc/hosts ]]; then
    if grep -qE '^127\.0\.1\.1\s+' /etc/hosts; then
      sed -i "s/^127\.0\.1\.1\s\+.*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts
    else
      echo -e "127.0.1.1\t$NEW_HOSTNAME" >> /etc/hosts
    fi
  fi

  ok "主机名已更新为: $NEW_HOSTNAME"
}

setup_user_pubkey_if_needed(){
  [[ "$ENABLE_KEY_ONLY" == "true" ]] || return 0
  step "配置用户与公钥"
  if ! id "$TARGET_USER" >/dev/null 2>&1; then
    info "用户 $TARGET_USER 不存在，自动创建管理员用户"
    adduser --disabled-password --gecos '' "$TARGET_USER"
    if getent group sudo >/dev/null 2>&1; then
      usermod -aG sudo "$TARGET_USER"
      info "已加入 sudo 组"
    elif getent group wheel >/dev/null 2>&1; then
      usermod -aG wheel "$TARGET_USER"
      info "已加入 wheel 组"
    else
      warn "未找到 sudo/wheel 组，请手动授予管理员权限"
    fi
  fi
  install -d -m 700 "/home/$TARGET_USER/.ssh"
  echo "$PUBKEY" > "/home/$TARGET_USER/.ssh/authorized_keys"
  chmod 600 "/home/$TARGET_USER/.ssh/authorized_keys"
  chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/.ssh"
  ok "公钥已写入 /home/$TARGET_USER/.ssh/authorized_keys"
}

get_sshd_config_path(){
  if [[ -f /etc/ssh/sshd_config ]]; then
    echo "/etc/ssh/sshd_config"
  elif [[ -f /etc/sshd_config ]]; then
    echo "/etc/sshd_config"
  else
    err "找不到 sshd_config"; exit 1
  fi
}

set_or_append(){
  local key="$1" val="$2" file="$3"
  if grep -Eq "^#?${key}[[:space:]]+" "$file"; then
    sed -i "s|^#\?${key}[[:space:]].*|${key} ${val}|" "$file"
  else
    echo "${key} ${val}" >> "$file"
  fi
}

configure_sshd_phase1(){
  step "SSH 第一阶段：改端口 + 禁止 root，暂不关密码"
  local sshcfg
  sshcfg="$(get_sshd_config_path)"
  backup_file "$sshcfg"

  set_or_append "Port" "$SSH_PORT" "$sshcfg"
  set_or_append "PubkeyAuthentication" "yes" "$sshcfg"
  set_or_append "PermitRootLogin" "no" "$sshcfg"
  set_or_append "PasswordAuthentication" "yes" "$sshcfg"

  sshd -t
  restart_ssh
  ok "SSH 第一阶段已完成"
}

smart_ssh_probe(){
  local probe_ok="true"
  if command -v ss >/dev/null 2>&1; then
    if ss -ltn | awk '{print $4}' | grep -qE "[:.]${SSH_PORT}$"; then
      ok "检测到 sshd 正在监听端口 $SSH_PORT"
    else
      warn "未检测到 sshd 监听新端口 $SSH_PORT"
      probe_ok="false"
    fi
  fi

  if command -v nc >/dev/null 2>&1; then
    if nc -z 127.0.0.1 "$SSH_PORT" >/dev/null 2>&1; then
      ok "本机 TCP 探测通过: 127.0.0.1:$SSH_PORT"
    else
      warn "本机 TCP 探测失败: 127.0.0.1:$SSH_PORT"
      probe_ok="false"
    fi
  fi

  [[ "$probe_ok" == "true" ]]
}

verify_new_port_and_confirm(){
  [[ "$ENABLE_KEY_ONLY" == "true" ]] || return 0

  step "智能验证（防锁死）"
  local server_ip
  server_ip="$(curl -4 -s --max-time 3 ifconfig.me || echo '<server_ip>')"

  smart_ssh_probe || warn "自动探测未完全通过，请务必手工验证。"

  cat <<EOF
请在本地【新开一个终端】执行：

  ssh -p $SSH_PORT $TARGET_USER@$server_ip

验证成功后回来选择：
  1) 我已验证成功，继续切仅秘钥
  2) 稍后验证（脚本等待60秒后再问）
  3) 先不切，仅保留当前状态（密码登录继续开启）
EOF

  while true; do
    read -r -p "请输入 [1/2/3]: " choose
    case "$choose" in
      1) ok "收到，继续执行第二阶段。"; return 0 ;;
      2) info "好的，等待 60 秒..."; sleep 60 ;;
      3) warn "已跳过第二阶段，当前保留密码登录。"; ENABLE_KEY_ONLY="false"; return 0 ;;
      *) warn "输入无效，请输入 1/2/3" ;;
    esac
  done
}

configure_sshd_phase2_keyonly(){
  [[ "$ENABLE_KEY_ONLY" == "true" ]] || return 0
  step "SSH 第二阶段：切换为仅秘钥登录"
  local sshcfg
  sshcfg="$(get_sshd_config_path)"

  set_or_append "PasswordAuthentication" "no" "$sshcfg"
  set_or_append "ChallengeResponseAuthentication" "no" "$sshcfg"
  set_or_append "KbdInteractiveAuthentication" "no" "$sshcfg"
  set_or_append "UsePAM" "yes" "$sshcfg"

  sshd -t
  restart_ssh
  ok "已切换为仅秘钥登录"
}

configure_fail2ban(){
  step "配置 Fail2ban 严格策略"
  mkdir -p /etc/fail2ban/jail.d
  cat >/etc/fail2ban/jail.d/sshd.local <<EOF
[sshd]
enabled = true
port = $SSH_PORT
backend = systemd
maxretry = 3
findtime = 10m
bantime = 24h
bantime.increment = false
EOF
  systemctl restart fail2ban
  ok "Fail2ban 已生效（3次/10分钟 -> 封禁24小时）"
}

enable_bbr(){
  step "启用 BBR 加速"
  cat >/etc/sysctl.d/99-bbr.conf <<'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
  sysctl --system >/dev/null
  local cc
  cc="$(sysctl -n net.ipv4.tcp_congestion_control || true)"
  [[ "$cc" == "bbr" ]] && ok "BBR 已启用" || warn "BBR 可能未启用，请确认内核支持。"
}

write_summary(){
  cat >"$SUMMARY_FILE" <<EOF
[VPS Bootstrap Summary]
Time: $(date '+%F %T %Z')
OS: $OS_ID $OS_VER
Package Manager: $PKG_MGR
SSH Service: $SSH_SERVICE
SSH Port: $SSH_PORT
Timezone: $TIMEZONE
Hostname: $(hostnamectl --static 2>/dev/null || hostname)
Key-only Login: $ENABLE_KEY_ONLY
Fail2ban Policy: maxretry=3, findtime=10m, bantime=24h
BBR: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)
Log File: $LOG_FILE
EOF
  chmod 600 "$SUMMARY_FILE"
}

print_final(){
  step "执行完成"
  echo
  ui_line
  echo -e "${C_BOLD}${C_GREEN}✅ 初始化完成${C_RESET}"
  echo -e "${C_BOLD}系统:${C_RESET} $OS_ID $OS_VER"
  echo -e "${C_BOLD}SSH 新端口:${C_RESET} ${C_YELLOW}$SSH_PORT${C_RESET}"
  echo -e "${C_BOLD}仅秘钥登录:${C_RESET} $ENABLE_KEY_ONLY"
  echo -e "${C_BOLD}日志文件:${C_RESET} $LOG_FILE"
  echo -e "${C_BOLD}摘要文件:${C_RESET} $SUMMARY_FILE"
  ui_line
  echo -e "${C_YELLOW}建议：确认登录正常后执行 sudo reboot${C_RESET}"
}

main(){
  need_root
  ui_title
  init_logging
  detect_os
  ask_timezone
  ask_hostname
  ask_ssh_port
  ask_key_only

  system_update_and_cleanup
  install_base_tools
  set_timezone
  apply_hostname
  setup_user_pubkey_if_needed

  configure_sshd_phase1
  verify_new_port_and_confirm
  configure_sshd_phase2_keyonly

  configure_fail2ban
  enable_bbr
  write_summary
  print_final
}

main "$@"
