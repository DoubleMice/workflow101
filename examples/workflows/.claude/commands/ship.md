Ship the current changes: review, test, and commit in one go.

## Step 1: Pre-check

- Run `git status` to confirm there are staged or unstaged changes
- If no changes found, stop and report "nothing to ship"

## Step 2: Code Review

Run a comprehensive code review on the current changes:

1. Get the git diff (staged + unstaged)
2. Launch 4 parallel review agents (defined in `.claude/agents/`):
   - `security-reviewer` — see .claude/agents/security-reviewer.md
   - `performance-reviewer` — see .claude/agents/performance-reviewer.md
   - `style-reviewer` — see .claude/agents/style-reviewer.md
   - `logic-reviewer` — see .claude/agents/logic-reviewer.md
3. Pass the diff text to each agent, collect results into a unified list

Each issue must include: severity (critical/warning/info), file, line, description, suggestion.

**Gate**: If any CRITICAL issue is found, stop here. Show the report and ask the user whether to continue or abort.

## Step 3: Run Tests

1. Run `pytest tests/ -x -q` (or the project's test command from CLAUDE.md)
2. If tests fail, analyze the failure and suggest a fix
3. Do NOT proceed to commit if tests fail — stop and report

## Step 4: Generate Commit

1. Run `git diff --cached` (and `git diff` if nothing staged, stage all first with confirmation)
2. Analyze changes and generate a Conventional Commits message:
   - type(scope): subject
   - Body explaining WHY
3. Show the commit message and wait for user confirmation
4. Create the commit

## Step 5: Summary

Output a brief summary:
- Review: X issues found (Y critical, Z warnings)
- Tests: passed / failed
- Commit: <hash> <message>

Ship target: $ARGUMENTS (default: all current changes)
