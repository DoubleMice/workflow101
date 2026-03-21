# Ch7: Hooks 与 Skills — commit 时自动触发审查

> 最好的工具是你感觉不到它存在的工具。
>
> | 章节 | 关键词 |
> |:-----|:------|
> | Ch0 工具选型 | 工具选型 · 开发模式 |
> | Ch1 需求分析 | Plan Agent · 需求分析 |
> | Ch2 搭建脚手架 | CLAUDE.md · CLI 搭建 |
> | Ch3 解析 Git Diff | Explore Agent · Git Diff |
> | Ch4 Agent 设计 | Agent 设计 · Prompt 工程 |
> | Ch5 Fan-out/Fan-in | Fan-out/Fan-in · 并行执行 |
> | Ch6 结果聚合 | 结果聚合 · 条件逻辑 |
> | **► Ch7 Hooks 与 Skills** | **Hooks · Skills** |
> | Ch8 测试驱动 | 测试策略 · TDD |
> | Ch9 六种编排模式 | 模式提炼 · 最佳实践 |
> | 附录 课后作业 | Workflow 实战 |

**术语**

- Hook（钩子，在特定事件发生时自动触发的回调机制）
- Skill（技能，Claude Code 中可复用的 prompt 模板，用 `/` 触发）
- Lint（代码静态检查，自动发现风格和潜在错误）
- Regex（Regular Expression，正则表达式，文本模式匹配语法）
- Matcher（匹配器，Hook 中用于筛选目标工具的过滤条件）

## 7.1 场景引入

到这一步，Review Bot 已经能跑了。但每次都要手动输入 `/review-bot`，就像有了洗碗机却还要手动按开关——能用，但不够爽。

如果每次 `git commit` 的时候，审查自动跑起来呢？不用你记得，不用你操心，commit 一提交，报告就出来了。

这就是 **Hooks** 和 **Skills** 的用武之地。

---

## 7.2 Hooks 是什么？

Claude Code 的 Hooks 是一种**事件驱动的自动化机制**。你可以配置：当某个工具被调用时，自动执行一段 shell 命令。

打个比方：Hooks 就像你家的智能家居规则——"当门打开时，自动开灯"。在 Claude Code 里就是"当文件被保存时，自动跑 lint"或"当 commit 发生时，自动跑审查"。

### 7.2.1 Hook 的四种触发时机

| 触发时机 | 说明 | 典型用途 |
|---------|------|---------|
| PreToolUse | 工具调用**之前** | 拦截危险操作、参数校验 |
| PostToolUse | 工具调用**之后** | 自动格式化、自动测试 |
| Notification | 通知事件 | 发送消息到 Slack |
| Stop | Agent 停止时 | 清理临时文件 |

### 7.2.2 matcher 和 pattern 怎么匹配？

每条 Hook 规则通过 `matcher` 对象过滤，包含两个字段，必须同时命中才会触发：

| 字段 | 匹配对象 | 示例 |
|------|---------|------|
| `tools` | 工具名称列表（带 Tool 后缀） | `["BashTool"]`、`["WriteTool", "EditTool"]` |
| `input_contains` | 工具输入中包含的字符串 | `"git commit"`、`".py"` |

`input_contains` 匹配的内容取决于工具类型：

- **BashTool** → 匹配 `command` 字段（即 shell 命令字符串）
- **WriteTool / EditTool** → 匹配 `file_path` 字段（即操作的文件路径）
- **ReadTool / GlobTool / GrepTool** → 同样匹配路径或 pattern 参数

举个例子，`"tools": ["BashTool"], "input_contains": "git commit"` 的意思是：当 Claude Code 通过 Bash 工具执行的命令中包含 `git commit` 时触发。而 `"tools": ["WriteTool", "EditTool"], "input_contains": ".py"` 的意思是：当 Claude Code 写入或编辑 `.py` 文件时触发。

### 7.2.3 Skills 是什么？

Skills 是 Claude Code 的**可复用 prompt 模板**。你把一段操作指令写成 Markdown 文件，放到 `.claude/skills/` 目录下，就能用 `/skill-name` 一键触发。

它的工作机制很简单：当你输入 `/review-bot HEAD~3` 时，Claude Code 读取对应的 `SKILL.md` 文件，把内容作为 prompt 注入当前对话，同时把 `HEAD~3` 替换到 `$ARGUMENTS` 变量的位置。本质上就是一个带参数的 prompt 快捷方式——但这个"快捷方式"可以编排出完整的多步骤工作流。

### 7.2.4 Claude Code 的三个自定义目录

Claude Code 提供了三个目录来扩展能力，容易混淆：

| 目录 | 用途 | 触发方式 |
|------|------|---------|
| `.claude/skills/` | 用户可调用的 Skill（prompt 模板） | 用 `/skill-name` 手动触发，或 Claude 判断相关时自动应用 |
| `.claude/agents/` | 自定义 Agent 定义 | 作为 subagent 被调用 |
| `.claude/rules/` | 项目规则（自动加载） | 每次会话自动生效 |

- **skills/** 里的 `SKILL.md` 既可以手动触发（`/review-bot`），也可以被动生效（Claude 发现当前任务相关时自动应用）。加 `disable-model-invocation: true` 可以限制为仅手动触发
- **agents/** 里的定义用于创建专门的 subagent，在独立上下文中运行
- **rules/** 里的规则每次会话自动加载，适合放代码风格、测试要求等约束

> 💡 **Tip**: `/review-bot` 加了 `disable-model-invocation: true`，只能手动触发。如果你有一些"Claude 写代码时应该自动遵守的规范"，放在 `rules/` 更合适。

---

## 7.3 实操复现：配置自动审查流水线

### Step 1: 配置 Hook — commit 后自动审查

在项目的 `.claude/settings.json` 中添加 hook 配置：

```json
{
  "PostToolUse": [
    {
      "matcher": { "tools": ["BashTool"], "input_contains": "git commit" },
      "hooks": [{ "type": "command", "command": "echo 'HOOK: Auto-review triggered after commit'" }]
    }
  ]
}
```

这个配置的意思是：当 Claude Code 通过 Bash 工具执行了包含 `git commit` 的命令后，自动打印一条提示。

实际项目中，你可以把 `echo` 换成工具层的 diff 摘要命令，让 commit 后立刻看到变更概览：

```json
{
  "PostToolUse": [
    {
      "matcher": { "tools": ["BashTool"], "input_contains": "git commit" },
      "hooks": [{ "type": "command", "command": "review-bot diff HEAD~1 2>/dev/null | head -1 || true" }]
    }
  ]
}
```

注意：完整的审查流程（并行 4 个 agent）应该通过 `/review-bot` skill 触发，而不是放在 Hook 里。Hook 适合轻量级的自动化（格式化、lint、摘要），重量级的编排交给 Skill。

> ⚠️ **踩坑提醒**: Hook 的 command 是同步执行的。如果审查耗时较长，会阻塞 Claude Code 的后续操作。对于耗时任务，考虑在 command 末尾加 `&` 让它后台运行。

### Step 2: 创建自定义 Skill

Skill 的创建规则很简单：

1. 在 `.claude/skills/` 下创建一个以 skill 名命名的目录
2. 目录内放一个 `SKILL.md` 文件——`skills/review-bot/SKILL.md` 对应 `/review-bot`
3. 文件开头加 YAML frontmatter（name, description），正文是 prompt，支持 `$ARGUMENTS` 变量
4. 嵌套目录也可以——`skills/db/migrate/SKILL.md` 对应 `/db:migrate`

内置变量：

| 变量 | 含义 |
|------|------|
| `$ARGUMENTS` | 用户在 `/command` 后面输入的所有参数 |

来创建 `/review-bot` skill：

**`.claude/skills/review-bot/SKILL.md`**:

```markdown
---
name: review-bot
description: Run parallel C/C++ code review with 4 specialized agents
---

Run a C/C++ code review workflow. Follow each step exactly.

## Step 1: Get the diff
review-bot diff $ARGUMENTS

Capture the FULL output. The raw diff after the `---` separator is what agents review.
If empty, stop and report "No changes to review."

## Step 2: Fan-out — 4 parallel review agents
Launch exactly 4 Task tool calls IN PARALLEL. Each Task must:
- Use subagent_type: "general-purpose"
- Include the COMPLETE agent prompt below (do NOT tell the agent to read a file)
- Append the full diff content at the end

**Task 1 — Security:**
> You are a C/C++ security expert. Focus ONLY on security and memory safety.
> Ignore style, performance, logic. Check for: buffer overflow, use-after-free,
> format string vulnerabilities, integer overflow, null pointer dereference.
> Output one JSON object per line (no code fences):
> {"severity":"critical|warning|info","file":"<path>","line":<n>,"description":"...","suggestion":"..."}

**Task 2 — Performance:**
> You are a C/C++ performance engineer. Focus ONLY on performance.
> Ignore security, style, logic. Check for: memory leaks, unnecessary heap allocations
> in loops, cache-unfriendly access, unnecessary copies, missing reserve(), blocking I/O.
> Output one JSON object per line (no code fences):
> {"severity":"critical|warning|info","file":"<path>","line":<n>,"description":"...","suggestion":"..."}

**Task 3 — Style:**
> You are a C/C++ style reviewer. Focus ONLY on style and readability.
> Ignore security, performance, logic. Check for: missing/inconsistent header guards,
> const correctness, raw new/delete vs RAII, naming conventions, include order, magic numbers.
> Output one JSON object per line (no code fences):
> {"severity":"critical|warning|info","file":"<path>","line":<n>,"description":"...","suggestion":"..."}

**Task 4 — Logic:**
> You are a C/C++ logic reviewer. Focus ONLY on correctness.
> Ignore security, performance, style. Check for: undefined behavior, signed/unsigned
> mismatch, off-by-one errors, resource leaks on error paths, unchecked return values,
> incorrect pointer arithmetic.
> Output one JSON object per line (no code fences):
> {"severity":"critical|warning|info","file":"<path>","line":<n>,"description":"...","suggestion":"..."}

## Step 3: Fan-in — collect and merge
Extract all lines starting with `{` from each agent's response. Merge into JSON array.

## Step 4: Generate report
echo '<merged_json_array>' | review-bot report
```

现在输入 `/review-bot HEAD~3`，Claude Code 读取这个文件，把 `$ARGUMENTS` 替换为 `HEAD~3`，然后按步骤执行——获取 diff、并行派出 4 个 agent、收集结果、生成报告。

> ⚠️ **踩坑提醒：Prompt 必须内联**：注意 Step 2 中每个 agent 的 prompt 是完整写在 skill 文件里的，而不是"读取 `.claude/agents/security-reviewer.md`"。因为每个 subagent 有独立的上下文窗口，看不到主 agent 读过的文件。这是实践中最容易犯的错误——如果你写"参考之前的 prompt"，subagent 会一脸茫然。

再来几个实用示例：

**`.claude/skills/test/SKILL.md`** — 智能跑测试：

```markdown
Run tests related to the current changes.

1. Check git diff to identify changed files
2. Find test files that cover the changed code
3. Run only the relevant tests: pytest $ARGUMENTS -x -q
4. If any test fails, analyze the failure and suggest a fix
```

**`.claude/skills/audit/SKILL.md`** — 安全审计：

```markdown
Perform a security audit on $ARGUMENTS (default: the entire project).

Focus on:
- Input validation and sanitization
- Authentication and authorization checks
- SQL injection, XSS, command injection
- Hardcoded secrets or credentials
- Insecure dependencies

Output a markdown report sorted by severity.
```

**Skill 编写最佳实践**：

- 用英文写 prompt（Claude 对英文指令的遵循度更高），注释可以用中文
- 第一行写清楚这个 skill 做什么——Claude 会把它当作任务目标
- 步骤要具体。"review the code" 太模糊，"launch 4 parallel review agents" 才有可操作性
- 用 `$ARGUMENTS` 提供灵活性，同时写明默认值（如 `default: HEAD~1`）
- 不要在 skill 里硬编码路径或项目名——让它保持通用，项目特定的配置放 CLAUDE.md

### Step 3: 更多实用 Hook 示例

**自动格式化：写完文件自动跑 black**

```json
{
  "PostToolUse": [
    {
      "matcher": { "tools": ["WriteTool", "EditTool"], "input_contains": ".py" },
      "hooks": [{ "type": "command", "command": "file_path=$(cat | jq -r '.tool_input.file_path // empty') && [ -n \"$file_path\" ] && black \"$file_path\" 2>/dev/null || true" }]
    }
  ]
}
```

Hook 通过 stdin 接收 JSON 上下文（见 Step 4），用 `jq` 提取 `file_path` 后传给 `black`。

**分支保护：阻止直接 commit 到 main**

```json
{
  "PreToolUse": [
    {
      "matcher": { "tools": ["BashTool"], "input_contains": "git commit" },
      "hooks": [{ "type": "command", "command": "branch=$(git branch --show-current) && [ \"$branch\" != 'main' ] || (echo 'BLOCKED: Do not commit to main' && exit 1)" }]
    }
  ]
}
```

PreToolUse hook 返回非零退出码时，会**阻止**工具调用。这就实现了"在 main 分支上禁止 commit"的保护。

### Step 4: Hook 调试技巧

Hook 出问题时不太好排查——它在后台静默执行，没有明显的错误提示。以下是几个实用的调试方法：

**1. 用日志文件记录 Hook 执行**

```json
{
  "PostToolUse": [
    {
      "matcher": { "tools": ["WriteTool", "EditTool"], "input_contains": ".py" },
      "hooks": [{ "type": "command", "command": "input=$(cat) && file_path=$(echo \"$input\" | jq -r '.tool_input.file_path // empty') && echo \"$(date): Hook triggered for $file_path\" >> /tmp/hook-debug.log && black \"$file_path\" 2>&1 | tee -a /tmp/hook-debug.log" }]
    }
  ]
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

## 7.4 提炼模板：自动化流水线模式

```
事件触发（Hook）
   ↓
预处理（PreToolUse: 校验、拦截）
   ↓
核心操作（工具调用）
   ↓
后处理（PostToolUse: 格式化、测试、审查）
```

### 7.4.1 Skill 快速参考

```
创建:  .claude/skills/<name>/SKILL.md  →  /<name> 触发
子目录: .claude/skills/db/migrate/SKILL.md  →  /db:migrate 触发
变量:  $ARGUMENTS — 用户输入的参数
格式:  YAML frontmatter（name, description）+ 正文写步骤
```

### 7.4.2 将 Skill 安装到其他项目

项目提供了安装脚本（`install.sh` / `install.bat`），可以把 skill 模板批量安装到目标项目：

```bash
# macOS / Linux
./examples/commands/install.sh ~/projects/my-app

# Windows
examples\commands\install.bat C:\projects\my-app
```

脚本会把 `SKILL.md` 文件复制到目标项目的 `.claude/skills/` 目录下，已存在的文件会跳过。

---

## 7.5 小结

Hook 负责"自动跑起来"，Skill 负责"怎么跑"——两者配合，把原来每次都要手动描述的审查流程变成一个 `/review-bot` 搞定。记住那个分工原则：轻量操作放 Hook，重量级编排交给 Skill。

---

