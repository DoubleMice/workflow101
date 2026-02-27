# Ch4: Agent 设计 — 安全、性能、风格、逻辑四个专家

> 一个人看代码容易有盲区。四个专家同时看，盲区就少多了。
>
> | 章节 | 关键词 |
> |:-----|:------|
> | Ch0 工具选型 | 工具选型 · 开发模式 |
> | Ch1 需求分析 | Plan Agent · 需求分析 |
> | Ch2 搭建脚手架 | CLAUDE.md · CLI 搭建 |
> | Ch3 解析 Git Diff | Explore Agent · Git Diff |
> | **► Ch4 Agent 设计** | **Agent 设计 · Prompt 工程** |
> | Ch5 Fan-out/Fan-in | Fan-out/Fan-in · 并行执行 |
> | Ch6 结果聚合 | 结果聚合 · 条件逻辑 |
> | Ch7 Hooks 与 Skills | Hooks · Skills |
> | Ch8 测试驱动 | 测试策略 · TDD |
> | Ch9 六种编排模式 | 模式提炼 · 最佳实践 |
> | 附录 课后作业 | Workflow 实战 |

**术语**

- Prompt（提示词，给 AI 的指令文本）
- Buffer Overflow（缓冲区溢出，写入超出分配内存的数据）
- Use-After-Free（释放后使用，访问已释放的内存）
- RAII（Resource Acquisition Is Initialization，资源获取即初始化）
- CWE（Common Weakness Enumeration，通用缺陷枚举）
- Dataclass（Python 数据类）
- ABC（Abstract Base Class，抽象基类）

**本章新概念**

| 概念 | 解决什么问题 |
|------|------------|
| Agent（专业角色） | 一个 AI 什么都审，结果什么都审不精——划定专业角色，各司其职 |
| Prompt 工程 | 同样的模型，不同的 prompt 效果天差地别——用角色、能力、约束三要素设计 prompt |

## 4.1 场景引入

假设你是一个技术总监，要审查一个重要的 PR。你会怎么安排？

你不会让一个人从头看到尾。你会说：

- "老王，你看安全方面有没有问题"
- "小李，你关注一下性能"
- "阿花，代码风格和规范你把把关"
- "老张，业务逻辑你最熟，你来看对不对"

四个人各看各的，最后汇总。这就是 Review Bot 要实现的。

---

## 4.2 设计思维：Agent = 角色 + 能力 + 约束

设计一个好的 Agent，核心就三件事：

**角色（Role）**：它是谁？这决定了它的视角和关注点。安全专家看到 `strcpy()` 会警觉，但风格审查员不会在意。

**能力（Capability）**：它能用什么工具？能读哪些文件？能执行什么命令？能力越精确，输出越聚焦。

**约束（Constraint）**：它不能做什么？不能改代码？只能看特定类型的文件？约束防止 agent 越界。

打个比方：

| | 安全审查员 | 性能审查员 |
|---|---|---|
| 角色 | 安全专家 | 性能工程师 |
| 能力 | 识别 buffer overflow、use-after-free、format string 漏洞 | 识别内存泄漏、cache-unfriendly 访问、不必要的拷贝 |
| 约束 | 只关注安全，不评价代码风格 | 只关注性能，不评价业务逻辑 |

### 4.2.1 Prompt 工程：写好 Agent 指令的关键

给 Agent 写 prompt，和给人写工作说明一样。好的工作说明有三个特点：

1. **具体**：不说"检查代码质量"，说"检查是否有 buffer overflow、use-after-free、未初始化内存读取"
2. **有边界**：不说"看看有什么问题"，说"只关注安全问题，其他问题忽略"
3. **有输出格式**：不说"告诉我结果"，说"按严重程度分级，每个问题包含文件路径、行号、描述、修复建议"

> ⚠️ **踩坑提醒**: 最常见的错误是 prompt 太宽泛。"帮我审查这段代码"会得到一堆泛泛而谈的建议。"检查这段 C 代码中是否存在 `strcpy`/`sprintf` 等不检查缓冲区长度的函数调用"会得到精准的结果。

---

## 4.3 实操复现：定义四个审查 Agent

### Step 1: 创建 Agent 数据结构

先定义 Agent 的通用结构。在 `review_bot/agents/` 目录下创建：

**review_bot/agents/__init__.py**:

```python
"""Review agents package."""
```

**review_bot/agents/base.py**:

```python
"""Base agent definition."""
from dataclasses import dataclass, field


@dataclass
class ReviewIssue:
    """A single issue found during review."""

    severity: str  # "critical", "warning", "info"
    file_path: str
    line: int | None
    description: str
    suggestion: str


@dataclass
class ReviewAgent:
    """Base review agent with role, capability, and constraints."""

    name: str
    role: str
    prompt_template: str
    focus_areas: list[str] = field(default_factory=list)

    def build_prompt(self, diff_content: str) -> str:
        """Build the review prompt with diff content injected."""
        return self.prompt_template.format(diff=diff_content)
```

> 💡 **为什么用 dataclass 而不是 ABC？** 这里的 agent 本质上是"prompt 配置"，不是需要多态的对象。dataclass 更轻量，也更容易序列化。

### Step 2: 定义四个专业 Agent

Agent 的 prompt 定义存在两个位置，各有用途：

| 位置 | 用途 | 格式 |
|------|------|------|
| `review_bot/agents/registry.py` | Python 侧引用，用于测试和程序化访问 | Python dataclass |
| `.claude/agents/*.md` | Claude Code 运行时使用的 subagent 定义 | Markdown 文件 |

两者的 prompt 内容应保持同步。`registry.py` 是"参考副本"，`.claude/agents/` 是"运行时真相"。

**review_bot/agents/registry.py**:

```python
"""Pre-configured review agents."""
from .base import ReviewAgent

SECURITY_AGENT = ReviewAgent(
    name="security",
    role="Security Reviewer",
    focus_areas=[
        "buffer overflow",
        "use-after-free",
        "format string vulnerability",
        "integer overflow/underflow",
        "null pointer dereference",
        "uninitialized memory read",
    ],
    prompt_template="""You are a C/C++ security expert reviewing code changes.

Focus ONLY on security and memory safety issues. Ignore style, performance, and logic concerns.

Check for:
- Buffer overflow (strcpy, sprintf, gets, unbounded memcpy)
- Use-after-free / double-free
- Format string vulnerabilities (printf with user-controlled format)
- Integer overflow/underflow leading to incorrect allocation sizes
- Null pointer dereference without prior check
- Uninitialized memory read
- Any other CWE-listed C/C++ vulnerability you recognize

Diff to review:
{diff}

For each issue found, respond with one JSON object per line (no code fences):
{{"severity":"critical|warning|info","file":"<path>","line":<number or null>,"description":"<what's wrong>","suggestion":"<how to fix>"}}

If no security issues found, respond with: "No security issues detected."
""",
)

PERFORMANCE_AGENT = ReviewAgent(
    name="performance",
    role="Performance Reviewer",
    focus_areas=[
        "memory leaks",
        "cache-unfriendly access",
        "unnecessary copies",
        "malloc in loops",
        "missing move semantics",
    ],
    prompt_template="""You are a C/C++ performance engineer reviewing code changes.

Focus ONLY on performance issues. Ignore security, style, and logic concerns.

Check for:
- Memory leaks (malloc/new without corresponding free/delete)
- Unnecessary heap allocations in hot loops
- Cache-unfriendly data access patterns (e.g. linked list traversal vs array)
- Unnecessary deep copies where move or reference would suffice
- Missing reserve() for vectors with known size
- Blocking I/O without async or thread pool

Diff to review:
{diff}

For each issue, respond with one JSON object per line (no code fences):
{{"severity":"critical|warning|info","file":"<path>","line":<number or null>,"description":"<what's wrong>","suggestion":"<how to fix>"}}

If no performance issues found, respond with: "No performance issues detected."
""",
)

STYLE_AGENT = ReviewAgent(
    name="style",
    role="Style Reviewer",
    focus_areas=[
        "header guards",
        "const correctness",
        "RAII usage",
        "naming conventions",
        "include order",
    ],
    prompt_template="""You are a C/C++ code style reviewer.

Focus ONLY on style and readability. Ignore security, performance, and logic.

Check for:
- Missing or inconsistent header guards (#pragma once vs #ifndef)
- Lack of const correctness (parameters, member functions, pointers)
- Raw new/delete instead of RAII (smart pointers, containers)
- Inconsistent naming conventions (mixedCase vs snake_case)
- Wrong #include order (system → third-party → project)
- Magic numbers without named constants

Diff to review:
{diff}

For each issue, respond with one JSON object per line (no code fences):
{{"severity":"critical|warning|info","file":"<path>","line":<number or null>,"description":"<what's wrong>","suggestion":"<how to fix>"}}

If no style issues found, respond with: "No style issues detected."
""",
)

LOGIC_AGENT = ReviewAgent(
    name="logic",
    role="Logic Reviewer",
    focus_areas=[
        "undefined behavior",
        "signed/unsigned mismatch",
        "off-by-one errors",
        "resource leak paths",
        "unchecked error codes",
    ],
    prompt_template="""You are a C/C++ logic and correctness reviewer.

Focus ONLY on logical errors. Ignore security, performance, and style.

Check for:
- Undefined behavior (signed overflow, out-of-bounds access, strict aliasing)
- Signed/unsigned comparison mismatch
- Off-by-one errors in loop bounds or array indexing
- Resource leak on error paths (early return without cleanup)
- Unchecked return values from system calls (malloc, fopen, read)
- Incorrect pointer arithmetic

Diff to review:
{diff}

For each issue, respond with one JSON object per line (no code fences):
{{"severity":"critical|warning|info","file":"<path>","line":<number or null>,"description":"<what's wrong>","suggestion":"<how to fix>"}}

If no logic issues found, respond with: "No logic issues detected."
""",
)

# All agents in one place for easy iteration
ALL_AGENTS = [SECURITY_AGENT, PERFORMANCE_AGENT, STYLE_AGENT, LOGIC_AGENT]
```

### Step 3: 分析 Prompt 设计的关键决策

回头看这四个 agent 的 prompt，有几个刻意的设计：

**1. 明确的边界声明**

每个 prompt 都有一句"Focus ONLY on X. Ignore Y, Z."。这不是废话——没有这句，agent 会"好心"地顺便提一些其他维度的建议，导致四个 agent 的输出有大量重复。

**2. 具体的检查清单**

不说"检查安全问题"，而是列出具体的检查项（buffer overflow, use-after-free, format string...）。这让 agent 有明确的"扫描目标"，而不是漫无目的地看。

**3. 统一的输出格式**

四个 agent 用完全相同的 **JSON-per-line** 输出格式。每个问题输出一行 JSON 对象：

```json
{"severity":"warning","file":"parser.c","line":42,"description":"...","suggestion":"..."}
```

这样后面汇总报告时，只需要逐行提取以 `{` 开头的行并 `json.loads()`，不需要为每个 agent 写不同的解析逻辑。

> ⚠️ **踩坑提醒**: 不要让 agent 用 Markdown 代码块包裹 JSON 输出（如 ` ```json ... ``` `）。代码块会导致解析器无法逐行提取 JSON。在 prompt 中明确写"respond with one JSON object per line (no code fences)"。

**4. 兜底语句**

每个 prompt 最后都有"If no X issues found, respond with..."。没有这句，agent 在没发现问题时可能会编造问题来"交差"。给它一个合法的"没问题"出口。

### Step 4: Prompt 迭代调优

Prompt 不是写一次就完美的。你需要用真实的 diff 数据去测试，然后根据结果调整。下面是安全 agent 的一次迭代过程：

**问题 1：误报太多**

第一版 prompt 跑完后，安全 agent 把所有 `memcpy()` 调用都标记为"潜在 buffer overflow"。这显然太激进了——很多 `memcpy` 的长度参数是编译期常量，完全安全。

```
修改前：- Buffer overflow (strcpy, sprintf, gets, unbounded memcpy)
修改后：- Buffer overflow (strcpy, sprintf, gets, memcpy with
         runtime-computed size lacking bounds check)
```

加了"runtime-computed size lacking bounds check"这个限定词，误报率大幅下降。

**问题 2：输出格式不稳定**

有时候 agent 会输出自由格式的文本而不是结构化的 severity/file/line 格式。

```
修改前：For each issue found, respond in this exact format:
修改后：For each issue found, you MUST respond in this exact format.
        Do NOT add any text outside this format:
```

加了 "MUST" 和 "Do NOT"，格式遵守率从约 80% 提升到接近 100%。

**问题 3：漏报**

安全 agent 没有检测到 `snprintf` 返回值未检查导致的截断风险。

```
修改前：- Format string vulnerabilities (printf with user-controlled format)
修改后：- Format string vulnerabilities (printf with user-controlled format)
        - Truncation bugs (snprintf return value unchecked)
```

在检查项中加入具体的代码模式，让 agent 知道"长什么样"的代码需要关注。

> 💡 **Tip**: Prompt 调优的本质是**用失败案例驱动改进**。每次发现误报或漏报，就把对应的修正加进 prompt。这和 TDD 的思路一样——用测试驱动代码质量，用真实数据驱动 prompt 质量。

---

## 4.4 检查清单精度 vs. LLM 泛化能力

设计 agent prompt 时，你会面临一个核心张力：**检查清单写得越具体，精度越高但覆盖面越窄；写得越开放，覆盖面越广但噪声越大**。纯清单模式（只列 `strcpy`/`sprintf`/`gets`）精度高但漏报多；纯开放模式（"find all security issues"）覆盖广但误报多。

### 4.4.1 甜蜜点："清单锚定 + 开放兜底"

Security Agent 的 prompt 中用了这个模式：

```
Check for:
- Buffer overflow (strcpy, sprintf, gets, ...)
- Use-after-free / double-free
- Format string vulnerabilities
- Integer overflow/underflow
- Null pointer dereference
- Uninitialized memory read
- Any other CWE-listed C/C++ vulnerability you recognize  ← 开放兜底
```

前 6 条是**锚定清单**——告诉 LLM "这些是重点，必须查"。最后一条是**开放兜底**——给 LLM 空间发挥泛化能力，捕捉清单之外的问题。

### 4.4.2 实例对比：同一段代码，三种 Prompt 策略

用这段 C 代码来看三种策略的差异：

```c
void handle_request(int sock) {
    char buf[64];
    int n = read(sock, buf, 256);  // ← 问题 1: 读 256 字节到 64 字节缓冲区
    buf[n] = '\0';                 // ← 问题 2: n 可能为 -1（read 失败）
    printf(buf);                   // ← 问题 3: format string 漏洞
    char *copy = strdup(buf);
    process(copy);
    // copy 未 free                 ← 问题 4: 内存泄漏（性能维度）
}
```

| 策略 | Prompt 风格 | 能发现的问题 | 误报风险 |
|------|------------|-------------|---------|
| 纯清单 | "Check for: strcpy, sprintf, gets" | 无（这段代码没用清单里的函数） | 极低 |
| 清单锚定 + 开放兜底 | 清单 + "Any other CWE vulnerability" | 问题 1, 2, 3 | 低 |
| 纯开放 | "Find all security issues" | 问题 1, 2, 3, 4 + 可能误报 | 中等 |

纯清单策略在这个例子中完全失效——因为代码没用 `strcpy`/`sprintf`/`gets`，但 `read` 的越界写入同样危险。清单锚定 + 开放兜底策略能捕捉到核心安全问题，同时保持较低的误报率。

### 4.4.3 设计原则

总结为四条实操原则：

1. **清单覆盖高频问题**：把你的领域中最常见的 80% 问题列成清单。对 C/C++ 安全来说，就是 CWE Top 25 中的 C 相关条目。

2. **开放兜底捕捉长尾**：在清单末尾加一条开放式指令，让 LLM 用自己的知识补充清单之外的发现。

3. **用限定词控制精度**：不说"buffer overflow"，说"buffer overflow with runtime-computed size lacking bounds check"。限定词越精确，误报越少。

4. **迭代校准**：跑几轮真实数据，统计误报和漏报，调整清单的粒度和开放兜底的措辞。这是一个持续的过程，不是一次性的。

> 💡 **Tip**: 这个平衡没有标准答案。如果你的场景对误报零容忍（比如 CI 流水线中的自动拦截），就把清单写得更具体、开放兜底的权重调低。如果你的场景更看重覆盖面（比如安全审计报告），就给 LLM 更多自由发挥的空间。

---

## 4.5 提炼模板：Agent Prompt 设计模板

```
You are a [角色] reviewing [审查对象].

Focus ONLY on [关注领域]. Ignore [排除领域].

Check for:
- [具体检查项 1]
- [具体检查项 2]
- [具体检查项 3]

[输入数据占位符]

For each issue found, respond with one JSON object per line (no code fences):
{"severity":"critical|warning|info","file":"<path>","line":<number or null>,"description":"<what>","suggestion":"<fix>"}

If no issues found, respond with: "[无问题时的标准回复]"
```

这个模板的核心原则：**越具体越好，越有边界越好，输出格式必须是机器可解析的 JSON-per-line**。

---

## 4.6 小结

- Agent 设计三要素：角色、能力、约束
- Prompt 要具体、有边界、有统一输出格式
- 四个审查 agent 各司其职：安全、性能、风格、逻辑

---

