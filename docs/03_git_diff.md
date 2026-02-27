# Ch3: 解析 Git Diff — 用 Explore Agent 读懂变更

> 审查代码的第一步不是"找 bug"，而是"理解变更"。
>
> | 章节 | 关键词 |
> |:-----|:------|
> | Ch0 工具选型 | 工具选型 · 开发模式 |
> | Ch1 需求分析 | Plan Agent · 需求分析 |
> | Ch2 搭建脚手架 | CLAUDE.md · CLI 搭建 |
> | **► Ch3 解析 Git Diff** | **Explore Agent · Git Diff** |
> | Ch4 Agent 设计 | Agent 设计 · Prompt 工程 |
> | Ch5 Fan-out/Fan-in | Fan-out/Fan-in · 并行执行 |
> | Ch6 结果聚合 | 结果聚合 · 条件逻辑 |
> | Ch7 Hooks 与 Skills | Hooks · Skills |
> | Ch8 测试驱动 | 测试策略 · TDD |
> | Ch9 六种编排模式 | 模式提炼 · 最佳实践 |
> | 附录 课后作业 | Workflow 实战 |

**术语**

- Diff（差异，两个版本之间的变更内容）
- Unified Diff（统一差异格式，`git diff` 的标准输出格式）
- Explore Agent（探索代理，Claude Code 的只读代码探索 subagent）
- Dataclass（Python 数据类）
- Subprocess（子进程，Python 中调用外部命令的模块）

**本章新概念**

| 概念 | 解决什么问题 |
|------|------------|
| Explore Agent | 想让 AI 分析代码但怕它手痒改坏东西——只读模式，只看不动 |

## 3.1 场景引入

你打开一个 PR，里面改了 47 个文件、1200 行代码。你的第一反应是什么？

大多数人会从第一个文件开始逐行看。看到第 10 个文件的时候，前面看的已经忘了一半。

更聪明的做法：先鸟瞰全局——改了哪些模块？是新功能还是 bug fix？影响范围有多大？然后再决定重点看哪里。

这一章给 Review Bot 加上"理解变更"的能力，同时学习 Claude Code 的 **Explore Agent**。

---

## 3.2 设计思维：Explore Agent 是什么？

在 Claude Code 中，Explore Agent 是一种专门用来**探索代码库**的 subagent。它的特点：

- 只读不写：只能看代码，不能改代码
- 上下文隔离：它探索过程中读的所有文件，不会占用主 agent 的上下文
- 速度快：专门优化过，比让主 agent 自己去翻文件快得多

打个比方：你要装修房子，不会自己拿着卷尺每个房间量一遍。你会派一个人去量，量完把数据带回来给你。Explore Agent 就是那个拿卷尺的人。

### 3.2.1 Explore Agent 的工具箱

Explore Agent 不是空手去探索的，它有一套专用工具：

| 工具 | 用途 | 示例 |
|------|------|------|
| Glob | 按模式匹配文件路径 | `**/*.py` 找所有 Python 文件 |
| Grep | 在文件内容中搜索 | 搜索 `def parse_diff` 找到函数定义 |
| Read | 读取文件内容 | 读取 `cli.py` 理解入口逻辑 |
| WebFetch | 获取网页内容 | 查阅外部文档 |
| WebSearch | 搜索网页 | 搜索技术方案 |

注意：Explore Agent **没有** Edit、Write、Bash 这些能修改文件或执行命令的工具。这是"只读"约束的硬性保证。

### 3.2.2 什么时候用 Explore Agent？

- 你需要了解一个不熟悉的代码库的结构
- 你想知道某个函数在哪里被调用
- 你需要分析变更影响了哪些模块
- 任何"先看看再说"的场景

### 3.2.3 什么时候不该用？

- 简单的文件查找（直接用 Glob 更快）
- 你已经知道要看哪个文件（直接用 Read）
- 需要执行命令才能获取信息（用 Bash agent）

> 💡 **Tip**: Explore Agent 适合"开放式探索"——你不确定答案在哪里，需要 AI 自己去翻。如果你已经知道目标文件，直接读取比派 Explore Agent 更快。

### 3.2.4 在 Claude Code 中怎么触发？

你不需要手动创建 Explore Agent。当你让 Claude Code 做探索性任务时，它会自动使用 Task tool 派出 Explore subagent：

```
帮我看看这个项目的目录结构和核心模块是怎么组织的。
```

Claude Code 内部会这样做：

```
Task(subagent_type="Explore", prompt="分析项目目录结构和核心模块组织方式...")
```

Explore Agent 会用 Glob、Grep、Read 等工具快速扫描代码库，然后把结论带回来。主 agent 只收到最终结论，不会被探索过程中读取的大量文件内容撑满上下文窗口。

---

## 3.3 实操复现：实现 Git Diff 解析

### Step 1: 理解 git diff 的输出格式

先看看 `git diff` 到底输出什么：

```bash
git diff HEAD~1
```

输出的 unified diff 格式长这样：

```diff
diff --git a/review_bot/cli.py b/review_bot/cli.py
index abc1234..def5678 100644
--- a/review_bot/cli.py
+++ b/review_bot/cli.py
@@ -10,6 +10,8 @@ app = typer.Typer(
 )

+import subprocess
+
 @app.command()
 def review(
```

关键信息：
- `diff --git a/... b/...` — 哪个文件变了
- `@@ -10,6 +10,8 @@` — 变更的位置（第 10 行开始，原来 6 行，现在 8 行）
- `+` 开头 — 新增的行
- `-` 开头 — 删除的行

### Step 2: 让 Claude Code 实现 diff 解析器

在 Claude Code 中输入：

```
帮我实现 review_bot/diff_parser.py。
需求：
1. 调用 git diff 获取变更
2. 解析 unified diff 格式
3. 返回结构化数据：每个文件的变更内容、新增行数、删除行数
4. 用 dataclass 定义数据结构
```

你应该得到类似这样的代码：

**review_bot/diff_parser.py**:

```python
"""Git diff parser — turns raw diff into structured data."""
import subprocess
from dataclasses import dataclass, field


@dataclass
class FileChange:
    """Represents changes to a single file."""

    path: str
    added_lines: list[str] = field(default_factory=list)
    removed_lines: list[str] = field(default_factory=list)

    @property
    def additions(self) -> int:
        return len(self.added_lines)

    @property
    def deletions(self) -> int:
        return len(self.removed_lines)
```

接下来是核心的解析逻辑：

```python
@dataclass
class DiffResult:
    """Parsed diff containing all file changes."""

    files: list[FileChange] = field(default_factory=list)

    @property
    def total_additions(self) -> int:
        return sum(f.additions for f in self.files)

    @property
    def total_deletions(self) -> int:
        return sum(f.deletions for f in self.files)

    @property
    def summary(self) -> str:
        return (
            f"{len(self.files)} files changed, "
            f"{self.total_additions} additions, "
            f"{self.total_deletions} deletions"
        )
```

然后是获取和解析 diff 的函数：

```python
def get_diff(target: str = "HEAD~1", repo: str | None = None) -> str:
    """Run git diff and return raw output.

    Args:
        target: Git diff target (e.g., HEAD~1, main, abc1234).
        repo: Path to the git repository. Uses cwd if None.
    """
    cmd = ["git", "diff", target]
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        cwd=repo,
    )
    if result.returncode != 0:
        raise RuntimeError(f"git diff failed: {result.stderr}")
    return result.stdout


def parse_diff(raw_diff: str) -> DiffResult:
    """Parse unified diff into structured data."""
    result = DiffResult()
    current_file: FileChange | None = None

    for line in raw_diff.splitlines():
        if line.startswith("diff --git"):
            # Extract file path: "diff --git a/foo.py b/foo.py"
            path = line.split(" b/")[-1]
            current_file = FileChange(path=path)
            result.files.append(current_file)
        elif current_file and line.startswith("+") and not line.startswith("+++"):
            current_file.added_lines.append(line[1:])
        elif current_file and line.startswith("-") and not line.startswith("---"):
            current_file.removed_lines.append(line[1:])

    return result
```

> 💡 **为什么用 dataclass？** 比起返回 dict，dataclass 有类型提示、自动生成 `__repr__`，还能加 property 做计算属性。后面 agent 拿到这个数据结构，用起来更方便。

### 3.3.3 边界情况：真实世界的 diff 没那么干净

上面的解析器能处理最常见的情况，但真实项目中你会遇到这些边界：

| 情况 | diff 中的表现 | 处理策略 |
|------|-------------|---------|
| 二进制文件 | `Binary files a/logo.png and b/logo.png differ` | 跳过，记录文件名 |
| 文件重命名 | `rename from old.py` / `rename to new.py` | 记录新旧路径 |
| 新增文件 | `--- /dev/null` | `deletions = 0` |
| 删除文件 | `+++ /dev/null` | `additions = 0` |
| 空 diff | 空字符串 | 返回空 `DiffResult` |
| 文件路径含空格 | `diff --git a/my file.py b/my file.py` | 用 `b/` 分割而非空格 |

解析器已经处理了空 diff 和基本的增删。其他边界情况可以后续按需添加——先让核心流程跑通，再逐步完善。这也是 Ch1 中"渐进式规划"思想的体现。

> ⚠️ **踩坑提醒**: 不要试图一开始就处理所有边界情况。先覆盖 80% 的常见场景，等测试（Ch8）暴露出问题再补。过早优化边界处理是浪费时间。

### Step 3: 接入 CLI

更新 `cli.py`，把 diff 解析接进去：

```python
from review_bot.diff_parser import get_diff, parse_diff

@app.command()
def diff(
    target: str = typer.Argument("HEAD~1", help="Git diff target"),
    repo: str = typer.Option(None, help="Path to git repository (default: cwd)"),
) -> None:
    """Parse git diff and print structured summary."""
    raw_diff = get_diff(target, repo=repo)
    result = parse_diff(raw_diff)
    typer.echo(result.summary)
    typer.echo("---")
    typer.echo(raw_diff)
```

现在跑一下：

```bash
review-bot HEAD~1
review-bot HEAD~3 --repo /path/to/other/repo
```

你应该能看到变更文件列表和原始 diff 输出。`--repo` 参数让你可以从任意目录审查其他仓库的变更。

> ⚠️ **注意**: 当前只有一个 `diff` 命令，typer 会自动提升为主命令，所以用法是 `review-bot HEAD~1` 而不是 `review-bot diff HEAD~1`。Ch6 添加 `report` 子命令后会切换为多命令模式，届时需要改用 `review-bot diff HEAD~1`。

---

## 3.4 提炼模板：Explore Agent 使用模式

当你需要让 Claude Code 探索代码库时，用这个 prompt 模式：

```
帮我分析 [目标范围]。
我需要知道：
1. [具体问题 1]
2. [具体问题 2]
3. [具体问题 3]
不需要修改任何代码，只需要告诉我结论。
```

关键点：**明确说"不需要修改"**。否则 Claude Code 可能会顺手帮你改代码。

---

## 3.5 小结

- Explore Agent 是 Claude Code 的"侦察兵"，只读不写，上下文隔离
- Git diff 解析是 Code Review 的第一步：先理解变更，再做审查
- 用 dataclass 定义结构化数据，比 dict 更安全、更好用

---

