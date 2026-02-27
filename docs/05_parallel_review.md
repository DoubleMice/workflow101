# Ch5: Fan-out/Fan-in — 四个 Agent 同时开工

> 串行审查像排队买奶茶，并行审查像四个窗口同时出餐。
>
> | 章节 | 关键词 |
> |:-----|:------|
> | Ch0 工具选型 | 工具选型 · 开发模式 |
> | Ch1 需求分析 | Plan Agent · 需求分析 |
> | Ch2 搭建脚手架 | CLAUDE.md · CLI 搭建 |
> | Ch3 解析 Git Diff | Explore Agent · Git Diff |
> | Ch4 Agent 设计 | Agent 设计 · Prompt 工程 |
> | **► Ch5 Fan-out/Fan-in** | **Fan-out/Fan-in · 并行执行** |
> | Ch6 结果聚合 | 结果聚合 · 条件逻辑 |
> | Ch7 Hooks 与 Skills | Hooks · Skills |
> | Ch8 测试驱动 | 测试策略 · TDD |
> | Ch9 六种编排模式 | 模式提炼 · 最佳实践 |
> | 附录 课后作业 | Workflow 实战 |

**术语**

- Fan-out/Fan-in（扇出/扇入，任务并行分发再汇总结果的模式）
- Subagent（子代理，由主 Agent 派出执行子任务）
- Context Isolation（上下文隔离，每个 subagent 拥有独立的对话上下文）
- Timeout（超时，等待操作完成的最大时间限制）

**本章新概念**

| 概念 | 解决什么问题 |
|------|------------|
| Ch5 Fan-out/Fan-in | 4 个 Agent 串行太慢——同时派出去，最后统一收结果 |
| Subagent | 子任务的中间过程塞满主 Agent 的记忆——独立上下文，只带结论回来 |

## 5.1 场景引入

上一章设计了四个审查 agent。如果让它们一个接一个地跑：

```
安全审查（30秒）→ 性能审查（30秒）→ 风格审查（30秒）→ 逻辑审查（30秒）= 120秒
```

但它们之间完全没有依赖——安全审查不需要等性能审查的结果。那为什么不让它们同时跑？

```
安全审查（30秒）─┐
性能审查（30秒）─┤
风格审查（30秒）─┼→ 汇总 = 30秒 + 汇总时间
逻辑审查（30秒）─┘
```

这就是 **Fan-out / Fan-in** 模式：把任务分发（fan-out）给多个 agent，等它们都完成后收集结果（fan-in）。

---

## 5.2 设计思维：Claude Code 的并行执行机制

### 5.2.1 怎么实现并行？

在 Claude Code 中，并行执行的关键是：**在同一条消息中发起多个 Task 调用**。

串行（一个接一个）：
```
消息1: Task(agent=security, ...)  → 等结果
消息2: Task(agent=performance, ...) → 等结果
消息3: Task(agent=style, ...)     → 等结果
```

并行（同时发出）：
```
消息1: Task(agent=security, ...)
        Task(agent=performance, ...)
        Task(agent=style, ...)
        Task(agent=logic, ...)
        → 同时执行，一起返回
```

### 5.2.2 前台 vs 后台 Agent

Claude Code 的 Task tool 有一个 `run_in_background` 参数：

- **前台（默认）**：主 agent 等待 subagent 完成后才继续。适合需要结果才能进行下一步的场景。
- **后台**：主 agent 不等待，继续做其他事。适合"发出去就行，结果晚点再看"的场景。

审查场景用前台模式——因为需要等所有 agent 都审查完，才能汇总报告。

### 5.2.3 上下文隔离：为什么并行 Agent 不会互相干扰？

每个 subagent 都有自己独立的上下文窗口。安全 agent 读了 100 个文件，这些内容不会出现在性能 agent 的上下文里。

这很重要，原因有二：
1. **避免干扰**：安全 agent 的分析不会影响性能 agent 的判断
2. **节省上下文**：主 agent 只收到每个 subagent 的最终结论，不会被中间过程撑爆

---

## 5.3 实操复现：实现并行审查调度

### Step 1: 创建结果聚合层

注意：这里不实现 LLM 调度逻辑。Python 代码只负责**数据结构和结果解析**，真正的并行调度由 `/review-bot` skill 通过 Claude Code 的 Task tool 完成。

**review_bot/scheduler.py**:

```python
"""Result aggregation utilities for Claude Code skill orchestration.

This module provides data structures for collecting and aggregating
review results from parallel Claude Code subagents. The actual LLM
orchestration happens through the /review-bot skill, not Python code.
"""
import json
from dataclasses import dataclass, field

from .agents.base import ReviewIssue


@dataclass
class AgentResult:
    """Result from a single agent's review."""

    agent_name: str
    issues: list[ReviewIssue] = field(default_factory=list)
    error: str | None = None


@dataclass
class ReviewSession:
    """Aggregated results from all agents."""

    results: list[AgentResult] = field(default_factory=list)

    @property
    def all_issues(self) -> list[ReviewIssue]:
        return [
            issue
            for result in self.results
            for issue in result.issues
        ]

    @property
    def has_critical(self) -> bool:
        return any(i.severity == "critical" for i in self.all_issues)
```

### Step 2: 实现 Agent 输出解析

每个 subagent 返回的是自由文本（包含 JSON-per-line 格式的 issue）。需要一个解析函数把文本转成结构化数据：

```python
def parse_agent_output(agent_name: str, raw_output: str) -> AgentResult:
    """Parse raw agent output text into structured AgentResult.

    Extracts JSON issue objects from agent response text.
    Each line starting with '{' is treated as a potential JSON issue.
    """
    result = AgentResult(agent_name=agent_name)

    for line in raw_output.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            data = json.loads(line)
            result.issues.append(ReviewIssue(
                severity=data.get("severity", "info"),
                file_path=data.get("file", "unknown"),
                line=data.get("line"),
                description=data.get("description", ""),
                suggestion=data.get("suggestion", ""),
            ))
        except (json.JSONDecodeError, KeyError):
            continue

    return result
```

这段代码的关键设计：

1. **只提取以 `{` 开头的行**：agent 输出中可能有解释性文字，只有 JSON 行才是结构化数据
2. **容错**：无效 JSON 静默跳过，不会让整个解析崩掉
3. **纯函数**：输入文本，输出结构化数据，可独立测试

> ⚠️ **架构要点**：Python 代码只做"工具层"——解析文本、生成报告。LLM 编排（谁来跑、怎么并行）完全交给 Claude Code 的 `/review-bot` skill。这种分层让 Python 代码可测试、可复用，而编排逻辑保持灵活。

### Step 3: 用 `/review-bot` Skill 触发并行审查

这是关键部分。实际项目中，并行审查通过 **Skill**（`.claude/skills/review-bot/SKILL.md`）触发，而不是每次手动写一大段 prompt。

在 Claude Code 中输入：

```
/review-bot HEAD~3
```

Claude Code 读取 `.claude/skills/review-bot/SKILL.md`，把 `HEAD~3` 替换到 `$ARGUMENTS`，然后按步骤执行。Skill 文件的核心内容：

```markdown
Run a C/C++ code review workflow.

## Step 1: Get the diff
review-bot diff $ARGUMENTS

## Step 2: Fan-out — 4 parallel review agents
Launch exactly 4 Task tool calls IN PARALLEL (in a single message). Each Task must:
- Use subagent_type: "general-purpose"
- Include the COMPLETE agent prompt below
- Append the full diff content at the end

**Task 1 — Security:**
> You are a C/C++ security expert. Focus ONLY on security...
> Output one JSON object per line (no code fences):
> {"severity":"...","file":"...","line":...,"description":"...","suggestion":"..."}

**Task 2 — Performance:**
> You are a C/C++ performance engineer. Focus ONLY on performance.
> Ignore security, style, logic. Check for: memory leaks, unnecessary heap allocations
> in loops, cache-unfriendly access, unnecessary copies, missing reserve(), blocking I/O.
> Output format: same JSON-per-line as above. If none: "No performance issues detected."

**Task 3 — Style:**
> You are a C/C++ style reviewer. Focus ONLY on style and readability.
> Ignore security, performance, logic. Check for: missing/inconsistent header guards,
> const correctness, raw new/delete vs RAII, naming conventions, include order, magic numbers.
> Output format: same JSON-per-line. If none: "No style issues detected."

**Task 4 — Logic:**
> You are a C/C++ logic reviewer. Focus ONLY on correctness.
> Ignore security, performance, style. Check for: undefined behavior, signed/unsigned
> mismatch, off-by-one errors, resource leaks on error paths, unchecked return values,
> incorrect pointer arithmetic. Output format: same JSON-per-line. If none: "No logic issues detected."

## Step 3: Fan-in — collect and merge
Extract all lines starting with `{` from each agent's response.

## Step 4: Generate report
echo '<merged_json_array>' | review-bot report
```

Claude Code 内部会同时发起 4 个 Task 调用（概念示意）：

```
Task(subagent_type="general-purpose", prompt="[Security prompt + diff]")
Task(subagent_type="general-purpose", prompt="[Performance prompt + diff]")
Task(subagent_type="general-purpose", prompt="[Style prompt + diff]")
Task(subagent_type="general-purpose", prompt="[Logic prompt + diff]")
```

四个 subagent 同时启动，各自独立审查，完成后结果一起返回给主 agent。

> ⚠️ **踩坑提醒：Prompt 必须内联**：Skill 文件中必须把每个 agent 的完整 prompt 写进去，不能写"读取 `.claude/agents/security-reviewer.md`"。因为 subagent 有独立的上下文窗口，看不到主 agent 读过的文件。这是实践中最容易犯的错误。

### Step 4: 三层架构的协作

回顾 Ch2 的 CLAUDE.md，其中定义了三层架构：

```markdown
## Architecture
- Python 代码 = 工具层（diff 解析、报告生成）
- `.claude/skills/review-bot/SKILL.md` = 编排层（通过 Claude Code Task tool 调度）
- `.claude/agents/*.md` = Agent 定义（每个 agent 的角色和 prompt）
```

在并行审查中，三层各司其职：

| 层 | 职责 | 文件 |
|---|------|------|
| 工具层 | `review-bot diff` 获取 diff，`review-bot report` 生成报告 | `cli.py`, `diff_parser.py`, `reporter.py` |
| 编排层 | `/review-bot` skill 调度 4 个并行 Task，收集结果 | `.claude/skills/review-bot/SKILL.md` |
| Agent 层 | 每个 agent 的专业 prompt（运行时真相） | `.claude/agents/*.md` |

注意：Skill 文件中内联了 agent prompt（因为 subagent 上下文隔离），而 `.claude/agents/*.md` 作为独立的 agent 定义文件，可以在其他场景中被单独调用。`registry.py` 则是 Python 侧的参考副本，用于测试和程序化访问。

> ⚠️ **踩坑提醒**: 并行 agent 的数量不是越多越好。Claude Code 有并发限制（建议最多 4 个同时运行）。超过这个数量，反而会因为资源竞争变慢。

### 5.3.5 并行执行的实战注意事项

**1. 前台 vs 后台：怎么选？**

```
# 概念示意（非可执行代码）

# 前台（默认）：主 agent 等所有 subagent 完成后才继续
Task(subagent_type="general-purpose", prompt="...")

# 后台：主 agent 不等待，继续做其他事
Task(subagent_type="general-purpose", prompt="...", run_in_background=True)
```

审查场景用前台——因为必须等所有 agent 都审查完，才能汇总报告。后台模式适合"发出去就行，结果晚点再看"的场景，比如在后台跑一个耗时的代码分析，同时主 agent 继续和你对话。

**2. 如果一个 agent 超时了怎么办？**

回顾 Ch1 的设计决策：部分失败不阻塞整体。在 `scheduler.py` 中，`AgentResult` 有一个 `error` 字段。如果某个 agent 超时或报错，主 agent 会记录错误信息，但不会阻塞其他 agent 的结果。

**3. 并行 agent 的 prompt 要自包含**

每个 subagent 有独立的上下文窗口，看不到主 agent 的对话历史。所以 prompt 必须包含所有必要信息——不能说"用之前讨论的格式"，要把格式完整写进去。这就是 Ch4 中每个 agent prompt 都自带完整输出格式说明的原因。

---

## 5.4 提炼模板：Fan-out / Fan-in 模式

```
1. 准备输入数据
   ↓
2. Fan-out: 同时派出 N 个 agent
   ├── Agent A (独立上下文)
   ├── Agent B (独立上下文)
   └── Agent C (独立上下文)
   ↓
3. Fan-in: 收集所有结果
   ↓
4. 聚合处理
```

适用场景：
- 多个独立的审查/分析任务
- 批量处理多个文件
- 多维度评估（安全 + 性能 + 风格 + ...）

不适用场景：
- 步骤之间有依赖（用顺序工作流）
- 后一步需要前一步的结果（用 pipeline）

---

## 5.5 小结

- 并行执行的关键：在同一条消息中发起多个 Task 调用
- Fan-out / Fan-in 是最常用的并行模式
- 每个 subagent 上下文隔离，互不干扰
- 并发数建议不超过 4 个

---

