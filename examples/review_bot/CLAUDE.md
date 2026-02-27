# Review Bot — Code Review Automator

## Project Overview
A CLI tool that analyzes local git diffs of C/C++ projects and runs parallel
code reviews using multiple specialized agents. Built with Python and typer.

## Tech Stack
- Python 3.10+
- typer (CLI framework)
- subprocess (git operations)

## Architecture
- Python 代码 = 工具层（diff 解析、报告生成）
- `.claude/skills/review-bot/SKILL.md` = 编排层（通过 Claude Code Task tool 调度）
- `.claude/agents/*.md` = Agent 定义（每个 agent 的角色和 prompt，含 YAML frontmatter）
- `.claude/rules/*.md` = 项目规则（代码风格、测试要求，自动加载）

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
