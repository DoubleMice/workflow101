Run a full preflight check before submitting code for review or deployment.

Unlike /ship which is sequential (review → test → commit), preflight runs all checks IN PARALLEL for speed, then aggregates results.

## Step 1: Identify Scope

- Parse $ARGUMENTS as the target (default: changes since branching from main)
- Run `git diff main...HEAD --stat` to list affected files
- If no changes, stop and report "nothing to check"

## Step 2: Parallel Checks (launch ALL at once)

Launch these agents simultaneously using Task tool. Each agent's system prompt is defined in `.claude/agents/`:

**Agent 1 — Security Audit** (`.claude/agents/security-reviewer.md`):
- Scan changed files for vulnerabilities
- Each finding: CWE ID, severity, file, line, attack scenario, fix

**Agent 2 — Code Review** (`.claude/agents/logic-reviewer.md` + `.claude/agents/style-reviewer.md`):
- Review changed code for logic errors, edge cases, style issues
- Each finding: severity, file, line, description, suggestion

**Agent 3 — Test Verification**:
- Run the project's test suite (see CLAUDE.md for test command)
- Check test coverage for changed files
- Report: pass/fail, coverage %, uncovered lines

**Agent 4 — Doc Check**:
- Verify docstrings exist for new public functions
- Check README if public API changed
- Report: missing docs list

## Step 3: Aggregate Results

Collect all agent results and produce a single report:

```
## Preflight Report

### Security: PASS / FAIL (N issues)
### Review:   PASS / FAIL (N issues)
### Tests:    PASS / FAIL (coverage: N%)
### Docs:     PASS / FAIL (N missing)

### Overall: READY / NOT READY
```

**Overall is READY** only if: zero critical security issues AND tests pass.
Warnings and doc issues are reported but don't block.

Target: $ARGUMENTS (default: main...HEAD)
