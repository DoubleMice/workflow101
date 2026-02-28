"""Git diff parser — turns raw diff into structured data."""
import subprocess
from dataclasses import dataclass, field


@dataclass
class FileChange:
    """Represents changes to a single file."""

    path: str
    added_lines: list[str] = field(default_factory=list)
    removed_lines: list[str] = field(default_factory=list)

    @property
    def additions(self) -> int:
        return len(self.added_lines)

    @property
    def deletions(self) -> int:
        return len(self.removed_lines)


@dataclass
class DiffResult:
    """Parsed diff containing all file changes."""

    files: list[FileChange] = field(default_factory=list)

    @property
    def total_additions(self) -> int:
        return sum(f.additions for f in self.files)

    @property
    def total_deletions(self) -> int:
        return sum(f.deletions for f in self.files)

    @property
    def summary(self) -> str:
        return (
            f"{len(self.files)} files changed, "
            f"{self.total_additions} additions, "
            f"{self.total_deletions} deletions"
        )


def get_diff(target: str = "HEAD~1", repo: str | None = None) -> str:
    """Run git diff and return raw output.

    Args:
        target: Git diff target (e.g., HEAD~1, main, abc1234).
        repo: Path to the git repository. Uses cwd if None.
    """
    cmd = ["git", "diff", target]
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        cwd=repo,
    )
    if result.returncode != 0:
        raise RuntimeError(f"git diff failed: {result.stderr}")
    return result.stdout


def parse_diff(raw_diff: str) -> DiffResult:
    """Parse unified diff into structured data."""
    result = DiffResult()
    current_file: FileChange | None = None

    for line in raw_diff.splitlines():
        if line.startswith("diff --git"):
            # Extract file path: "diff --git a/foo.py b/foo.py"
            path = line.split(" b/")[-1]
            current_file = FileChange(path=path)
            result.files.append(current_file)
        elif current_file and line.startswith("+") and not line.startswith("+++"):
            current_file.added_lines.append(line[1:])
        elif current_file and line.startswith("-") and not line.startswith("---"):
            current_file.removed_lines.append(line[1:])

    return result
