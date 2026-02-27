# Workflow Example Project

This project demonstrates how to compose Commands, Skills, Agents, and Hooks into a unified development workflow.

## .claude/ Directory Structure

```
.claude/
├── commands/          # User-invoked workflows (slash commands)
│   ├── ship.md        #   /ship — sequential: review → test → commit
│   ├── preflight.md   #   /preflight — parallel: audit + review + test + doc
│   └── hotfix.md      #   /hotfix — fast path: security → test → commit
├── skills/            # Auto-applied domain knowledge
│   └── code-standards/
│       └── SKILL.md   #   Python conventions, security rules, test patterns
├── agents/            # Reusable subagent definitions
│   ├── security-reviewer.md
│   ├── performance-reviewer.md
│   ├── style-reviewer.md
│   └── logic-reviewer.md
└── settings.json      # Hooks: auto-format, branch protection, commit reminder
```

- **commands/** — orchestration logic, user triggers with `/name`
- **skills/** — domain knowledge, Claude auto-applies when relevant
- **agents/** — specialized reviewers, called as subagents by commands

## Available Commands

- `/ship` — Full ship flow: review → test → commit (sequential, with gates)
- `/preflight` — Pre-submit check: audit + review + test + doc (parallel, then aggregate)
- `/hotfix` — Emergency fix: security check → test → commit (fast path)

## Project Conventions

- Language: Python 3.10+
- Test runner: `pytest tests/ -x -q`
- Commit style: Conventional Commits (`type(scope): subject`)
- Branch naming: `feature/*`, `hotfix/*`, `release/*`

## Workflow Rules

- NEVER push to `main` directly — always use a feature branch
- NEVER skip tests before committing
- When reviewing code, always launch 4 parallel agents (security, performance, style, logic)
- When a review finds CRITICAL issues, stop and report — do not auto-fix without confirmation
