# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Workflow101 是一个中文教程项目，教开发者用 Claude Code 从零构建 Code Review Automator（CLI 工具）。教程采用 MkDocs + Material 主题，部署在 ReadTheDocs。

## 常用命令

```bash
# 安装文档构建依赖
./scripts/export-rtd.sh install

# 本地预览（http://127.0.0.1:8000）
./scripts/export-rtd.sh serve

# 构建静态站点到 _site/
./scripts/export-rtd.sh build

# 清理构建产物（删除 _site/ 和 docs/examples/）
./scripts/export-rtd.sh clean

# Review Bot 测试（在 examples/review_bot/ 下）
cd examples/review_bot && pip install -e . && pytest tests/ -x -q
```

## 构建流水线

`export-rtd.sh` 执行两步：
1. **同步 examples**：`scripts/sync_examples.py` 将 `examples/` 各子目录复制到 `docs/examples/`（解决跨平台符号链接问题）
2. **MkDocs 构建**：读取 `mkdocs.yml`，从 `docs/` 生成静态站点到 `_site/`

`_site/` 和 `docs/examples/` 都在 `.gitignore` 中。`docs/` 下的章节文件是源文件，直接编辑。

新增或重命名章节文件时，必须同步更新 `mkdocs.yml` 的 `nav` 部分。

## 内容源文件

- `docs/` 下 `[0-9][0-9]_*.md` 和 `[0-9][0-9][a-d]_*.md` 是教程章节源文件（Ch0-Ch9 + 课后作业 10a-10d）
- `docs/tutorial.md` 是所有章节合并的单页版本，**手动维护**——修改任何章节后需同步更新此文件
- `examples/` 是可运行的示例代码，构建时通过 `sync_examples.py` 复制到 `docs/examples/`，是示例代码的唯一 source of truth

## tutorial.md 锚点规则

MkDocs 处理中文标题时会**剥离所有中文字符和标点**，只保留 ASCII 字母数字和连字符。纯中文标题会生成自动编号 ID（如 `_4`、`_28`）。编辑 tutorial.md 的 TOC 锚点时，必须先 `./scripts/export-rtd.sh build` 构建，再从 `_site/tutorial/index.html` 提取实际锚点 ID。

示例：
- `## 0.1 什么是 AI Coding Agent？` → `#01-ai-coding-agent`
- `## Ch0: 工具选型 — Claude Code、Cursor、Copilot 怎么选` → `#ch0-claude-codecursorcopilot`
- `## 附录: 课后作业 — Workflow 实战` → `#_28`（纯中文部分被剥离后自动编号）

## Review Bot 架构（examples/review_bot/）

三层分离设计：

- **Python 工具层**（`review_bot/`）：diff 解析、结果聚合、报告渲染——只做确定性逻辑
- **编排层**（`.claude/skills/review-bot/SKILL.md`）：`/review-bot` Skill，通过 Task tool 调度 4 个 agent 并行审查，收集结果后调用 `review-bot report`
- **Agent 层**（`.claude/agents/*.md`）：4 个审查 agent（security / performance / style / logic），各自独立的角色定义和 prompt

Agent 定义存在两处，必须保持同步：
- `review_bot/agents/registry.py` — Python 数据结构（用于测试和程序化访问）
- `.claude/agents/*.md` — 运行时定义（Claude Code 实际使用）

Agent 输出格式：每行一个 JSON 对象（不用 code fence），便于流式解析。`registry.py` 中的 prompt_template 包含 `{diff}` 占位符，JSON 模板中的花括号需用 `{{` `}}` 转义。

## 编写规范

- 所有教程内容使用中文撰写
- 技术术语保留英文原文（如 agent、workflow、hook、diff）
- 依赖：Python 3.10+、mkdocs >= 1.6、mkdocs-material >= 9.5
