# Ch1: 项目规划 — 让 AI 帮你想清楚再动手

> **本章目标**：用 Plan Agent 规划项目，做出关键设计决策
>
> | 章节 | 关键词 |
> |:-----|:------|
> | Ch0 生态概览 | 工具选型 · 开发模式 |
> | **► Ch1 项目规划** | **Plan Agent · 需求分析** |
> | Ch2 项目脚手架 | CLAUDE.md · CLI 搭建 |
> | Ch3 理解变更 | Explore Agent · Git Diff |
> | Ch4 设计审查团队 | Agent 设计 · Prompt 工程 |
> | Ch5 并行审查 | Fan-out/Fan-in · 并行执行 |
> | Ch6 报告生成 | 结果聚合 · 条件逻辑 |
> | Ch7 自动化 | Hooks · Skills |
> | Ch8 质量保障 | 测试策略 · TDD |
> | Ch9 模板库 | 模式提炼 · 最佳实践 |
> | 附录 课后作业 | Workflow 实战 |

> 写代码之前最重要的事：想清楚要做什么。

**术语**

- Plan Mode（规划模式，Claude Code 的只读规划状态）
- PR（Pull Request，合并请求）
- Subagent（子代理，主 Agent 派出的下属）
- Dataclass（Python 数据类，用装饰器自动生成样板代码）
- Fan-out/Fan-in（扇出/扇入，并行分发再汇总的模式）

## 场景引入

你接到一个需求："做一个自动代码审查工具"。

大多数人的第一反应是打开编辑器开始写代码。然后写到一半发现架构不对，推倒重来。再写到一半发现需求理解错了，又推倒重来。

如果你有一个 AI 助手，能在动手之前帮你把需求拆清楚、架构想明白、任务排好序呢？

这就是 Claude Code 的 **Plan Agent** 能做的事。

---

## 设计思维：为什么要用 AI 做规划？

### 规划的价值

软件开发中，最贵的不是写代码，而是**写错代码**。返工的成本远高于多花点时间想清楚。

传统做法：你自己写 PRD、画架构图、拆任务。这些都是你的经验在驱动。

AI 辅助做法：你描述目标，AI 帮你补盲点。它见过的项目比你多，能提醒你"这里通常会有坑"。

> 关键心态转变：不是让 AI 替你决策，而是让它帮你**想得更全面**。最终拍板的还是你。

### Claude Code 的 Plan 模式

Claude Code 有一个内置的 Plan 模式。当你面对一个复杂任务时，可以让它先进入"规划模式"——只思考、不动手。

**怎么进入 Plan 模式？**

在 Claude Code 的输入框中按 `Shift+Tab`，会在三种模式之间循环切换：

```
Normal Mode → Auto-accept Edits → Plan Mode → Normal Mode → ...
```

当底部状态栏显示 `⏸ plan mode on` 时，就进入了 Plan 模式。

**Plan 模式下能做什么？**

| 能做 | 不能做 |
|------|--------|
| 读取文件、搜索代码 | 创建、编辑、删除文件 |
| 派出 Explore subagent 分析架构 | 执行修改性的 shell 命令 |
| 搜索网页、获取文档 | 安装依赖包 |
| 向你提问、澄清需求 | 任何会改变代码库的操作 |
| 创建和管理任务列表 | |

这个"只读"约束很重要——它保证了 AI 在规划阶段不会"手痒"偷偷改你的代码。

**怎么退出？**

再按一次 `Shift+Tab` 切回 Normal Mode。确认方案后，在 Normal Mode 下让 AI 按方案执行。

> 💡 **Tip**: 你也可以不用 Plan 模式的快捷键，直接在 prompt 里说"请先帮我规划，不要写代码"。效果类似，但 Plan 模式的硬约束更可靠——它从工具层面禁止了写操作，而不是靠 AI 的"自觉"。

Plan 模式下，Claude Code 会：
1. 分析你的需求
2. 探索相关代码（如果已有代码库）
3. 设计实现方案
4. 列出具体步骤
5. 等你确认后再执行

这和直接让它"帮我写个 XXX"有本质区别。后者是边想边做，前者是想清楚再做。这就是 Ch0 中提到的 **Plan-then-Code** 开发模式的实践。

---

## 实操复现：规划 Code Review Automator

### Step 1: 启动 Claude Code 并描述项目

打开终端，创建项目目录：

```bash
mkdir -p ~/projects/review-bot && cd ~/projects/review-bot
claude
```

进入 Claude Code 后，输入：

```
我想构建一个 Code Review Automator CLI 工具。
功能：分析本地 git diff，用多个专业 agent 并行审查（安全、性能、风格、逻辑），生成结构化报告。
技术栈：Python + typer。
请先帮我规划，不要写代码。
```

> 💡 **Tip**: 最后那句"请先帮我规划，不要写代码"很关键。不加这句，Claude Code 可能直接开始写代码。明确告诉它你要的是规划，不是实现。

### Step 2: 审视 AI 给出的规划

Claude Code 通常会给出类似这样的规划：

```
项目结构：
review_bot/
├── cli.py          # CLI entry point (typer)
├── diff_parser.py  # Git diff parsing
├── agents/
│   ├── security.py # Security review agent
│   ├── performance.py
│   ├── style.py
│   └── logic.py
├── reporter.py     # Report generation
└── config.py       # Configuration

实现步骤：
1. 搭建 CLI 框架（typer）
2. 实现 git diff 解析
3. 设计审查 agent prompt
4. 实现并行审查调度
5. 实现报告生成
6. 添加 hook 自动触发
```

这个规划看起来不错，但有几个问题值得追问：

```
几个问题：
1. diff 解析要支持哪些格式？只支持 unified diff 还是也要支持 stat？
2. agent 之间需要共享上下文吗？比如安全 agent 发现的问题，逻辑 agent 需要知道吗？
3. 报告输出什么格式？纯文本？Markdown？JSON？
4. 错误处理策略是什么？一个 agent 挂了，其他的继续还是全部停？
```

> ⚠️ **踩坑提醒**: 不要无脑接受 AI 的第一版规划。它给的是"通用最佳实践"，不一定适合你的具体场景。你的工作是**追问细节**和**做取舍**。

### Step 3: 迭代细化

好的规划不是一轮就能定的。你需要和 AI 来回几轮，逐步收敛。下面是一段典型的规划对话：

**第一轮：追问架构决策**

```
你: agent 之间需要共享上下文吗？比如安全 agent 发现了 buffer overflow，
    逻辑 agent 需要知道这件事吗？

AI: 建议不共享。原因：
    1. 共享会引入依赖——安全 agent 必须先跑完，其他 agent 才能开始
    2. 一个 agent 的误判会传染给其他 agent
    3. 独立运行可以并行，速度更快
    代价是可能有少量重复发现，但汇总阶段可以去重。

你: 同意。那如果一个 agent 挂了呢？比如安全 agent 超时了。

AI: 两种策略：
    A) 全部停止，报错退出 — 简单但脆弱
    B) 部分失败继续，在报告中标注哪个 agent 失败了 — 更健壮
    建议选 B，因为 3 个 agent 的审查结果总比 0 个好。

你: 选 B。在报告里加一个 "Agent Errors" 区域。
```

**第二轮：追问数据格式**

```
你: 四个 agent 的输出格式需要统一吗？

AI: 强烈建议统一。如果每个 agent 输出格式不同，汇总时要写 4 套解析逻辑。
    建议统一为：severity / file / line / description / suggestion
    这 5 个字段覆盖了审查结果的核心信息。

你: severity 分几级？

AI: 建议 3 级：
    - critical: 必须修复才能合并（安全漏洞、数据丢失风险）
    - warning: 建议修复（性能问题、潜在 bug）
    - info: 可选改进（风格建议、命名优化）
    报告的最终 verdict 基于最高 severity 决定。

你: 好，就这样。
```

经过几轮追问，我们确定了以下设计决策：

| 决策点 | 选择 | 理由 |
|--------|------|------|
| Diff 格式 | unified diff | 信息最完整，包含上下文行 |
| Agent 间通信 | 不共享 | 保持独立性，避免级联错误 |
| 报告格式 | Markdown + JSON | Markdown 给人看，JSON 给程序用 |
| 错误处理 | 部分失败继续 | 一个 agent 挂了不影响其他审查 |
| CLI 框架 | typer | 类型安全，自动生成帮助文档 |
| 输出格式 | 统一 5 字段 | severity / file / line / description / suggestion |
| 严重程度 | 3 级 | critical / warning / info |

### Step 4: 确认最终架构

让 Claude Code 根据讨论结果画出最终架构：

```
请根据我们的讨论，画出最终的系统架构图（ASCII）和确认项目结构。
```

最终架构：

```
┌───────────────────────────────────────────┐
│              CLI (typer)                   │
│           review-bot review                │
└─────────────────────┬─────────────────────┘
                      │
                      ▼
┌───────────────────────────────────────────┐
│             Diff Parser                    │
│       git diff → structured data           │
└─────────────────────┬─────────────────────┘
                      │
        ┌─────────┬───┴───┬─────────┐
        ▼         ▼       ▼         ▼
   ┌────────┐ ┌──────┐ ┌───────┐ ┌───────┐
   │Security│ │ Perf │ │ Style │ │ Logic │
   │ Agent  │ │Agent │ │ Agent │ │ Agent │
   └───┬────┘ └──┬───┘ └───┬───┘ └──┬────┘
       └─────────┴────┬────┴─────────┘
                      │
                      ▼
┌───────────────────────────────────────────┐
│              Reporter                      │
│      aggregate → markdown / json           │
└───────────────────────────────────────────┘
```

---

## 提炼模板：AI 辅助规划的通用流程

不管你做什么项目，都可以套用这个流程：

```
1. 描述目标（不要说"怎么做"，只说"要什么"）
   ↓
2. 让 AI 给出初版规划
   ↓
3. 追问细节（格式？边界？错误处理？）
   ↓
4. 做取舍（记录每个决策的理由）
   ↓
5. 确认最终方案（架构图 + 项目结构 + 实施步骤）
```

### Prompt 模板

```
我想构建 [项目描述]。
功能需求：[列出核心功能]
技术约束：[技术栈、平台、性能要求等]
请先帮我规划，不要写代码。需要包含：
- 项目结构
- 核心模块划分
- 实施步骤（按优先级排序）
- 你认为需要提前想清楚的设计决策
```

### 决策记录模板

养成记录设计决策的习惯。后面回头看，你会感谢自己的。

```markdown
## 决策：[决策标题]
- 选项 A：[描述] — 优点 / 缺点
- 选项 B：[描述] — 优点 / 缺点
- **选择**：[选了哪个]
- **理由**：[为什么]
```

---

## 规划的常见误区

### 误区 1：规划等于写 PRD

不需要写一份 20 页的需求文档。AI 辅助规划的重点是**对话式探索**——通过提问和回答逐步收敛方案。一个清晰的架构图 + 一张决策表，比一份冗长的 PRD 更有用。

### 误区 2：一次规划到位

没有人能在第一次就想清楚所有细节。好的规划是**渐进式**的：先定大方向（Ch1），实现过程中遇到新问题再补充。我们的 Review Bot 就是这样——Ch1 定了整体架构，但 agent 的具体 prompt 设计是到 Ch4 才细化的。

### 误区 3：AI 说什么就是什么

AI 给的规划基于"通用最佳实践"，但你的项目有自己的约束。比如 AI 可能建议用 asyncio 做并行，但我们选了 Claude Code 的 subagent 并行——因为这是教程的教学目标。**你的判断力才是最终决策者**。

### 误区 4：跳过规划直接写代码

"这个需求很简单，不用规划"——这句话是 bug 的温床。哪怕只花 5 分钟让 AI 帮你列一下实施步骤，也比直接开干强。规划的成本远低于返工的成本。

---

## 小结

这一章我们做了一件看起来"没产出"但极其重要的事：**想清楚再动手**。

- Plan Agent 的核心价值不是替你做决策，而是帮你**想得更全面**
- 好的规划 = 明确的目标 + 清晰的架构 + 有序的步骤 + 记录在案的决策
- 不要无脑接受 AI 的第一版方案，追问细节、做取舍才是你的工作

下一章，我们开始真正写代码——搭建项目脚手架。

---

## 参考链接

- [Anthropic 官方文档 — Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- [Claude Code Plan Mode 使用指南](https://buildermethods.com/library/plan-mode-claude-code)
- [Plan Mode 详解 — claudelog](https://www.claudelog.com/mechanics/plan-mode)
- [Spec-Driven Development: 给 AI 一份蓝图](https://zencoder.ai/blog/spec-driven-development-sdd-the-engineering-method-ai-needed)
- [Claude Code 环境配置最佳实践](https://www.maxzilla.nl/blog/claude-code-environment-best-practices/)

---

[上一章: Ch0 — 生态概览](00_ecosystem.md) | [下一章: Ch2 — 项目脚手架](02_scaffolding.md)
