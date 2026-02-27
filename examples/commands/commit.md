Generate a clear, conventional commit message for the current staged changes.

1. Run `git diff --cached` to see staged changes
2. Analyze what changed: new feature, bug fix, refactor, docs, test, chore?
3. Write a commit message following Conventional Commits format:
   - type(scope): subject
   - Blank line
   - Body explaining WHY, not WHAT (the diff shows what)
4. If $ARGUMENTS is provided, use it as additional context for the message
5. Show the message and wait for confirmation before committing
