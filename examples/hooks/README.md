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

## 安装方式

Hook 配置写在项目根目录的 `.claude/settings.json` 中。

### 方式一：直接复制

选一个 JSON 文件，把 `hooks` 字段复制到你项目的 `.claude/settings.json`：

```bash
# 如果项目还没有 .claude 目录，先创建
mkdir -p .claude

# 直接用某个模板作为起点
cp examples/hooks/auto-format.json .claude/settings.json
```

### 方式二：合并多个 Hook

如果要同时启用多个 hook，需要手动合并到同一个 `settings.json`。同一个触发时机（如 `PostToolUse`）下可以放多条规则：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "pattern": "git commit",
        "command": "branch=$(git branch --show-current) && [ \"$branch\" != 'main' ] || (echo 'BLOCKED: Do not commit to main' && exit 1)"
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "pattern": "\\.py$",
        "command": "black $FILE_PATH 2>/dev/null || true"
      },
      {
        "matcher": "Write|Edit",
        "pattern": "review_bot/.*\\.py$",
        "command": "pytest tests/ -x -q 2>&1 | tail -5"
      }
    ]
  }
}
```

### 验证 Hook 是否生效

用 `debug-hook.sh` 确认 hook 能正确触发：

```bash
# 1. 先把 debug hook 加到 settings.json
#    将某条 hook 的 command 临时改为:
#    "command": "bash examples/hooks/debug-hook.sh"

# 2. 在 Claude Code 中触发对应操作（比如编辑一个 .py 文件）

# 3. 查看日志
cat /tmp/hook-debug.log
```

看到日志输出说明 matcher 和 pattern 匹配成功，再换回正式的 command。

### 注意事项

- Hook 的 `command` 是同步执行的，会阻塞 Claude Code。耗时命令考虑加 `&` 后台运行
- `PreToolUse` hook 返回非零退出码会阻止工具调用（可用于拦截危险操作）
- `PostToolUse` hook 的退出码不影响工具调用，但输出会反馈给 Claude
- Hook 通过 stdin 接收 JSON 格式的工具调用上下文，用 `jq` 解析
