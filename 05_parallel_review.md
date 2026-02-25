# Ch5: 并行审查 — 四个 Agent 同时开工

> **本章目标**：实现四 Agent 并行审查，掌握 Fan-out/Fan-in 模式
>
> | 章节 | 关键词 |
> |:-----|:------|
> | Ch0 生态概览 | 工具选型 · 开发模式 |
> | Ch1 项目规划 | Plan Agent · 需求分析 |
> | Ch2 项目脚手架 | CLAUDE.md · CLI 搭建 |
> | Ch3 理解变更 | Explore Agent · Git Diff |
> | Ch4 设计审查团队 | Agent 设计 · Prompt 工程 |
> | **► Ch5 并行审查** | **Fan-out/Fan-in · 并行执行** |
> | Ch6 报告生成 | 结果聚合 · 条件逻辑 |
> | Ch7 自动化 | Hooks · Skills |
> | Ch8 质量保障 | 测试策略 · TDD |
> | Ch9 模板库 | 模式提炼 · 最佳实践 |
> | 附录 课后作业 | Workflow 实战 |

> 串行审查像排队买奶茶，并行审查像四个窗口同时出餐。

**术语**

- Fan-out/Fan-in（扇出/扇入，任务并行分发再汇总结果的模式）
- Subagent（子代理，由主 Agent 派出执行子任务）
- Context Isolation（上下文隔离，每个 subagent 拥有独立的对话上下文）
- Timeout（超时，等待操作完成的最大时间限制）

## 场景引入

上一章我们设计了四个审查 agent。如果让它们一个接一个地跑：

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

## 设计思维：Claude Code 的并行执行机制

### 怎么实现并行？

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

### 前台 vs 后台 Agent

Claude Code 的 Task tool 有一个 `run_in_background` 参数：

- **前台（默认）**：主 agent 等待 subagent 完成后才继续。适合需要结果才能进行下一步的场景。
- **后台**：主 agent 不等待，继续做其他事。适合"发出去就行，结果晚点再看"的场景。

我们的审查场景用前台模式——因为需要等所有 agent 都审查完，才能汇总报告。

### 上下文隔离：为什么并行 Agent 不会互相干扰？

每个 subagent 都有自己独立的上下文窗口。安全 agent 读了 100 个文件，这些内容不会出现在性能 agent 的上下文里。

这很重要，原因有二：
1. **避免干扰**：安全 agent 的分析不会影响性能 agent 的判断
2. **节省上下文**：主 agent 只收到每个 subagent 的最终结论，不会被中间过程撑爆

---

## 实操复现：实现并行审查调度

### Step 1: 创建调度器

**review_bot/scheduler.py**:

```python
"""Parallel review scheduler — fan-out/fan-in pattern."""
from dataclasses import dataclass, field

from .agents.base import ReviewAgent, ReviewIssue
from .agents.registry import ALL_AGENTS
from .diff_parser import DiffResult


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

> 💡 **为什么要有 `error` 字段？** 记得 Ch1 的设计决策吗——"一个 agent 挂了，其他的继续"。`error` 字段就是为了记录失败的 agent，而不是让整个审查流程崩掉。

### Step 2: 在 Claude Code 中触发并行审查

这是关键部分。在 Claude Code 中，你可以这样触发并行审查：

```
我有以下 git diff 内容需要审查。请同时派出 4 个 subagent 并行审查：
1. 安全审查 agent
2. 性能审查 agent
3. 风格审查 agent
4. 逻辑审查 agent

每个 agent 使用各自的专业 prompt，审查完后汇总结果。
```

Claude Code 内部会同时发起 4 个 Task 调用（以下为概念示意，非可执行代码——Task 是 Claude Code 的内部工具调用，用户通过自然语言指令触发，而非直接编写）：

```
Task(subagent_type="general-purpose", prompt="[Security Agent prompt + diff]")
Task(subagent_type="general-purpose", prompt="[Performance Agent prompt + diff]")
Task(subagent_type="general-purpose", prompt="[Style Agent prompt + diff]")
Task(subagent_type="general-purpose", prompt="[Logic Agent prompt + diff]")
```

四个 subagent 同时启动，各自独立审查，完成后结果一起返回给主 agent。

### Step 3: 用 CLAUDE.md 编排并行审查

为了让 Claude Code 自动执行并行审查，我们可以在 CLAUDE.md 中加入编排指令：

```markdown
## Review Workflow

When asked to review code, follow this workflow:

1. Parse the git diff to get structured change data
2. Fan-out: Launch 4 parallel subagents simultaneously:
   - Security agent (use security prompt)
   - Performance agent (use performance prompt)
   - Style agent (use style prompt)
   - Logic agent (use logic prompt)
3. Fan-in: Collect all results
4. Generate unified report
```

> ⚠️ **踩坑提醒**: 并行 agent 的数量不是越多越好。Claude Code 有并发限制（建议最多 4 个同时运行）。超过这个数量，反而会因为资源竞争变慢。

### 并行执行的实战注意事项

**1. 前台 vs 后台：怎么选？**

```
# 概念示意（非可执行代码）

# 前台（默认）：主 agent 等所有 subagent 完成后才继续
Task(subagent_type="general-purpose", prompt="...")

# 后台：主 agent 不等待，继续做其他事
Task(subagent_type="general-purpose", prompt="...", run_in_background=True)
```

我们的审查场景用前台——因为必须等所有 agent 都审查完，才能汇总报告。后台模式适合"发出去就行，结果晚点再看"的场景，比如在后台跑一个耗时的代码分析，同时主 agent 继续和你对话。

**2. 如果一个 agent 超时了怎么办？**

回顾 Ch1 的设计决策：部分失败继续。在 `scheduler.py` 中，`AgentResult` 有一个 `error` 字段。如果某个 agent 超时或报错，主 agent 会记录错误信息，但不会阻塞其他 agent 的结果。

**3. 并行 agent 的 prompt 要自包含**

每个 subagent 有独立的上下文窗口，看不到主 agent 的对话历史。所以 prompt 必须包含所有必要信息——不能说"用我们之前讨论的格式"，要把格式完整写进去。这就是 Ch4 中每个 agent prompt 都自带完整输出格式说明的原因。

---

## 提炼模板：Fan-out / Fan-in 模式

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

## 小结

- 并行执行的关键：在同一条消息中发起多个 Task 调用
- Fan-out / Fan-in 是最常用的并行模式
- 每个 subagent 上下文隔离，互不干扰
- 并发数建议不超过 4 个
- 下一章处理这些 agent 返回的结果

---

## 参考链接

- [From Tasks to Swarms](https://alexop.dev/posts/from-tasks-to-swarms-agent-teams-in-claude-code/)
- [Claude Code Agent Teams 实践指南](https://blog.laozhang.ai/en/posts/claude-code-agent-teams)

---

[上一章: Ch4 — 设计审查团队](04_agent_design.md) | [下一章: Ch6 — 报告生成](06_report.md)
