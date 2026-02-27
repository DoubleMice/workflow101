"""Result aggregation utilities for Claude Code skill orchestration.

This module provides data structures for collecting and aggregating
review results from parallel Claude Code subagents. The actual LLM
orchestration happens through the /review-bot skill, not Python code.
"""
import json
from dataclasses import dataclass, field

from .agents.base import ReviewIssue


@dataclass
class AgentResult:
    """Result from a single agent's review."""

    agent_name: str
    issues: list[ReviewIssue] = field(default_factory=list)
    error: str | None = None


@dataclass
class ReviewSession:
    """Aggregated results from all agents."""

    results: list[AgentResult] = field(default_factory=list)

    @property
    def all_issues(self) -> list[ReviewIssue]:
        return [
            issue
            for result in self.results
            for issue in result.issues
        ]

    @property
    def has_critical(self) -> bool:
        return any(i.severity == "critical" for i in self.all_issues)


def parse_agent_output(agent_name: str, raw_output: str) -> AgentResult:
    """Parse raw agent output text into structured AgentResult.

    Extracts JSON issue objects from agent response text.
    Each line starting with '{' is treated as a potential JSON issue.
    """
    result = AgentResult(agent_name=agent_name)

    for line in raw_output.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            data = json.loads(line)
            result.issues.append(ReviewIssue(
                severity=data.get("severity", "info"),
                file_path=data.get("file", "unknown"),
                line=data.get("line"),
                description=data.get("description", ""),
                suggestion=data.get("suggestion", ""),
            ))
        except (json.JSONDecodeError, KeyError):
            continue

    return result
