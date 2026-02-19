#!/usr/bin/env bash
set -euo pipefail

# ==============================================
#  VPS Bootstrap Pro (No-Firewall Edition)
#  - 美化交互
#  - 两阶段 SSH 安全切换（防锁死）
#  - 审计日志落盘
# ==============================================

############################
# 全局配置
############################
SSH_PORT="22"
ENABLE_KEY_ONLY="true"
TARGET_USER=""
PUBKEY=""
TIMEZONE="Asia/Shanghai"
LOG_DIR="/var/log/vps-bootstrap"
RUN_ID="$(date +%F-%H%M%S)"
LOG_FILE="$LOG_DIR/bootstrap-$RUN_ID.log"
SUMMARY_FILE="$LOG_DIR/bootstrap-summary-$RUN_ID.txt"

############################
# 颜色与UI
############################
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_BLUE='\033[1;34m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[1;31m'
C_CYAN='\033[1;36m'

ui_line() { echo -e "${C_CYAN}============================================================${C_RESET}"; }
ui_title() {
  ui_line
  echo -e "${C_BOLD}${C_BLUE}🦞 VPS Bootstrap Pro${C_RESET}"
  echo -e "${C_CYAN}安全初始化（无防火墙版）${C_RESET}"
  ui_line
}
step() { echo -e "\n${C_BOLD}${C_BLUE}▶ $*${C_RESET}"; }
ok() { echo -e "${C_GREEN}✔ $*${C_RESET}"; }
warn() { echo -e "${C_YELLOW}⚠ $*${C_RESET}"; }
err() { echo -e "${C_RED}✖ $*${C_RESET}"; }
info() { echo -e "${C_CYAN}• $*${C_RESET}"; }

############################
# 基础函数
############################
need_root() {
  if [[ $EUID -ne 0 ]]; then
    err "请使用 root 或 sudo 执行。"
    exit 1
  fi
}

init_logging() {
  mkdir -p "$LOG_DIR"
  touch "$LOG_FILE"
  chmod 600 "$LOG_FILE"
  # 将 stdout/stderr 同步写入日志
  exec > >(tee -a "$LOG_FILE") 2>&1
  info "日志文件: $LOG_FILE"
}

backup_file() {
  local f="$1"
  cp "$f" "${f}.bak.$(date +%F-%H%M%S)"
}

prompt_continue() {
  local msg="$1"
  read -r -p "$msg [y/N]: " ans
  [[ "${ans,,}" == "y" ]]
}

############################
# 交互选择
############################
ask_timezone() {
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

ask_ssh_port() {
  step "配置 SSH 端口"
  read -r -p "请输入新的 SSH 端口（1024-65535，回车默认22）: " input_port
  if [[ -z "${input_port:-}" ]]; then
    SSH_PORT="22"
  else
    if ! [[ "$input_port" =~ ^[0-9]+$ ]] || (( input_port < 1024 || input_port > 65535 )); then
      err "端口无效，必须是 1024-65535 的数字。"
      exit 1
    fi
    SSH_PORT="$input_port"
  fi
  ok "SSH 端口将设置为: $SSH_PORT"
}

ask_key_only() {
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
    if [[ -z "$TARGET_USER" ]]; then
      err "你选择了仅秘钥登录，用户名不能为空。"
      exit 1
    fi
    read -r -p "粘贴该用户 SSH 公钥（ssh-ed25519/ssh-rsa...）: " PUBKEY
    if [[ -z "$PUBKEY" ]]; then
      err "你选择了仅秘钥登录，但未提供公钥。"
      exit 1
    fi
    ok "已启用仅秘钥登录（将采用两阶段切换防锁死）"
  else
    warn "将保留密码登录。"
  fi
}

############################
# 系统操作
############################
system_update_and_cleanup() {
  step "系统更新与清理"
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
  DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y
  apt-get autoremove -y
  apt-get autoclean -y
  ok "系统更新与清理完成"
}

install_base_tools() {
  step "安装常用软件"
  apt-get install -y \
    curl wget unzip nano vim sudo git jq htop ca-certificates gnupg lsb-release \
    openssh-server fail2ban
  ok "基础软件安装完成"
}

set_timezone() {
  step "应用时区"
  timedatectl set-timezone "$TIMEZONE"
  ok "时区已生效: $TIMEZONE"
}

setup_user_pubkey_if_needed() {
  [[ "$ENABLE_KEY_ONLY" == "true" ]] || return 0

  step "配置用户与公钥"
  if ! id "$TARGET_USER" >/dev/null 2>&1; then
    info "用户 $TARGET_USER 不存在，自动创建并加入 sudo 组"
    adduser --disabled-password --gecos '' "$TARGET_USER"
    usermod -aG sudo "$TARGET_USER"
  fi

  install -d -m 700 "/home/$TARGET_USER/.ssh"
  echo "$PUBKEY" > "/home/$TARGET_USER/.ssh/authorized_keys"
  chmod 600 "/home/$TARGET_USER/.ssh/authorized_keys"
  chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/.ssh"
  ok "公钥已写入 /home/$TARGET_USER/.ssh/authorized_keys"
}

configure_sshd_phase1() {
  step "SSH 第一阶段：改端口 + 禁止 root，暂不关密码"
  backup_file /etc/ssh/sshd_config

  sed -i "s/^#\?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
  sed -i "s/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/" /etc/ssh/sshd_config
  sed -i "s/^#\?PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config

  # 第一阶段保留密码，避免锁死
  sed -i "s/^#\?PasswordAuthentication .*/PasswordAuthentication yes/" /etc/ssh/sshd_config

  sshd -t
  systemctl restart ssh || systemctl restart sshd
  ok "SSH 第一阶段已完成"
}

configure_sshd_phase2_keyonly() {
  [[ "$ENABLE_KEY_ONLY" == "true" ]] || return 0

  step "SSH 第二阶段：切换为仅秘钥登录"
  sed -i "s/^#\?PasswordAuthentication .*/PasswordAuthentication no/" /etc/ssh/sshd_config
  sed -i "s/^#\?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/" /etc/ssh/sshd_config
  sed -i "s/^#\?KbdInteractiveAuthentication .*/KbdInteractiveAuthentication no/" /etc/ssh/sshd_config || true
  sed -i "s/^#\?UsePAM .*/UsePAM yes/" /etc/ssh/sshd_config

  sshd -t
  systemctl restart ssh || systemctl restart sshd
  ok "已切换为仅秘钥登录"
}

verify_new_port_and_confirm() {
  [[ "$ENABLE_KEY_ONLY" == "true" ]] || return 0

  step "人工验证（防锁死）"
  cat <<EOF
请【先不要关闭当前会话】。
请在你的本地终端新开一个窗口，执行：

  ssh -p $SSH_PORT $TARGET_USER@<服务器IP>

如果新端口 + 公钥登录成功，再回来继续。
EOF

  if prompt_continue "你是否已经在新终端验证登录成功并继续切换到仅秘钥？"; then
    ok "已确认，继续执行第二阶段。"
  else
    warn "你选择了暂不切换到仅秘钥。当前保持密码登录开启状态。"
    ENABLE_KEY_ONLY="false"
  fi
}

configure_fail2ban() {
  step "配置 Fail2ban 严格策略"
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

  systemctl enable fail2ban --now
  systemctl restart fail2ban
  ok "Fail2ban 已生效（3次/10分钟 -> 封禁24小时）"
}

enable_bbr() {
  step "启用 BBR 加速"
  cat >/etc/sysctl.d/99-bbr.conf <<'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
  sysctl --system >/dev/null

  local cc
  cc="$(sysctl -n net.ipv4.tcp_congestion_control || true)"
  if [[ "$cc" == "bbr" ]]; then
    ok "BBR 已启用"
  else
    warn "BBR 可能未启用，请确认内核支持。"
  fi
}

write_summary() {
  cat >"$SUMMARY_FILE" <<EOF
[VPS Bootstrap Summary]
Time: $(date '+%F %T %Z')
SSH Port: $SSH_PORT
Timezone: $TIMEZONE
Key-only Login: $ENABLE_KEY_ONLY
Fail2ban Policy: maxretry=3, findtime=10m, bantime=24h
BBR: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)
Log File: $LOG_FILE
EOF
  chmod 600 "$SUMMARY_FILE"
}

print_final() {
  step "执行完成"
  echo
  ui_line
  echo -e "${C_BOLD}${C_GREEN}✅ 初始化完成${C_RESET}"
  echo -e "${C_BOLD}SSH 新端口:${C_RESET} ${C_YELLOW}$SSH_PORT${C_RESET}"
  echo -e "${C_BOLD}时区:${C_RESET} $TIMEZONE"
  echo -e "${C_BOLD}仅秘钥登录:${C_RESET} $ENABLE_KEY_ONLY"
  echo -e "${C_BOLD}日志文件:${C_RESET} $LOG_FILE"
  echo -e "${C_BOLD}摘要文件:${C_RESET} $SUMMARY_FILE"
  ui_line
  echo
  echo -e "${C_YELLOW}[重要提醒]${C_RESET}"
  echo "1) 请务必先在新终端测试 SSH 登录："
  if [[ -n "$TARGET_USER" ]]; then
    echo "   ssh -p $SSH_PORT $TARGET_USER@<server_ip>"
  else
    echo "   ssh -p $SSH_PORT <user>@<server_ip>"
  fi
  echo "2) 确认无误后再退出当前会话。"
  echo "3) 建议执行重启确保全部配置稳定生效：sudo reboot"
}

main() {
  need_root
  ui_title
  init_logging

  ask_timezone
  ask_ssh_port
  ask_key_only

  system_update_and_cleanup
  install_base_tools
  set_timezone
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
