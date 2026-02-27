# Review Bot — Code Review Automator

从教程各章节提取组装的完整 CLI 项目。详见 [Ch2](../../02_scaffolding.md) 至 [Ch8](../../08_testing.md)。

## 快速开始

```bash
# 安装（开发模式）
cd examples/review_bot
pip install -e .

# 解析 git diff
review-bot diff HEAD~1

# 通过 Claude Code Skill 触发完整审查
# /review-bot HEAD~3
```

## 项目结构

| 文件 / 目录 | 用途 |
|-------------|------|
| `review_bot/cli.py` | CLI 入口（typer），提供 diff 子命令 |
| `review_bot/diff_parser.py` | Git diff 解析，输出结构化变更数据 |
| `review_bot/scheduler.py` | 审查结果聚合工具 |
| `review_bot/reporter.py` | Markdown / JSON 报告生成 |
| `review_bot/agents/` | Agent 定义（base + registry） |
| `.claude/agents/` | 4 个审查 agent 的 prompt（安全/性能/风格/逻辑） |
| `.claude/skills/review-bot/SKILL.md` | `/review-bot` Skill，编排完整审查流程 |
| `.claude/rules/*.md` | 项目规则（代码风格、测试要求，自动加载） |
| `tests/` | 单元测试 + 集成测试 |

## 运行测试

```bash
pytest tests/ -x -q
```

## 架构说明

- Python 代码 = 工具层（diff 解析、结果聚合、报告生成）
- `.claude/skills/review-bot/SKILL.md` = 编排层（通过 Claude Code Task tool 调度 4 个 agent 并行审查）
- `.claude/agents/*.md` = Agent 定义（每个 agent 有独立的角色、检查清单和输出格式）

这种分层设计让 Python 只负责确定性逻辑，LLM 编排和 agent prompt 放在 Markdown 文件中，方便迭代调整。
