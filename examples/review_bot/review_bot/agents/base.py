"""Base agent definition."""
from dataclasses import dataclass, field


@dataclass
class ReviewIssue:
    """A single issue found during review."""

    severity: str  # "critical", "warning", "info"
    file_path: str
    line: int | None
    description: str
    suggestion: str


@dataclass
class ReviewAgent:
    """Base review agent with role, capability, and constraints."""

    name: str
    role: str
    prompt_template: str
    focus_areas: list[str] = field(default_factory=list)

    def build_prompt(self, diff_content: str) -> str:
        """Build the review prompt with diff content injected."""
        return self.prompt_template.format(diff=diff_content)
