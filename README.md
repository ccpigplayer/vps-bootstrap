# VPS Bootstrap Pro

一个面向 VPS 的交互式一键初始化脚本，重点解决：
- 新机首次配置重复劳动
- SSH 加固容易锁死
- 多机缺少统一审计日志

> 当前为无防火墙版本（按项目需求）。

---

## 核心特性

- 美化交互 UI（彩色步骤 + 菜单式输入）
- SSH 两阶段防锁死流程
  1. 先改端口 + 禁 root（暂保留密码）
  2. 自动探测新端口监听状态 + 本机 TCP 探测
  3. 引导你在本地新终端验证
  4. 验证通过后再切换仅秘钥登录
- Fail2ban 严格策略：10 分钟内失败 3 次，封禁 24 小时
- Fail2ban 端口自动同步 SSH 新端口
- BBR 启用
- 系统更新 + 自动清理旧依赖
- 多时区选择（默认上海）
- 审计日志落盘：
  - `/var/log/vps-bootstrap/bootstrap-时间戳.log`
  - `/var/log/vps-bootstrap/bootstrap-summary-时间戳.txt`

---

## 支持矩阵

| 功能 | Ubuntu / Debian | Rocky / Alma / CentOS / RHEL / Fedora |
|---|---|---|
| 系统更新 + 清理旧依赖 | ✅ | ✅ |
| 安装基础工具（curl/wget/unzip/nano/vim/sudo等） | ✅ | ✅ |
| 交互式时区选择 | ✅ | ✅ |
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

### 一行调用（推荐）

```bash
git clone https://github.com/ccpigplayer/vps-bootstrap.git && cd vps-bootstrap && sudo bash server-bootstrap.sh
```

> 如果仓库是 private，会提示输入 GitHub 凭据（或使用已配置的 SSH Key）。

---

## 项目结构

```text
.
├── server-bootstrap.sh
├── bootstrap-playbook.md
├── CHANGELOG.md
└── README.md
```

---

## 说明

- 此仓库为私有项目，不附带开源许可。
