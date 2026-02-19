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

## 系统支持

- Ubuntu / Debian
- Rocky / AlmaLinux / CentOS / RHEL / Fedora（基础支持）

---

## 快速开始

```bash
chmod +x server-bootstrap.sh
sudo ./server-bootstrap.sh
```

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
