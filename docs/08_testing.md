# Ch8: 测试驱动 — 谁来审查审查者？

> 你写了一个审查代码的工具，但这个工具本身的代码谁来审查？
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
> | Ch7 Hooks 与 Skills | Hooks · Skills |
> | **► Ch8 测试驱动** | **测试策略 · TDD** |
> | Ch9 六种编排模式 | 模式提炼 · 最佳实践 |
> | 附录 课后作业 | Workflow 实战 |

**术语**

- TDD（Test-Driven Development，测试驱动开发，Red→Green→Refactor 循环）
- Pytest（Python 主流测试框架）
- Fixture（测试夹具，预置的测试数据或环境）
- Mock（模拟对象，替代真实依赖的假实现）
- Regression（回归，修改代码后旧功能意外损坏）
- CI（Continuous Integration，持续集成）

## 8.1 场景引入

Review Bot 已经能自动审查代码了。但有个尴尬的问题：如果 diff 解析器有 bug，把新增行当成删除行呢？如果报告生成器漏掉了 critical 级别的问题呢？

工具本身的质量，决定了审查结果的可信度。这一章给 Review Bot 加上测试，并用 Claude Code 的 agent 编排来自动化测试流程。

---

## 8.2 验证优先 — 最高杠杆的实践

官方文档把"给 Claude 一种验证自己工作的方式"列为**最高杠杆**的操作。意思是：不要只告诉 Claude 做什么，还要告诉它怎么确认做对了。

### 8.2.1 在 Prompt 中提供验证标准

**❌ 没有验证标准**：
```
帮我实现 diff 解析器。
```

**✅ 带验证标准**：
```
帮我实现 diff 解析器。
验证标准：
1. 运行 pytest tests/test_diff_parser.py -x 全部通过
2. 空 diff 输入返回空 DiffResult（files 列表为空）
3. 多文件 diff 能正确拆分为独立的 FileChange
```

带验证标准的 prompt 让 Claude 能自我检查——实现完后它会主动跑测试、验证边界情况，而不是写完就交差。

### 8.2.2 验证的三个层次

| 层次 | 方式 | 示例 |
|------|------|------|
| 自动化验证 | 测试套件、linter、类型检查 | `pytest`、`ruff check`、`mypy` |
| 结构化验证 | 在 prompt 中写明预期输出 | "输入 X 应该返回 Y" |
| 人工验证 | 审查 Claude 的输出 | 检查生成的报告是否合理 |

> 💡 **Tip**: 在 CLAUDE.md 的 Rules 中加入验证相关指令，让 Claude 养成"做完就验证"的习惯：
> ```markdown
> ## Rules
> - After implementing any function, run its tests immediately
> - Before committing, run `pytest tests/ -x -q` and `ruff check .`
> ```

---

## 8.3 测试策略

### 8.3.1 该测什么？

Review Bot 有四个核心模块，每个模块的测试重点不同：

| 模块 | 测试重点 | 测试类型 |
|------|---------|---------|
| diff_parser | 能正确解析各种 diff 格式 | 单元测试 |
| agents | prompt 生成正确、输出格式符合预期 | 单元测试 |
| scheduler | `parse_agent_output` 能从自由文本中提取 JSON issue | 单元测试 |
| reporter | 聚合逻辑正确、verdict 判断准确 | 单元测试 |
| 整体流程 | 从 diff 到报告的完整链路 | 集成测试 |

### 8.3.2 用 Agent 写测试

还记得 Ch0 介绍的 **TDD with AI** 开发模式吗？核心循环是 Red → Green → Refactor，AI 在每个阶段都能帮忙。在 Review Bot 的场景里可以这样用：

```
1. Red:   你描述期望行为 → Claude Code 生成测试（此时测试应该失败）
2. Green: Claude Code 写最小实现让测试通过
3. Refactor: Claude Code 重构代码，测试保证不破坏功能
```

具体怎么让 Claude Code 写测试？prompt 的质量决定测试的质量：

**❌ 太模糊的 prompt**：
```
帮我写 diff_parser 的测试。
```

**✅ 好的 prompt**：
```
帮我为 review_bot/diff_parser.py 写单元测试。
要求：
1. 用 pytest，测试数据用 fixture
2. 覆盖以下场景：
   - 正常的单文件 diff（有增有删）
   - 多文件 diff
   - 空 diff
   - 只有新增、只有删除
   - 二进制文件（应跳过）
3. 每个测试函数只测一件事
4. 测试命名用 test_<功能>_<场景> 格式
```

Claude Code 会先用 Explore agent 读取源代码，理解逻辑，然后生成测试。它往往能想到你忽略的边界情况——因为它会系统性地遍历代码路径，而人容易只测 happy path。

> 💡 **Tip**: 让 AI 写测试时，先跑一遍看看是否全部通过。如果全部通过，反而要警惕——可能测试写得太宽松了。好的测试应该在代码有 bug 时能失败。

---

## 8.4 实操复现：为 Review Bot 添加测试

### Step 1: diff_parser 单元测试

**tests/test_diff_parser.py**:

```python
"""Tests for diff parser."""
import pytest

from review_bot.diff_parser import FileChange, DiffResult, parse_diff


SAMPLE_DIFF = """\
diff --git a/parser.c b/parser.c
index abc1234..def5678 100644
--- a/parser.c
+++ b/parser.c
@@ -1,3 +1,5 @@
 #include <stdio.h>
+#include <stdlib.h>
+#include <string.h>

 void parse()
-    return;
+    printf("parsing");
"""


def test_parse_diff_file_count():
    result = parse_diff(SAMPLE_DIFF)
    assert len(result.files) == 1
    assert result.files[0].path == "parser.c"


def test_parse_diff_additions():
    result = parse_diff(SAMPLE_DIFF)
    assert result.files[0].additions == 3  # stdlib.h, string.h, printf


def test_parse_diff_deletions():
    result = parse_diff(SAMPLE_DIFF)
    assert result.files[0].deletions == 1  # return;


def test_parse_diff_empty():
    result = parse_diff("")
    assert len(result.files) == 0
    assert result.total_additions == 0


def test_summary():
    result = parse_diff(SAMPLE_DIFF)
    assert "1 files changed" in result.summary
```

### Step 2: reporter 单元测试

**tests/test_reporter.py**:

```python
"""Tests for report generator."""
from review_bot.agents.base import ReviewIssue
from review_bot.reporter import Report, Verdict, render_markdown


def _make_issue(severity: str = "warning") -> ReviewIssue:
    return ReviewIssue(
        severity=severity,
        file_path="parser.c",
        line=10,
        description="test issue",
        suggestion="fix it",
    )


def test_verdict_pass():
    report = Report(issues=[])
    assert report.verdict == Verdict.PASS


def test_verdict_warn():
    report = Report(issues=[_make_issue("warning")])
    assert report.verdict == Verdict.WARN


def test_verdict_fail():
    report = Report(issues=[_make_issue("critical")])
    assert report.verdict == Verdict.FAIL


def test_render_markdown_contains_verdict():
    report = Report(issues=[_make_issue("critical")])
    md = render_markdown(report)
    assert "CRITICAL" in md
    assert "parser.c:10" in md
```

### Step 3: 测试 Agent Prompt 的输出

Agent 的 prompt 是 Review Bot 的核心资产。怎么测试 prompt 生成是否正确？

**tests/test_agents.py**:

```python
"""Tests for review agents."""
from review_bot.agents.registry import (
    SECURITY_AGENT,
    PERFORMANCE_AGENT,
    STYLE_AGENT,
    LOGIC_AGENT,
    ALL_AGENTS,
)


FAKE_DIFF = "diff --git a/parser.c b/parser.c\n+#include <stdlib.h>\n"


def test_all_agents_registered():
    assert len(ALL_AGENTS) == 4


def test_agent_names_unique():
    names = [a.name for a in ALL_AGENTS]
    assert len(names) == len(set(names))


def test_build_prompt_injects_diff():
    prompt = SECURITY_AGENT.build_prompt(FAKE_DIFF)
    assert FAKE_DIFF in prompt
    assert "security" in prompt.lower()


def test_each_agent_has_output_format():
    """Every agent prompt must specify the output format."""
    for agent in ALL_AGENTS:
        prompt = agent.build_prompt(FAKE_DIFF)
        assert "severity" in prompt, f"{agent.name} missing severity format"
        assert "suggestion" in prompt, f"{agent.name} missing suggestion format"


def test_each_agent_has_boundary():
    """Every agent prompt must have a 'Focus ONLY' boundary."""
    for agent in ALL_AGENTS:
        prompt = agent.build_prompt(FAKE_DIFF)
        assert "Focus ONLY" in prompt, f"{agent.name} missing focus boundary"
```

注意最后两个测试——它们不是测业务逻辑，而是测 **prompt 的结构约束**。Ch4 中说过，好的 agent prompt 必须有统一输出格式和明确边界。这两个测试就是把这些设计原则变成了可执行的断言。

> ⚠️ **踩坑提醒**: 不要试图测试 LLM 的输出内容（比如"安全 agent 应该能发现 buffer overflow"）。LLM 输出是非确定性的，这类测试会时过时不过。只测你能控制的部分：prompt 生成、数据结构、聚合逻辑。

### Step 4: 测试 Agent 输出解析

`parse_agent_output` 是连接 LLM 输出和结构化数据的桥梁——它从 agent 的自由文本中提取 JSON issue。这个函数必须足够健壮，因为 LLM 输出不总是完美的。

**tests/test_scheduler.py**:

```python
"""Tests for result aggregation and agent output parsing."""
from review_bot.agents.base import ReviewIssue
from review_bot.scheduler import (
    AgentResult,
    ReviewSession,
    parse_agent_output,
)


def test_parse_agent_output_with_json_issues():
    """Extract JSON issues from mixed text output."""
    raw = """Here are the security issues found:
{"severity": "critical", "file": "parser.c", "line": 10, "description": "Buffer overflow", "suggestion": "Use bounded read"}
Some other text
{"severity": "warning", "file": "conn.c", "line": null, "description": "Unchecked return", "suggestion": "Check retval"}
"""
    result = parse_agent_output("security", raw)
    assert result.agent_name == "security"
    assert len(result.issues) == 2
    assert result.issues[0].severity == "critical"
    assert result.issues[1].file_path == "conn.c"


def test_parse_agent_output_no_issues():
    """Agent found nothing — should return empty list."""
    raw = "No security issues detected."
    result = parse_agent_output("security", raw)
    assert len(result.issues) == 0


def test_parse_agent_output_invalid_json():
    """Malformed JSON lines should be silently skipped."""
    raw = "{not valid json}\n{also bad"
    result = parse_agent_output("test", raw)
    assert len(result.issues) == 0


def test_review_session_aggregation():
    """ReviewSession aggregates across agents."""
    r1 = AgentResult(agent_name="security", issues=[
        ReviewIssue("critical", "a.c", 1, "desc", "fix"),
    ])
    r2 = AgentResult(agent_name="style", issues=[
        ReviewIssue("info", "b.c", 2, "desc2", "fix2"),
    ])
    session = ReviewSession(results=[r1, r2])
    assert len(session.all_issues) == 2
    assert session.has_critical is True
```

这组测试覆盖了三个关键场景：正常提取、空输出、畸形 JSON。注意 `test_parse_invalid_json_skipped` ——LLM 有时会输出不完整的 JSON，解析器必须容错而不是崩溃。

### Step 5: 集成测试 — 从 diff 到报告的完整链路

单元测试验证每个零件，集成测试验证零件组装后能不能跑。

**tests/test_integration.py**:

```python
"""Integration tests — full pipeline from diff to report."""
from review_bot.agents.base import ReviewIssue
from review_bot.diff_parser import parse_diff
from review_bot.reporter import Report, Verdict, render_markdown


MULTI_FILE_DIFF = """\
diff --git a/parser.c b/parser.c
--- a/parser.c
+++ b/parser.c
@@ -1,2 +1,3 @@
 #include <stdio.h>
+#include <stdlib.h>
diff --git a/conn_pool.c b/conn_pool.c
--- a/conn_pool.c
+++ b/conn_pool.c
@@ -5,3 +5,2 @@
-old_alloc()
+new_alloc()
"""


def test_full_pipeline_pass():
    """No issues → PASS verdict."""
    diff = parse_diff(MULTI_FILE_DIFF)
    assert len(diff.files) == 2

    report = Report(issues=[])
    assert report.verdict == Verdict.PASS
    md = render_markdown(report)
    assert "通过" in md


def test_full_pipeline_fail():
    """Critical issue → FAIL verdict with details in report."""
    diff = parse_diff(MULTI_FILE_DIFF)

    issues = [
        ReviewIssue(
            severity="critical",
            file_path=diff.files[0].path,
            line=2,
            description="Buffer overflow — read() exceeds buffer size",
            suggestion="Use bounded read with sizeof(buf)",
        )
    ]
    report = Report(issues=issues)
    assert report.verdict == Verdict.FAIL

    md = render_markdown(report)
    assert "CRITICAL" in md
    assert "parser.c:2" in md
    assert "Buffer overflow" in md
```

集成测试的关键：用真实的数据结构走完整条链路，而不是 mock 掉中间环节。

### Step 6: 用 Hook 自动跑测试

在 `.claude/settings.json` 中添加测试 hook：

```json
{
  "PostToolUse": [
    {
      "matcher": { "tools": ["WriteTool", "EditTool"], "input_contains": "review_bot/" },
      "hooks": [{ "type": "command", "command": "pytest tests/ -x -q 2>&1 | tail -5" }]
    }
  ]
}
```

每次 Claude Code 修改了 `review_bot/` 下的 Python 文件，自动跑测试。`-x` 遇到第一个失败就停，`-q` 精简输出，`tail -5` 只显示最后几行结果。

### 8.4.7 AI 写测试的常见陷阱

让 Claude Code 写测试很方便，但有几个坑要注意：

**陷阱 1：测试只验证当前实现，不验证预期行为**

```python
# ❌ 这个测试只是"拍了个快照"，不是在验证行为
def test_summary():
    result = parse_diff(SAMPLE_DIFF)
    assert result.summary == "1 files changed, 3 additions, 1 deletions"
```

如果 summary 格式改了（比如 "1 file changed" 去掉复数 s），这个测试就会失败——但功能其实没问题。更好的写法：

```python
# ✅ 验证关键信息存在，不绑定具体格式
def test_summary_contains_key_info():
    result = parse_diff(SAMPLE_DIFF)
    assert "1" in result.summary  # file count
    assert "3" in result.summary  # additions
```

**陷阱 2：过度 mock 导致测试没有意义**

```python
# ❌ mock 掉了所有东西，测试等于什么都没测
def test_review(mocker):
    mocker.patch("review_bot.diff_parser.get_diff", return_value="")
    mocker.patch("review_bot.diff_parser.parse_diff", return_value=DiffResult())
    # ... 这测的是什么？
```

原则：只 mock 外部依赖（git 命令、网络请求），不 mock 自己的代码。

**陷阱 3：AI 生成的测试数据太"完美"**

AI 倾向于生成格式完美的测试数据。但真实世界的 diff 可能有乱码、超长行、混合编码。手动加几个"脏数据"测试用例：

```python
def test_parse_diff_with_unicode():
    """Real diffs may contain non-ASCII characters."""
    diff = 'diff --git a/中文.py b/中文.py\n+print("你好")\n'
    result = parse_diff(diff)
    assert result.files[0].path == "中文.py"
```

### 8.4.8 测试驱动的 Bug 修复流程

当用户报告 Review Bot 有 bug 时，用 TDD 流程修复：

```
1. 复现：写一个失败的测试用例，精确描述 bug
   ↓
2. 确认红灯：跑测试，确认新测试确实失败
   ↓
3. 修复：让 Claude Code 修复代码，直到测试通过
   ↓
4. 回归：跑全量测试，确认没有破坏其他功能
```

在 Claude Code 中的实际操作：

```
用户报告：当 diff 中有文件重命名时，parse_diff 会崩溃。

请按以下步骤修复：
1. 先在 tests/test_diff_parser.py 中添加一个测试用例，
   用包含 rename 的 diff 数据，验证 parse_diff 不会崩溃
2. 跑测试确认它失败
3. 修改 parse_diff 让测试通过
4. 跑全量测试确认没有回归
```

这个流程的好处：bug 修复后，测试用例永远留在那里，防止同一个 bug 再次出现。

---

## 8.5 提炼模板：测试工作流模式

```
1. 写代码
   ↓
2. Hook 自动触发测试
   ↓
3. 测试失败 → Agent 自动修复 → 重新测试
   测试通过 → 继续下一步
```

在 CLAUDE.md 中加入测试相关指令：

```markdown
## Testing Rules
- Run `pytest tests/ -x -q` after any code change
- All tests must pass before committing
- New features must include tests
- Test edge cases: empty input, null values, boundary conditions
```

---

## 8.6 小结

给审查工具加测试不是仪式感，而是实际需要：diff 解析器出一个 bug，整个报告的可信度就垮了。养成在 prompt 里写验证标准的习惯——让 Claude 自己跑测试确认，比你事后检查省心得多。

---

