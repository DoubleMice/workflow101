# Ch2: 搭建脚手架 — CLAUDE.md + CLI 一步到位

> 好的开始是成功的一半。好的 CLAUDE.md 能省掉一半的反复纠正。
>
> | 章节 | 关键词 |
> |:-----|:------|
> | Ch0 工具选型 | 工具选型 · 开发模式 |
> | Ch1 需求分析 | Plan Agent · 需求分析 |
> | **► Ch2 搭建脚手架** | **CLAUDE.md · CLI 搭建** |
> | Ch3 解析 Git Diff | Explore Agent · Git Diff |
> | Ch4 Agent 设计 | Agent 设计 · Prompt 工程 |
> | Ch5 Fan-out/Fan-in | Fan-out/Fan-in · 并行执行 |
> | Ch6 结果聚合 | 结果聚合 · 条件逻辑 |
> | Ch7 Hooks 与 Skills | Hooks · Skills |
> | Ch8 测试驱动 | 测试策略 · TDD |
> | Ch9 六种编排模式 | 模式提炼 · 最佳实践 |
> | 附录 课后作业 | Workflow 实战 |

**术语**

- CLI（Command Line Interface，命令行界面）
- Linter（代码静态检查工具）
- Docstring（文档字符串，嵌在代码中的说明文本）
- Type Hints（类型提示，Python 的静态类型标注）
- pyproject.toml（Python 项目配置文件，PEP 621 标准）

**本章新概念**

| 概念 | 解决什么问题 |
|------|------------|
| CLAUDE.md | AI 每次都在猜你的偏好，反复纠正很累——写一份"入职手册"，启动即生效 |
| Sequential Workflow | 多个步骤有先后依赖——按顺序串起来，前一步的输出喂给下一步 |

## 2.1 场景引入

你新招了一个实习生，第一天上班。你会怎么做？

肯定不是直接甩一句"去把代码写了"。你会给他一份入职手册：公司用什么技术栈、代码风格是什么、哪些事情绝对不能做、遇到问题找谁。

CLAUDE.md 就是你给 Claude Code 的"入职手册"。没有它，Claude Code 每次都在猜你的偏好；有了它，它从第一行代码就知道该怎么写。

---

## 2.2 设计思维：CLAUDE.md 的三层配置

Claude Code 的配置有三个层级，从大到小：

```
~/.claude/CLAUDE.md          ← 全局：你所有项目的通用偏好
项目根目录/CLAUDE.md          ← 项目级：这个项目的规则
子目录/CLAUDE.md              ← 目录级：特定模块的规则
```

就像公司制度：集团有集团的规章，部门有部门的细则，小组有小组的约定。越具体的层级优先级越高。

### 2.2.1 该写什么？

一份好的 CLAUDE.md 回答四个问题：

1. **这个项目是什么？**（技术栈、架构概述）
2. **代码怎么写？**（风格、命名、格式）
3. **什么不能做？**（禁止事项、安全红线）
4. **常用操作是什么？**（测试命令、构建命令、部署流程）

### 2.2.2 快速起步：/init 命令

不想从零写 CLAUDE.md？Claude Code 提供了 `/init` 命令，自动分析你的项目结构并生成初版配置：

```bash
cd ~/projects/review-bot
claude
# 进入 Claude Code 后输入：
/init
```

`/init` 会扫描目录结构、识别编程语言、检测构建系统，然后生成一份 CLAUDE.md。通常两分钟就能得到一个可用的起点，然后你再根据项目实际情况调整。

> 💡 **Tip**: `/init` 生成的是"通用版"，适合快速起步。但项目特有的规则（比如"不要直接 commit 到 main"）还是需要你手动补充。

### 2.2.3 CLAUDE.md 写作反模式

写 CLAUDE.md 也有坑。以下是常见的错误写法和改进建议：

**❌ 太模糊**
```markdown
## Rules
- Write good code
- Follow best practices
```

**✅ 具体可执行**
```markdown
## Rules
- Use type hints on all function signatures
- Max line length: 88 (black default)
- All public functions must have Google-style docstrings
```

**❌ 太长太杂**

把整个项目的 API 文档、数据库 schema、部署手册全塞进 CLAUDE.md。结果文件 2000 行，Claude Code 每次启动都要读一遍，挤占上下文空间。

**✅ 精简聚焦**

CLAUDE.md 只放"AI 写代码时需要知道的规则"。详细文档放在别的地方，需要时让 AI 去读。

**❌ 只有正面规则，没有负面约束**
```markdown
## Style
- Use descriptive variable names
```

**✅ 正反都有**
```markdown
## Style
- Use descriptive variable names
- NEVER use single-letter variables except in list comprehensions
- NEVER use `print()` for logging, use the `logging` module
```

Claude Code 对 "NEVER" 开头的规则特别敏感，遵守率很高。

---

## 2.3 实操复现：搭建 Review Bot 脚手架

### Step 1: 创建 CLAUDE.md

在项目根目录创建 `CLAUDE.md`：

```markdown
# Review Bot — Code Review Automator

## Project Overview
A CLI tool that analyzes local git diffs of C/C++ projects and runs parallel
code reviews using multiple specialized agents. Built with Python and typer.

## Tech Stack
- Python 3.10+
- typer (CLI framework)
- subprocess (git operations)

## Code Style
- Use type hints everywhere
- Docstrings: Google style
- Max line length: 88 (black default)
- Import order: stdlib → third-party → local (isort)

## Architecture
- Python 代码 = 工具层（diff 解析、报告生成）
- `.claude/skills/review-bot/SKILL.md` = 编排层（通过 Claude Code Task tool 调度）
- `.claude/agents/*.md` = Agent 定义（每个 agent 的角色和 prompt）

## Project Structure
review_bot/
├── cli.py           # CLI entry point (diff/report subcommands)
├── diff_parser.py   # Git diff parsing
├── scheduler.py     # Result aggregation utilities
├── reporter.py      # Report generation
└── agents/
    ├── base.py      # Base agent definition
    └── registry.py  # Agent registry

## Commands
- Diff: `review-bot diff [TARGET] [--repo PATH]`
- Skill: `/review-bot HEAD~3` or `/review-bot HEAD~5 --repo /path/to/repo`
- Test: `pytest tests/ -x -q`
- Lint: `ruff check .`
- Format: `black .`

## Rules
- NEVER commit directly to main
- NEVER hardcode file paths
- Always handle subprocess errors gracefully
- Keep each module under 200 lines
```

> 💡 **Tip**: CLAUDE.md 里的 Rules 部分特别重要。Claude Code 会严格遵守这些规则。如果你发现它总是犯同一个错误，把"不要做 XXX"写进 Rules，立竿见影。

### Step 2: 用 Claude Code 搭建 CLI 框架

现在让 Claude Code 来干活。在项目目录中启动 Claude Code：

```bash
cd ~/projects/review-bot
claude
```

输入：

```
请根据 CLAUDE.md 的项目结构，帮我搭建基础的 CLI 框架。
需要：
1. pyproject.toml（用 setuptools）
2. review_bot/cli.py — 用 typer，包含一个 review 命令
3. review_bot/__init__.py
4. 一个能跑通的最小实现
```

Claude Code 会读取 CLAUDE.md，然后按照里面的规范生成代码。你应该会得到类似这样的结果：

**pyproject.toml**:

```toml
[build-system]
requires = ["setuptools>=68.0"]
build-backend = "setuptools.build_meta"

[project]
name = "review-bot"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = [
    "typer>=0.9.0",
]

[project.scripts]
review-bot = "review_bot.cli:app"
```

**review_bot/diff_parser.py**（占位 stub，Ch3 会替换为完整实现）:

```python
"""Git diff parser — stub for CLI scaffolding."""
import subprocess
from dataclasses import dataclass, field


@dataclass
class FileChange:
    """Represents changes to a single file."""
    path: str
    added_lines: list[str] = field(default_factory=list)
    removed_lines: list[str] = field(default_factory=list)


@dataclass
class DiffResult:
    """Parsed diff containing all file changes."""
    files: list[FileChange] = field(default_factory=list)

    @property
    def summary(self) -> str:
        return f"{len(self.files)} files changed"


def get_diff(target: str = "HEAD~1", repo: str | None = None) -> str:
    """Run git diff and return raw output."""
    cmd = ["git", "diff", target]
    result = subprocess.run(cmd, capture_output=True, text=True, cwd=repo)
    if result.returncode != 0:
        raise RuntimeError(f"git diff failed: {result.stderr}")
    return result.stdout


def parse_diff(raw_diff: str) -> DiffResult:
    """Parse unified diff into structured data (minimal stub)."""
    result = DiffResult()
    for line in raw_diff.splitlines():
        if line.startswith("diff --git"):
            path = line.split(" b/")[-1]
            result.files.append(FileChange(path=path))
    return result
```

**review_bot/cli.py**:

```python
"""CLI entry point for Review Bot — utility layer for Claude Code skills."""
import typer

from .diff_parser import get_diff, parse_diff

app = typer.Typer(
    name="review-bot",
    help="Code review utilities — use /review-bot skill for full orchestration.",
)


@app.command()
def diff(
    target: str = typer.Argument("HEAD~1", help="Git diff target (e.g., HEAD~1, main)"),
    repo: str = typer.Option(None, help="Path to git repository (default: cwd)"),
) -> None:
    """Parse git diff and print structured summary."""
    raw_diff = get_diff(target, repo=repo)
    result = parse_diff(raw_diff)
    typer.echo(result.summary)
    typer.echo("---")
    typer.echo(raw_diff)


if __name__ == "__main__":
    app()
```

注意几个细节：
- 用了 type hints（`str`、`-> None`），因为 CLAUDE.md 里要求了
- docstring 用 Google style，也是 CLAUDE.md 的规范
- CLI 定位为**工具层**——只做 diff 解析和报告生成，不做 LLM 编排。编排由 `/review-bot` skill 通过 Claude Code 的 Task tool 完成
- `repo` 参数支持从任意目录审查远程仓库

### Step 3: 验证脚手架

```bash
# Install in development mode
pip install -e .

# Test the CLI
review-bot --help
review-bot HEAD~3
review-bot HEAD~3 --repo /path/to/other/repo
```

如果看到 diff 摘要和原始 diff 输出，说明脚手架搭好了。

> ⚠️ **注意 typer 的单命令行为**: 当前只有一个 `diff` 命令，typer 会自动将它提升为主命令。所以用法是 `review-bot HEAD~3` 而不是 `review-bot diff HEAD~3`。等 Ch6 添加 `report` 子命令后，typer 切换为多命令模式，届时需要改用 `review-bot diff HEAD~3`。

---

## 2.4 设计思维：顺序工作流（Sequential Workflow）

搭脚手架的过程，其实就是一个**顺序工作流**：

```
创建 CLAUDE.md → 生成项目结构 → 写 CLI 入口 → 安装依赖 → 验证
```

每一步都依赖前一步的结果。这是最简单的编排模式，也是所有复杂模式的基础。

在 Claude Code 中，顺序工作流就是你和 AI 的一问一答：你给指令，它执行，你验证，再给下一个指令。没有并行，没有分支，就是一条直线走到底。

什么时候用顺序工作流？
- 步骤之间有严格依赖（不装依赖就没法跑测试）
- 任务本身不复杂，不需要拆分
- 你需要在每一步之后人工确认

---

## 2.5 设计思维：上下文管理 — 你最宝贵的资源

Claude Code 的上下文窗口是你最宝贵的资源。**上下文越满，性能越差**——这是官方文档反复强调的核心原则。

### 2.5.1 三个关键命令

| 命令 | 作用 | 什么时候用 |
|------|------|-----------|
| `/clear` | 清空当前对话，重新开始 | 切换到不相关的任务时 |
| `/compact` | 压缩对话历史，保留关键信息 | 上下文快满时（超过 128K） |
| `/rewind` | 回退到之前的对话状态 | 发现走错方向，想回到某个节点 |

### 2.5.2 避免 "Kitchen Sink Session"

最常见的上下文浪费模式：在同一个会话里做一堆不相关的事。

```
❌ 一个会话里：搭脚手架 → 调试 CSS → 写文档 → 查 API → 改配置
✅ 每个独立任务一个会话：搭脚手架 → /clear → 写文档 → /clear → 改配置
```

### 2.5.3 Subagent 是上下文的"防火墙"

这也是为什么 subagent 的上下文隔离那么重要（Ch3 和 Ch5 会详细讲）。Explore Agent 去翻了 100 个文件，这些内容不会出现在主 agent 的上下文里——主 agent 只收到最终结论。

> 💡 **Tip**: 养成习惯——每完成一个阶段性任务，考虑是否需要 `/clear` 或 `/compact`。上下文管理不是高级技巧，而是日常卫生。

---

## 2.6 提炼模板：CLAUDE.md 配置模板

```markdown
# [项目名称]

## Project Overview
[一句话描述项目做什么]

## Tech Stack
- [语言和版本]
- [核心依赖]

## Architecture
- [代码层职责说明]
- [编排层职责说明]

## Code Style
- [类型标注要求]
- [文档字符串风格]
- [格式化工具和配置]

## Project Structure
[目录树]

## Commands
- Run: [启动命令]
- Test: [测试命令]
- Lint: [检查命令]

## Rules
- [绝对不能做的事]
- [必须遵守的约定]

## Testing Rules
- [测试执行命令]
- [提交前必须通过测试]
- [新功能必须包含测试]
```

### 2.6.1 顺序工作流模板

```
Step 1: [前置准备] → 验证 ✓
Step 2: [核心操作] → 验证 ✓
Step 3: [后续处理] → 验证 ✓
```

每一步都有明确的输入、输出和验证条件。简单但可靠。

---

## 2.7 小结

- CLAUDE.md 是你和 AI 之间的"契约"，写得越清楚，AI 越靠谱
- 三层配置（全局 → 项目 → 目录）让你能精细控制不同场景
- 上下文窗口是最宝贵的资源——用 `/clear`、`/compact`、`/rewind` 主动管理
- 顺序工作流是最基础的编排模式：一步接一步，每步验证

---

