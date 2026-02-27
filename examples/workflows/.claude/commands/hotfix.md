Emergency hotfix workflow — fast path with minimal checks.

Use this when you need to ship a critical fix quickly. Skips style review and doc checks, keeps only security and test gates.

## Step 1: Create Hotfix Branch

1. Run `git branch --show-current` to check current branch
2. If not on a hotfix branch, create one: `git checkout -b hotfix/$ARGUMENTS`
3. If $ARGUMENTS is empty, ask the user for a short description

## Step 2: Focused Security Check

Run a targeted security review on the changed files ONLY:
- Check for injection, auth bypass, data exposure
- Skip style, performance, and doc checks
- Gate: block on CRITICAL security issues only

## Step 3: Run Tests

1. Identify test files covering the changed code
2. Run only those tests: `pytest <relevant-tests> -x -q`
3. Gate: block if any test fails

## Step 4: Commit and Prepare

1. Stage changes and generate commit message: `fix(scope): description`
2. Show commit message, wait for confirmation
3. Create the commit
4. Show the command to push: `git push origin hotfix/...`

Do NOT push automatically — let the user decide.
