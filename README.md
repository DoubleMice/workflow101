# Workflow101：用 Claude Code 构建 Code Review Automator

> 别光看，跟着做。一个项目从零到一，顺便把 AI Agent 工作流编排学了。

## 这是什么？

这是一个项目驱动的教程。我们会从零开始，用 Claude Code 构建一个真实的 **Code Review Automator** —— 一个能自动分析 git diff、并行调度多个审查 agent、生成结构化报告的 CLI 工具。

不是那种"先讲 30 页理论再写 Hello World"的教程。每一章你都在往这个工具上加功能，workflow 编排的各种模式会在构建过程中自然浮现。

## 我们要构建什么？

```
$ review-bot review --diff HEAD~1
```

一行命令，背后发生的事：

1. 解析 git diff，理解"改了什么"
2. 同时派出 4 个专业审查 agent（安全 / 性能 / 风格 / 逻辑）
3. 收集所有审查结果，生成一份结构化报告
4. 还能在 git commit 时自动触发

听起来不复杂？但要把它做好，你会用到 Claude Code 几乎所有的编排能力。

## 适合谁？

- 刚接触 Claude Code，想快速上手的开发者
- 已经在用，但还停留在"一问一答"模式的人
- 想看看 AI Agent 编排在实际项目中怎么落地的人

## 教程结构

每章三段式：**设计思维**（为什么这样做）→ **实操复现**（跟着做）→ **提炼模板**（带走复用）

| 章节 | 你在构建什么 | 学到的编排模式 |
|------|-------------|---------------|
| [Ch0: 生态概览](00_ecosystem.md) | 了解 AI Coding Agent 全景 | — |
| [Ch1: 项目规划](01_planning.md) | 用 AI 规划整个项目 | Plan Agent |
| [Ch2: 项目脚手架](02_scaffolding.md) | CLI 框架 + CLAUDE.md | Sequential Workflow |
| [Ch3: 理解变更](03_git_diff.md) | Git diff 解析模块 | Explore Agent |
| [Ch4: 审查团队](04_agent_design.md) | 4 个专业审查 agent | Agent Design |
| [Ch5: 并行审查](05_parallel_review.md) | 4 agent 同时工作 | Parallel + Fan-out/Fan-in |
| [Ch6: 报告生成](06_report.md) | 结构化审查报告 | Result Aggregation |
| [Ch7: 自动化](07_automation.md) | Hook 自动触发审查 | Hooks + Skills |
| [Ch8: 质量保障](08_testing.md) | 测试与 CI 集成 | Test Workflow |
| [Ch9: 模板库](09_templates.md) | 可复用 workflow 模板 | Pattern Summary |
| [Appendix: 课后作业](10_homework.md) | 自己动手：4 个 Workflow 实战 | 综合实战 |

## 示例代码

`examples/` 目录包含完整可运行的示例，可以直接复制到你的项目中使用：

| 目录 | 内容 |
|------|------|
| [examples/review_bot/](examples/review_bot/) | 完整的 Review Bot 项目（从教程各章提取组装） |
| [examples/hooks/](examples/hooks/) | Claude Code Hook 配置模板（自动审查、格式化、分支保护） |
| [examples/mcp/](examples/mcp/) | MCP Server 配置示例（GitHub、文件系统、SQLite） |
| [examples/commands/](examples/commands/) | 自定义 Skill 模板（/review、/test、/audit） |
| [examples/ci/](examples/ci/) | CI/CD 集成（GitHub Actions AI 审查工作流） |

## 技术栈

- Python 3.10+
- [typer](https://typer.tiangolo.com/) — CLI 框架
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — AI 编排引擎
- Git — 变更分析数据源

## 如何使用本教程

1. **按顺序来** — 每章都在前一章的代码基础上继续
2. **动手做** — 每章都有完整的操作步骤，别光看不练
3. **带着项目来** — 学完一章，想想自己的项目能怎么用

## 前置要求

- macOS / Linux / Windows WSL
- Node.js 18+（安装 Claude Code 用）
- Python 3.10+（构建项目用）
- Anthropic API key 或 Claude Pro/Max 订阅
- 基本的命令行和 Git 操作能力

## 参考资源

- [Anthropic 官方文档](https://docs.anthropic.com/en/docs/claude-code)
- [Claude Code GitHub](https://github.com/anthropics/claude-code)
- [MCP 协议规范](https://modelcontextprotocol.io/)

---

*本教程持续更新中。如果觉得有帮助，欢迎 star 和分享。*
