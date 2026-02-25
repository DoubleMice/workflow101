# Ch7: 自动化 — 让审查在你 commit 的瞬间自动发生

> **本章目标**：配置 Hooks 和 Skills，实现 commit 后自动审查
>
> | 章节 | 关键词 |
> |:-----|:------|
> | Ch0 生态概览 | 工具选型 · 开发模式 |
> | Ch1 项目规划 | Plan Agent · 需求分析 |
> | Ch2 项目脚手架 | CLAUDE.md · CLI 搭建 |
> | Ch3 理解变更 | Explore Agent · Git Diff |
> | Ch4 设计审查团队 | Agent 设计 · Prompt 工程 |
> | Ch5 并行审查 | Fan-out/Fan-in · 并行执行 |
> | Ch6 报告生成 | 结果聚合 · 条件逻辑 |
> | **► Ch7 自动化** | **Hooks · Skills** |
> | Ch8 质量保障 | 测试策略 · TDD |
> | Ch9 模板库 | 模式提炼 · 最佳实践 |
> | 附录 课后作业 | Workflow 实战 |

> 最好的工具是你感觉不到它存在的工具。

**术语**

- Hook（钩子，在特定事件发生时自动触发的回调机制）
- Skill（技能，Claude Code 中可复用的 prompt 模板，用 `/` 触发）
- Lint（代码静态检查，自动发现风格和潜在错误）
- Regex（Regular Expression，正则表达式，文本模式匹配语法）
- Matcher（匹配器，Hook 中用于筛选目标工具的过滤条件）

## 场景引入

到目前为止，我们的 Review Bot 已经能跑了。但每次都要手动敲 `review-bot review`，就像有了洗碗机却还要手动按开关一样——能用，但不够爽。

如果每次 `git commit` 的时候，审查自动跑起来呢？不用你记得，不用你操心，commit 一提交，报告就出来了。

这就是 **Hooks** 和 **Skills** 的用武之地。

---

## 设计思维：Hooks 是什么？

Claude Code 的 Hooks 是一种**事件驱动的自动化机制**。你可以配置：当某个工具被调用时，自动执行一段 shell 命令。

打个比方：Hooks 就像你家的智能家居规则——"当门打开时，自动开灯"。在 Claude Code 里就是"当文件被保存时，自动跑 lint"或"当 commit 发生时，自动跑审查"。

### Hook 的四种触发时机

| 触发时机 | 说明 | 典型用途 |
|---------|------|---------|
| PreToolUse | 工具调用**之前** | 拦截危险操作、参数校验 |
| PostToolUse | 工具调用**之后** | 自动格式化、自动测试 |
| Notification | 通知事件 | 发送消息到 Slack |
| Stop | Agent 停止时 | 清理临时文件 |

### Skills 是什么？

Skills 是 Claude Code 的**可复用 prompt 模板**。你可以把常用的操作封装成一个 skill，然后用 `/skill-name` 一键触发。

比如我们的审查流程，每次都要输入一大段指令。封装成 skill 后，只需要 `/review` 就搞定了。

### Claude Code 的三个自定义目录

Claude Code 提供了三个目录来扩展能力，容易混淆：

| 目录 | 用途 | 触发方式 |
|------|------|---------|
| `.claude/commands/` | 用户可调用的 Skill（prompt 模板） | 用 `/skill-name` 手动触发 |
| `.claude/skills/` | 自动应用的领域知识（`SKILL.md`） | Claude 判断相关时自动应用 |
| `.claude/agents/` | 自定义 Agent 定义 | 作为 subagent 被调用 |

- **commands/** 里的 Skill 是你主动触发的——比如 `/review` 启动审查流程
- **skills/** 里的 `SKILL.md` 是被动生效的——Claude 发现当前任务和某个 skill 相关时，自动读取并应用。适合放领域知识（比如"本项目的数据库迁移规范"）。可以加 `disable-model-invocation: true` 防止自动触发
- **agents/** 里的定义用于创建专门的 subagent，在独立上下文中运行

> 💡 **Tip**: 我们的 `/review` 放在 `commands/` 是对的——它是用户主动触发的操作。如果你有一些"Claude 写代码时应该自动遵守的规范"，放在 `skills/` 更合适。

---

## 实操复现：配置自动审查流水线

### Step 1: 配置 Hook — commit 后自动审查

在项目的 `.claude/settings.json` 中添加 hook 配置：

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "pattern": "git commit",
        "command": "echo 'HOOK: Auto-review triggered after commit'"
      }
    ]
  }
}
```

这个配置的意思是：当 Claude Code 通过 Bash 工具执行了包含 `git commit` 的命令后，自动打印一条提示。

实际项目中，你可以把 `echo` 换成真正的审查命令：

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "pattern": "git commit",
        "command": "review-bot review --diff HEAD~1 --output markdown"
      }
    ]
  }
}
```

> ⚠️ **踩坑提醒**: Hook 的 command 是同步执行的。如果审查耗时较长，会阻塞 Claude Code 的后续操作。对于耗时任务，考虑在 command 末尾加 `&` 让它后台运行。

### Step 2: 创建自定义 Skill — /review

在项目的 `.claude/commands/` 目录下创建 skill 文件：

**`.claude/commands/review.md`**:

```markdown
Run a comprehensive code review on the current changes.

1. Get the git diff for $ARGUMENTS (default: HEAD~1)
2. Parse the diff to understand what changed
3. Launch 4 parallel review agents:
   - Security reviewer
   - Performance reviewer
   - Style reviewer
   - Logic reviewer
4. Collect all results and generate a unified report
5. Output the report in markdown format
```

现在在 Claude Code 中输入 `/review` 或 `/review HEAD~3`，就会自动执行完整的审查流程。

`$ARGUMENTS` 是 skill 的内置变量，会被替换为用户在 `/review` 后面输入的参数。

### Step 3: 更多实用 Hook 示例

**自动格式化：写完文件自动跑 black**

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "pattern": "\\.py$",
        "command": "black $FILE_PATH 2>/dev/null || true"
      }
    ]
  }
}
```

**分支保护：阻止直接 commit 到 main**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "pattern": "git commit",
        "command": "branch=$(git branch --show-current) && [ \"$branch\" != 'main' ] || (echo 'BLOCKED: Do not commit to main' && exit 1)"
      }
    ]
  }
}
```

PreToolUse hook 返回非零退出码时，会**阻止**工具调用。这就实现了"在 main 分支上禁止 commit"的保护。

### Step 4: Hook 调试技巧

Hook 出问题时不太好排查——它在后台静默执行，没有明显的错误提示。以下是几个实用的调试方法：

**1. 用日志文件记录 Hook 执行**

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "pattern": "\\.py$",
        "command": "input=$(cat) && file_path=$(echo $input | jq -r '.tool_input.file_path // empty') && echo \"$(date): Hook triggered for $file_path\" >> /tmp/hook-debug.log && black \"$file_path\" 2>&1 | tee -a /tmp/hook-debug.log"
      }
    ]
  }
}
```

跑完后查看 `/tmp/hook-debug.log`，就能看到 Hook 是否被触发、执行了什么、有没有报错。

**2. Hook 的输入机制：stdin JSON**

Claude Code 执行 Hook 时，会通过 **stdin** 传入一个 JSON 对象，包含工具调用的上下文信息。你的 Hook 脚本需要从 stdin 读取这个 JSON 来获取详细信息：

```bash
#!/bin/bash
# 从 stdin 读取 JSON 输入
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
echo "Hook triggered: $tool_name on $file_path"
```

stdin JSON 的典型结构：

```json
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/home/user/project/app.py",
    "content": "..."
  }
}
```

> ⚠️ **踩坑提醒**: Hook 的 command 是同步执行的，会阻塞 Claude Code 的后续操作。如果你的 Hook 命令耗时较长（比如跑完整测试套件），考虑在末尾加 `&` 让它后台运行，或者用 `timeout 10s` 限制执行时间。

**3. 先用 echo 测试 matcher 和 pattern**

不确定 Hook 能不能匹配到？先把 command 换成 `echo`：

```json
{
  "command": "cat | jq . && echo 'HOOK FIRED'"
}
```

看到 JSON 输出了，说明 Hook 匹配成功，再换成真正的命令。

---

## 进阶：Headless 模式与 CI 集成

到目前为止，我们的自动化都发生在 Claude Code 的交互式会话里。但真正的自动化应该能在 **无人值守** 的环境中运行——比如 CI/CD 流水线。

### Headless 模式：`claude -p`

Claude Code 支持 headless 模式，用 `-p` 参数直接传入 prompt，执行完毕后退出：

```bash
# 单次执行，不进入交互式会话
claude -p "分析 HEAD~1 的 git diff，给出安全审查意见"

# 指定输出格式
claude -p "审查这段代码的安全问题" --output-format json

# 限制可用工具（最小权限原则）
claude -p "检查代码风格" --allowedTools "Read,Glob,Grep"
```

### 在 CI 中集成 Review Bot

在 GitHub Actions 中，你可以这样集成：

```yaml
# .github/workflows/review.yml
name: AI Code Review
on: [pull_request]

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Run AI Review
        run: |
          claude -p "审查 origin/main...HEAD 的变更，
          重点关注安全和逻辑问题，
          输出 JSON 格式的审查报告" \
          --output-format json > review-report.json
```

### 批量处理：Fan-out 的 CLI 版本

Headless 模式还能实现 Ch5 中 Fan-out 模式的 CLI 版本——用 shell 循环并行启动多个 Claude 实例：

```bash
# 对每个变更文件并行启动审查（最多 4 个并发）
git diff --name-only HEAD~1 | xargs -P 4 -I {} \
  claude -p "审查文件 {} 的安全问题" --allowedTools "Read,Grep"
```

> ⚠️ **注意**: Headless 模式每次调用都是独立会话，没有上下文延续。适合一次性任务，不适合需要多轮对话的场景。

---

## 提炼模板：自动化流水线模式

```
事件触发（Hook）
   ↓
预处理（PreToolUse: 校验、拦截）
   ↓
核心操作（工具调用）
   ↓
后处理（PostToolUse: 格式化、测试、审查）
```

### Skill 模板

```markdown
[一句话描述这个 skill 做什么]

1. [步骤 1]
2. [步骤 2]
3. [步骤 3]

Input: $ARGUMENTS (描述参数含义和默认值)
Output: [描述输出格式]
```

---

## 小结

- Hooks 是事件驱动的自动化：工具调用前后自动执行 shell 命令
- Hook 通过 stdin JSON 接收工具调用的上下文信息
- PreToolUse 可以拦截危险操作，PostToolUse 可以自动后处理
- 三个自定义目录各有分工：`commands/`（手动触发）、`skills/`（自动应用）、`agents/`（subagent 定义）
- Headless 模式（`claude -p`）让 Claude Code 能集成到 CI/CD 流水线
- Hook + Skill + Headless 组合起来就是一条完整的自动化流水线

---

## 参考链接

- [Hooks, Skills & Actions 完整指南](https://aibit.im/blog/post/ultimate-guide-to-claude-code-setup-hooks-skills-actions)
- [Anthropic 官方文档 — Hooks](https://docs.anthropic.com/en/docs/claude-code/hooks)

---

[上一章: Ch6 — 报告生成](06_report.md) | [下一章: Ch8 — 质量保障](08_testing.md)
