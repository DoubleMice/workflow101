---
description: Code standards and conventions for this project
---

# Code Standards

When writing or reviewing code in this project, follow these rules:

## Python

- Target Python 3.10+
- Use type hints for all public function signatures
- Use `pathlib.Path` instead of `os.path`
- Prefer f-strings over `.format()` or `%`
- Max line length: 88 (black default)

## Error Handling

- Never use bare `except:` — always catch specific exceptions
- Log errors before re-raising
- Use custom exception classes for domain errors

## Security

- Never hardcode secrets — use environment variables
- Validate all external input at system boundaries
- Use parameterized queries for database access

## Testing

- Test files mirror source structure: `review_bot/cli.py` → `tests/test_cli.py`
- Use pytest fixtures, not setUp/tearDown
- Test command: `pytest tests/ -x -q`
