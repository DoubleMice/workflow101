# Ch6: 结果聚合 — 把散装结果变成一份正经报告

> 四个专家各说各的，你需要一个人把它们整理成老板能看懂的东西。
>
> | 章节 | 关键词 |
> |:-----|:------|
> | Ch0 工具选型 | 工具选型 · 开发模式 |
> | Ch1 需求分析 | Plan Agent · 需求分析 |
> | Ch2 搭建脚手架 | CLAUDE.md · CLI 搭建 |
> | Ch3 解析 Git Diff | Explore Agent · Git Diff |
> | Ch4 Agent 设计 | Agent 设计 · Prompt 工程 |
> | Ch5 Fan-out/Fan-in | Fan-out/Fan-in · 并行执行 |
> | **► Ch6 结果聚合** | **结果聚合 · 条件逻辑** |
> | Ch7 Hooks 与 Skills | Hooks · Skills |
> | Ch8 测试驱动 | 测试策略 · TDD |
> | Ch9 六种编排模式 | 模式提炼 · 最佳实践 |
> | 附录 课后作业 | Workflow 实战 |

**术语**

- Verdict（裁定，审查的最终结论：通过/警告/不通过）
- JSON（JavaScript Object Notation，轻量数据交换格式）
- Enum（枚举，一组命名常量的集合）
- CI/CD（Continuous Integration/Continuous Delivery，持续集成/持续交付）
- Deduplication（去重，合并重复的审查结果）

## 6.1 场景引入

四个审查 agent 跑完了，你手里有四份独立的审查结果。安全 agent 说发现了 2 个问题，性能 agent 说有 1 个警告，风格 agent 提了 5 条建议，逻辑 agent 说一切正常。

现在问题来了：你要把这些散装信息变成一份结构化的报告，让人一眼就能看出"这个 PR 能不能合"。

---

## 6.2 结果聚合的三个层次

**层次 1：简单拼接** — 把四份结果首尾相连。能用，但不好用。读者要自己去找重点。

**层次 2：分类汇总** — 按严重程度排序，critical 放最前面。好一些，但缺少全局判断。

**层次 3：智能聚合** — 不仅汇总，还给出整体评估："这个 PR 有 2 个严重问题必须修复，3 个建议可以考虑。结论：修复后再合并。"

要做的是层次 3。

### 6.2.1 条件逻辑：根据结果做决策

报告不只是展示数据，还要给出建议。这需要条件逻辑：

```
if 有 critical 问题:
    verdict = "❌ 不建议合并，请先修复严重问题"
elif 有 warning:
    verdict = "⚠️ 可以合并，但建议关注以下警告"
else:
    verdict = "✅ 审查通过，可以合并"
```

这种"根据上游结果决定下游行为"的模式，在 workflow 编排中非常常见。

---

## 6.3 实操复现：实现报告生成器

### Step 1: 定义报告数据结构

**review_bot/reporter.py**:

```python
"""Report generator — aggregates review results."""
from dataclasses import dataclass, field
from enum import Enum

from .agents.base import ReviewIssue


class Verdict(Enum):
    PASS = "pass"
    WARN = "warn"
    FAIL = "fail"


@dataclass
class Report:
    """Structured review report."""

    issues: list[ReviewIssue] = field(default_factory=list)
    agent_errors: list[str] = field(default_factory=list)

    @property
    def verdict(self) -> Verdict:
        if any(i.severity == "critical" for i in self.issues):
            return Verdict.FAIL
        if any(i.severity == "warning" for i in self.issues):
            return Verdict.WARN
        return Verdict.PASS
```

### Step 2: 实现 Markdown 报告渲染

```python
VERDICT_DISPLAY = {
    Verdict.PASS: "✅ 审查通过，可以合并",
    Verdict.WARN: "⚠️ 可以合并，但请关注以下警告",
    Verdict.FAIL: "❌ 不建议合并，请先修复严重问题",
}


def render_markdown(report: Report) -> str:
    """Render report as Markdown."""
    lines = ["# Code Review Report", ""]
    lines.append(f"**Verdict**: {VERDICT_DISPLAY[report.verdict]}")
    lines.append("")

    # Group issues by severity
    for severity in ("critical", "warning", "info"):
        matched = [i for i in report.issues if i.severity == severity]
        if not matched:
            continue
        lines.append(f"## {severity.upper()} ({len(matched)})")
        lines.append("")
        for issue in matched:
            loc = f"{issue.file_path}:{issue.line}" if issue.line else issue.file_path
            lines.append(f"- **{loc}**: {issue.description}")
            lines.append(f"  - Suggestion: {issue.suggestion}")
        lines.append("")

    if report.agent_errors:
        lines.append("## Agent Errors")
        for err in report.agent_errors:
            lines.append(f"- {err}")

    return "\n".join(lines)
```

### Step 3: 接入 CLI — `report` 子命令

报告生成器需要一个 CLI 入口，让 `/review-bot` skill 能通过管道调用：

```python
# review_bot/cli.py 中新增 report 子命令
# 需要在文件顶部添加: import json, sys

@app.command()
def report(
    issues_json: str = typer.Option(
        None, "--issues", help="JSON array of issues (or read from stdin)",
    ),
) -> None:
    """Generate a Markdown review report from JSON issues."""
    if issues_json:
        raw = issues_json
    else:
        raw = sys.stdin.read()

    data = json.loads(raw)
    issues = [
        ReviewIssue(
            severity=item.get("severity", "info"),
            file_path=item.get("file", "unknown"),
            line=item.get("line"),
            description=item.get("description", ""),
            suggestion=item.get("suggestion", ""),
        )
        for item in data
    ]
    result = Report(issues=issues)
    typer.echo(render_markdown(result))
```

这样 `/review-bot` skill 的最后一步就能直接调用：

```bash
echo '[{"severity":"critical","file":"parser.c","line":42,...}]' | review-bot report
```

> ⚠️ **架构要点**：`report` 子命令从 stdin 读取 JSON 数组，输出 Markdown 报告。它是纯工具层——不关心 JSON 从哪来（可以是 4 个并行 agent 的合并结果，也可以是手动构造的测试数据）。这种设计让它可独立测试、可复用。

> ⚠️ **注意 CLI 用法变化**：添加 `report` 后，typer 从单命令自动提升模式切换为多命令子命令模式。之前 `review-bot HEAD~1` 的用法现在变成了 `review-bot diff HEAD~1`。这是 typer 的默认行为——只有一个命令时自动提升，两个以上时显示子命令列表。

生成的报告长这样：

```markdown
# Code Review Report

**Verdict**: ❌ 不建议合并，请先修复严重问题

## CRITICAL (1)

- **parser.c:42**: Buffer overflow — read() writes 256 bytes into 64-byte buffer
  - Suggestion: Use bounded read: read(sock, buf, sizeof(buf) - 1)

## WARNING (2)

- **conn_pool.c:15**: malloc in loop without free on error path
  - Suggestion: Add cleanup label with goto for error handling
- **http.c:88**: Unchecked return value from snprintf (possible truncation)
  - Suggestion: Check return value and handle truncation

## INFO (3)

- **config.h:5**: Magic number 8192
  - Suggestion: Use named constant MAX_BUFFER_SIZE
```

---

## 6.4 提炼模板：结果聚合模式

```
1. 收集多个来源的结果
   ↓
2. 标准化（统一格式）
   ↓
3. 分类排序（按优先级）
   ↓
4. 条件判断（给出整体评估）
   ↓
5. 渲染输出（Markdown / JSON / HTML）
```

关键设计决策：**统一输出格式要在 agent 设计阶段就定好**（Ch4 做的），而不是在聚合阶段再去适配。

### 6.4.1 结果去重

四个 agent 独立运行（Ch5 的设计决策），偶尔会发现同一个问题。比如安全 agent 和逻辑 agent 都标记了"未处理的异常"。

简单的去重策略：如果两个 issue 的 `file_path` 和 `line` 相同，保留 severity 更高的那个。

```python
def deduplicate(issues: list[ReviewIssue]) -> list[ReviewIssue]:
    """Remove duplicate issues, keeping the highest severity."""
    severity_rank = {"critical": 3, "warning": 2, "info": 1}
    seen: dict[tuple[str, int | None], ReviewIssue] = {}
    for issue in issues:
        key = (issue.file_path, issue.line)
        if key not in seen or severity_rank.get(issue.severity, 0) > severity_rank.get(seen[key].severity, 0):
            seen[key] = issue
    return list(seen.values())
```

> 💡 **Tip**: 去重不是必须的。有些团队更喜欢保留所有 agent 的原始输出，让人来判断是否重复。根据你的场景选择。

### 6.4.2 JSON 输出

Ch1 的设计决策中选了"Markdown 给人看，JSON 给程序用"。JSON 输出方便下游工具消费（比如 CI/CD 流水线根据 verdict 决定是否阻断合并）：

```python
import json

def render_json(report: Report) -> str:
    """Render report as JSON for programmatic consumption."""
    return json.dumps({
        "verdict": report.verdict.value,
        "issue_count": len(report.issues),
        "issues": [
            {
                "severity": i.severity,
                "file": i.file_path,
                "line": i.line,
                "description": i.description,
                "suggestion": i.suggestion,
            }
            for i in report.issues
        ],
    }, indent=2, ensure_ascii=False)
```

---

## 6.5 小结

聚合不是把四份结果拼在一起就完事。统一格式、按严重程度排序、给出整体 verdict——这些要在 agent 设计阶段就想清楚，聚合阶段只是收割前面的设计决策。

---

