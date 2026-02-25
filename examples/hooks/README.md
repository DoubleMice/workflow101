# Hook 配置示例

Claude Code Hooks 的实用配置模板。详见 [Ch7: 自动化](../../07_automation.md)。

## 文件说明

| 文件 | 用途 |
|------|------|
| post-commit-review.json | commit 后自动触发代码审查 |
| auto-format.json | 写完 Python 文件后自动格式化 |
| branch-protection.json | 阻止直接 commit 到 main 分支 |
| auto-test.json | 修改源码后自动跑测试 |
| debug-hook.sh | Hook 调试脚本，记录触发信息到日志 |
