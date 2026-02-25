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

## Project Structure
```
review_bot/
├── cli.py           # CLI entry point
├── diff_parser.py   # Git diff parsing
├── agents/          # Review agents
├── reporter.py      # Report generation
└── config.py        # Configuration
```

## Commands
- Run: `python -m review_bot review`
- Test: `pytest tests/`
- Lint: `ruff check .`
- Format: `black .`

## Rules
- NEVER commit directly to main
- NEVER hardcode file paths
- Always handle subprocess errors gracefully
- Keep each module under 200 lines
