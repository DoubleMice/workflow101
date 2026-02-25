Run tests and analyze any failures.

1. Run `pytest tests/ -x -q` for $ARGUMENTS (default: all tests)
2. If all tests pass, report success
3. If any test fails:
   a. Read the failing test and the source code it tests
   b. Analyze the root cause
   c. Suggest a fix (do not apply without confirmation)
4. Report test coverage summary
