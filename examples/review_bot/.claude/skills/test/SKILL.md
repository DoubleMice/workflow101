---
name: test
description: Run tests related to current changes
disable-model-invocation: true
---

Run tests related to the current changes.

1. Check git diff to identify changed files
2. Find test files that cover the changed code
3. Run only the relevant tests: pytest $ARGUMENTS -x -q
4. If any test fails, analyze the failure and suggest a fix
