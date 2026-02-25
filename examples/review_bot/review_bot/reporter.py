"""Report generator — aggregates review results."""
import json
from dataclasses import dataclass, field
from enum import Enum

from .agents.base import ReviewIssue


class Verdict(Enum):
    PASS = "pass"
    WARN = "warn"
    FAIL = "fail"


@dataclass
class Report:
    """Structured review report."""

    issues: list[ReviewIssue] = field(default_factory=list)
    agent_errors: list[str] = field(default_factory=list)

    @property
    def verdict(self) -> Verdict:
        if any(i.severity == "critical" for i in self.issues):
            return Verdict.FAIL
        if any(i.severity == "warning" for i in self.issues):
            return Verdict.WARN
        return Verdict.PASS


VERDICT_DISPLAY = {
    Verdict.PASS: "✅ 审查通过，可以合并",
    Verdict.WARN: "⚠️ 可以合并，但请关注以下警告",
    Verdict.FAIL: "❌ 不建议合并，请先修复严重问题",
}


def render_markdown(report: Report) -> str:
    """Render report as Markdown."""
    lines = ["# Code Review Report", ""]
    lines.append(f"**Verdict**: {VERDICT_DISPLAY[report.verdict]}")
    lines.append("")

    # Group issues by severity
    for severity in ("critical", "warning", "info"):
        matched = [i for i in report.issues if i.severity == severity]
        if not matched:
            continue
        lines.append(f"## {severity.upper()} ({len(matched)})")
        lines.append("")
        for issue in matched:
            loc = f"{issue.file_path}:{issue.line}" if issue.line else issue.file_path
            lines.append(f"- **{loc}**: {issue.description}")
            lines.append(f"  - Suggestion: {issue.suggestion}")
        lines.append("")

    if report.agent_errors:
        lines.append("## Agent Errors")
        for err in report.agent_errors:
            lines.append(f"- {err}")

    return "\n".join(lines)


def deduplicate(issues: list[ReviewIssue]) -> list[ReviewIssue]:
    """Remove duplicate issues, keeping the highest severity."""
    severity_rank = {"critical": 3, "warning": 2, "info": 1}
    seen: dict[tuple[str, int | None], ReviewIssue] = {}
    for issue in issues:
        key = (issue.file_path, issue.line)
        if key not in seen or severity_rank.get(
            issue.severity, 0
        ) > severity_rank.get(seen[key].severity, 0):
            seen[key] = issue
    return list(seen.values())


def render_json(report: Report) -> str:
    """Render report as JSON for programmatic consumption."""
    return json.dumps(
        {
            "verdict": report.verdict.value,
            "issue_count": len(report.issues),
            "issues": [
                {
                    "severity": i.severity,
                    "file": i.file_path,
                    "line": i.line,
                    "description": i.description,
                    "suggestion": i.suggestion,
                }
                for i in report.issues
            ],
        },
        indent=2,
        ensure_ascii=False,
    )
