# VPS Bootstrap Pro

一个面向 VPS 的交互式一键初始化脚本，重点解决：
- 新机首次配置重复劳动
- SSH 加固容易锁死
- 多机缺少统一审计日志

> 当前为无防火墙版本（按项目需求）。

---

## 核心特性

### 🎯 一句话定位
把一台新 VPS 从“裸机状态”快速拉到“可安全登录 + 可审计 + 可重复部署”。

### 🛡️ 安全基线
- **SSH 两阶段防锁死（可选）**：默认保留密码登录；仅在你主动选择后，才会在确认新连接可用后切换为仅秘钥并禁用 root 密码登录
- **现有公钥检测**：当你选择禁用密码登录时，脚本会先检查目标用户是否已存在且包含 `authorized_keys`，避免误锁死
- **Fail2ban 严格策略**：`3 次失败 / 10 分钟` → `封禁 24 小时`
- **端口自动对齐**：Fail2ban 自动跟随 SSH 新端口

### ⚙️ 运维效率
- **系统更新闭环**：更新 + 清理旧依赖（`autoremove/autoclean`）
- **基础工具就绪**：curl / wget / unzip / nano / vim / git / jq / htop
- **BBR 加速**：自动配置并校验拥塞控制

### 🌍 交互体验
- **彩色步骤引导**：菜单式输入，降低误操作
- **多时区快速选择**：上海/香港/新加坡/首尔/洛杉矶/东京
- **可选主机名修改**：一键改 `hostname`，便于多机统一命名规范
- **智能验证流程**：自动探测监听状态 + TCP 探测 + 等待重试
- **SSH 端口智能选择**：输入端口可手动指定；直接回车会自动生成高位随机端口

### 🧾 审计与追踪
- **全量日志**：`/var/log/vps-bootstrap/bootstrap-时间戳.log`
- **摘要日志**：`/var/log/vps-bootstrap/bootstrap-summary-时间戳.txt`

---

## 支持矩阵

| 功能 | Ubuntu / Debian | Rocky / Alma / CentOS / RHEL / Fedora |
|---|---|---|
| 系统更新 + 清理旧依赖 | ✅ | ✅ |
| 安装基础工具（curl/wget/unzip/nano/vim/sudo等） | ✅ | ✅ |
| 交互式时区选择 | ✅ | ✅ |
| 可选主机名修改 | ✅ | ✅ |
| 交互式 SSH 端口修改 | ✅ | ✅ |
| SSH 两阶段防锁死切换 | ✅ | ✅ |
| 仅秘钥登录（可选） | ✅ | ✅ |
| 智能验证（监听+TCP探测+等待重试） | ✅ | ✅ |
| Fail2ban 严格策略（3次/10分钟，封禁24小时） | ✅ | ✅ |
| Fail2ban 自动跟随 SSH 新端口 | ✅ | ✅ |
| BBR 启用 | ✅ | ✅（内核支持时） |
| 审计日志落盘 | ✅ | ✅ |
| 防火墙自动配置 | ❌（按项目要求不启用） | ❌（按项目要求不启用） |

---

## 快速开始

```bash
bash -lc 'tmp=/tmp/vps-bootstrap-install.sh; (command -v curl >/dev/null && curl -fsSL https://raw.githubusercontent.com/ccpigplayer/vps-bootstrap/main/install.sh -o "$tmp") || wget -qO "$tmp" https://raw.githubusercontent.com/ccpigplayer/vps-bootstrap/main/install.sh; bash "$tmp"'
```

> 说明：这是交互式脚本，不建议使用 `| bash` 直接管道执行，否则可能无法读取你的输入。

---

## 项目结构

```text
.
├── install.sh
├── server-bootstrap.sh
├── bootstrap-playbook.md
├── CHANGELOG.md
└── README.md
```

---

## Release 迭代

- 本项目已启用语义化版本（SemVer）
- 版本文件：`VERSION`
- 发布规则说明：`RELEASE.md`
- 本地发布脚本：`scripts/release.sh`
- 推送 tag（如 `v1.1.3`）后可按需创建 GitHub Release（当前默认手动）

## 说明

- 此仓库已切换为公开（public）。
- 不包含密钥、令牌、私有资产清单等敏感信息。
