Run a C/C++ code review workflow. This is a complete, executable workflow — follow each step exactly.

## Step 1: Get the diff

```bash
review-bot diff $ARGUMENTS
```

Capture the FULL output (summary line + raw diff). The raw diff content after the `---` separator is what agents will review. If the diff is empty, stop and report "No changes to review."

## Step 2: Fan-out — 4 parallel review agents

Launch exactly 4 Task tool calls IN PARALLEL (in a single message). Each Task must:
- Use subagent_type: "general-purpose"
- Include the COMPLETE agent prompt below (do NOT tell the agent to read a file)
- Append the full diff content at the end

### Agent prompts to inline:

**Task 1 — Security:**
> You are a C/C++ security expert. Focus ONLY on security and memory safety. Ignore style, performance, logic. Check for: buffer overflow, use-after-free, double-free, format string vulnerabilities, integer overflow/underflow, null pointer dereference, uninitialized memory read, any CWE-listed C/C++ vulnerability. For each issue, output one JSON object per line: {"severity":"critical|warning|info","file":"<path>","line":<number or null>,"description":"<what>","suggestion":"<fix>"}. If none found: "No security issues detected."

**Task 2 — Performance:**
> You are a C/C++ performance engineer. Focus ONLY on performance. Ignore security, style, logic. Check for: memory leaks, unnecessary heap allocations in loops, cache-unfriendly access, unnecessary copies, missing reserve(), blocking I/O. Output format: same JSON-per-line as above. If none: "No performance issues detected."

**Task 3 — Style:**
> You are a C/C++ style reviewer. Focus ONLY on style and readability. Ignore security, performance, logic. Check for: missing/inconsistent header guards, const correctness, raw new/delete vs RAII, naming conventions, include order, magic numbers. Output format: same JSON-per-line. If none: "No style issues detected."

**Task 4 — Logic:**
> You are a C/C++ logic reviewer. Focus ONLY on correctness. Ignore security, performance, style. Check for: undefined behavior, signed/unsigned mismatch, off-by-one errors, resource leaks on error paths, unchecked return values, incorrect pointer arithmetic. Output format: same JSON-per-line. If none: "No logic issues detected."

## Step 3: Fan-in — collect and merge

Wait for all 4 agents to complete. From each agent's response, extract all lines that start with `{` and are valid JSON. Merge into a single JSON array.

## Step 4: Generate report

Pipe the merged JSON array to the report generator:

```bash
echo '<merged_json_array>' | review-bot report
```

Output the resulting Markdown report to the user.
