"""Parallel review scheduler — fan-out/fan-in pattern."""
from dataclasses import dataclass, field

from .agents.base import ReviewAgent, ReviewIssue
from .agents.registry import ALL_AGENTS
from .diff_parser import DiffResult


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
