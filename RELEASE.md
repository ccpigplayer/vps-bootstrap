# Release 规则

从现在开始，所有改动按语义化版本发布（SemVer）：

- PATCH（x.y.Z）：文档、小修复、非破坏性调整
- MINOR（x.Y.z）：新增功能、向后兼容
- MAJOR（X.y.z）：破坏性变更

## 每次发布步骤

1. 完成改动并通过自检
2. 更新 `CHANGELOG.md`
3. 更新 `VERSION`
4. 提交代码并打 tag（`v<version>`）
5. 推送 `main` 和 tag
6. 自动生成 GitHub Release（由 Actions 在 tag push 后执行）

## 命令示例

```bash
# patch 版本发布
bash scripts/release.sh patch "docs: improve support matrix"

# minor 版本发布
bash scripts/release.sh minor "feat: add smarter ssh validation"
```
