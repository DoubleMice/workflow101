Run a security audit on the project.

1. Use Explore agent to understand the project structure and identify attack surfaces
2. Launch parallel security scanning agents:
   - Memory safety agent: buffer overflow, use-after-free, double-free
   - Input validation agent: unchecked user input, format string, injection
   - Resource management agent: memory leaks, file descriptor leaks, deadlocks
3. Collect results, deduplicate, and rank by severity
4. Generate audit report with:
   - Executive summary
   - Findings sorted by risk (critical -> info)
   - Each finding includes: CWE ID, attack scenario, confidence, remediation
   - Overall security rating

Output format: $ARGUMENTS (default: markdown)
