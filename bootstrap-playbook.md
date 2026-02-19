# VPS Bootstrap Pro 使用说明（无防火墙版）

本版本增强点：
- 系统支持增强：Ubuntu/Debian + RHEL 系基础支持
- 可选主机名修改（hostnamectl + /etc/hosts 同步）
- 标题去除 emoji
- SSH 验证流程更智能：自动探测 + 交互等待 + 安全降级
- 审计日志落盘

## 运行
```bash
chmod +x server-bootstrap.sh
sudo ./server-bootstrap.sh
```

## SSH 两阶段（防锁死）
1. 第一阶段：改端口 + 禁 root，保留密码登录
2. 脚本自动探测：
   - sshd 是否监听新端口
   - 本机 TCP 探测是否通过
3. 你在本地新终端验证：
   `ssh -p <新端口> <用户名>@<服务器IP>`
4. 你可选择：
   - 继续切换仅秘钥
   - 等待后再验证
   - 暂不切换（保留密码登录）

## 日志
- 全量：`/var/log/vps-bootstrap/bootstrap-*.log`
- 摘要：`/var/log/vps-bootstrap/bootstrap-summary-*.txt`
