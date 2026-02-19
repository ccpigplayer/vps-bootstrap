# Changelog

## v1.1.8
- feat: support interactive hostname update


## v1.1.7
- fix: installer now supports curl/wget fallback


## v1.1.6
- feat: short curl|bash installer and single quick-start path


## v1.1.5
- docs: refine core features layout and readability


## v1.1.4
- docs: public repo update + improved one-line bootstrap command


## v1.1.3
- fix: handle missing sudo package gracefully and admin group compatibility


## v1.1.2
- docs+release: support matrix and one-line run improvements


## v1.1.0
- 标题去除 emoji
- 增加系统支持：Ubuntu/Debian + RHEL 系基础支持
- SSH 验证流程增强：自动探测 + 等待重试 + 可安全降级
- 保留两阶段切换防锁死机制
- 持续记录审计日志与摘要
- 私有仓库场景：移除开源 License 文件

## v1.0.0
- 初始发布
- 交互式时区选择
- SSH 端口交互修改
- SSH 两阶段切换（防锁死）
- 可选仅秘钥登录
- Fail2ban 严格策略（3 次/10 分钟，封禁 24 小时）
- Fail2ban 自动同步 SSH 新端口
- BBR 启用
- 系统更新与自动清理
- 审计日志落盘
