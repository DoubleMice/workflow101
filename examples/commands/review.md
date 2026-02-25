Run a comprehensive code review on the current changes.

1. Get the git diff for $ARGUMENTS (default: HEAD~1)
2. Parse the diff to understand what changed
3. Launch 4 parallel review agents:
   - Security reviewer: check for memory safety, buffer overflow, format string vulnerabilities
   - Performance reviewer: check for memory leaks, unnecessary copies, cache-unfriendly patterns
   - Style reviewer: check for const correctness, naming conventions, include order
   - Logic reviewer: check for undefined behavior, off-by-one errors, unchecked return values
4. Collect all results and generate a unified report
5. Output the report in markdown format

Each agent must use this output format:
- severity: critical | warning | info
- file: <file path>
- line: <line number or null>
- description: <what's wrong>
- suggestion: <how to fix>
