# Workflow101：AI Agent 工作流编排实战

> 别再跟 AI 一句一句聊了。学会编排，让多个 Agent 替你干活。

## 你是不是还在这样用 AI 写代码？

```
你: "这段代码有安全问题吗？"
AI: "有，第 42 行有 SQL 注入风险……"
你: "那性能呢？"
AI: "嗯，第 78 行的循环可以优化……"
你: "代码风格呢？"
AI: [你已经问累了]
```

一个文件还好，十个文件呢？每次 PR 都手动问一遍？

这个教程通过构建一个真实项目，带你掌握 AI 编程中最核心的几个概念：**Agent、Skill、Hook、Workflow**——从"会用 AI"进阶到"会编排 AI"。

## 最终效果

```
> /review-bot HEAD~1

🔍 解析 diff: 3 files changed, 47 insertions(+), 12 deletions(-)

🚀 派出 4 个审查 agent...
  ✓ security  — 2 findings (1 critical, 1 warning)
  ✓ performance — 1 finding (1 info)
  ✓ style     — 3 findings (3 info)
  ✓ logic     — 1 finding (1 warning)

📋 审查报告 → review_report.md

Verdict: NEEDS_WORK (1 critical issue)
```

一条 Skill 指令，背后发生的事：

1. 解析 git diff，理解"改了什么"
2. 同时派出 4 个专业审查 agent（安全 / 性能 / 风格 / 逻辑）
3. 收集所有审查结果，按严重程度排序，生成结构化报告
4. 还能在 git commit 时自动触发——你甚至不用手动跑

## 你能学到什么？

每个概念都是为了解决一个真实问题：

| 你遇到的问题 | 解决它的概念 | 对应章节 |
|-------------|------------|---------|
| 一个 AI 什么都干，结果什么都不精 | **Agent** — 给 AI 划定专业角色，各司其职 | Ch4 |
| 派 Agent 调研，回来把上下文撑爆了 | **Subagent** — 独立上下文，只带结论回来 | Ch5 |
| 同样的审查流程每次都要重新描述一遍 | **Skill** — 把常用流程封装成一条命令 | Ch7 |
| 每次提交都要手动跑审查，总是忘 | **Hook** — 事件触发，代码一提交自动审查 | Ch7 |
| 4 个 Agent 怎么同时干活、结果怎么汇总 | **Workflow** — 编排多个 Agent 的协作模式 | Ch5-6 |
| 项目规则写了没人看，AI 也不遵守 | **CLAUDE.md** — 项目级指令，AI 每次启动自动加载 | Ch2 |
| Agent 需要访问 GitHub、数据库等外部工具 | **MCP** — 标准协议，即插即用连接外部能力 | Ch0 |

这些概念不绑定 Claude Code。换成 OpenCode、Gemini CLI、甚至纯 API 调用，思路都一样。工具会变，编排思维不会。

## 适合谁？

- 在用 AI 写代码，但还停留在"一问一答"模式，想进阶的开发者
- 听过 Agent、Workflow 这些词，但不知道怎么落地的人
- 想给团队搭建 AI 辅助工具链的技术负责人

## 教程结构

每章三段式：**设计思维**（为什么这样做）→ **实操复现**（跟着做）→ **提炼模板**（带走复用）

| 章节 | 你在构建什么 | 学到的编排模式 | 时长 |
|------|-------------|---------------|------|
| [Ch0: 生态概览](docs/00_ecosystem.md) | 了解 AI Coding Agent 全景 | — | 15 min |
| [Ch1: 项目规划](docs/01_planning.md) | 用 AI 规划整个项目 | Plan Agent | 15 min |
| [Ch2: 项目脚手架](docs/02_scaffolding.md) | CLI 框架 + CLAUDE.md | Sequential Workflow | 20 min |
| [Ch3: 理解变更](docs/03_git_diff.md) | Git diff 解析模块 | Explore Agent | 20 min |
| [Ch4: 审查团队](docs/04_agent_design.md) | 4 个专业审查 agent | Agent Design | 25 min |
| [Ch5: 并行审查](docs/05_parallel_review.md) | 4 agent 同时工作 | Parallel + Fan-out/Fan-in | 20 min |
| [Ch6: 报告生成](docs/06_report.md) | 结构化审查报告 | Result Aggregation | 15 min |
| [Ch7: 自动化](docs/07_automation.md) | Hook 自动触发审查 | Hooks + Skills | 20 min |
| [Ch8: 质量保障](docs/08_testing.md) | 测试与 CI 集成 | Test Workflow | 20 min |
| [Ch9: 模板库](docs/09_templates.md) | 可复用 workflow 模板 | Pattern Summary | 10 min |
| [课后作业](docs/10_homework.md) | 自己动手：4 个 Workflow 实战 | 综合实战 | 自定 |

> 总阅读时间约 3 小时。不用一口气读完——每章独立成篇，随时可以停下来消化。

## 示例代码

`examples/` 目录包含完整可运行的示例，可以直接复制到你的项目中使用：

| 目录 | 内容 |
|------|------|
| [examples/review_bot/](examples/review_bot/README.md) | 完整的 Review Bot 项目（从教程各章提取组装） |
| [examples/hooks/](examples/hooks/README.md) | Claude Code Hook 配置模板（自动审查、格式化、分支保护） |
| [examples/mcp/](examples/mcp/README.md) | MCP Server 配置示例（GitHub、文件系统、SQLite） |
| [examples/commands/](examples/commands/README.md) | 自定义 Skill 模板（/review-bot、/test、/audit、/commit、/doc） |
| [examples/workflows/](examples/workflows/README.md) | Workflow 编排示例（/ship、/preflight、/hotfix — 组合 Skill 实战） |
| [examples/ci/](examples/ci/README.md) | CI/CD 集成（GitHub Actions AI 审查工作流） |

## 技术栈

- Python 3.10+
- [typer](https://typer.tiangolo.com/) — CLI 框架
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — AI 编排引擎
- Git — 变更分析数据源

## 如何使用本教程

1. **新手按顺序阅读** — 每章都在前一章的代码基础上继续
2. **此事要躬行** — 每章都有完整的操作步骤，别光看不练
3. **带着项目来** — 学完一章，想想自己的项目能怎么用

## 前置要求

- macOS / Linux / Windows WSL
- Node.js 18+（安装 Claude Code 用）
- Python 3.10+（构建项目用）
- Anthropic API key 或 自行修改`.claude/settings.json`
- 基本的命令行和 Git 操作能力

## 参考资源

- [Anthropic 官方文档](https://docs.anthropic.com/en/docs/claude-code)
- [Claude Code GitHub](https://github.com/anthropics/claude-code)
- [MCP 协议规范](https://modelcontextprotocol.io/)
