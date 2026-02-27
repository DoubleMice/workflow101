"""CLI entry point for Review Bot — utility layer for Claude Code skills."""
import json
import sys

import typer

from .diff_parser import get_diff, parse_diff
from .agents.base import ReviewIssue
from .reporter import Report, render_markdown

app = typer.Typer(
    name="review-bot",
    help="Code review utilities — use /review-bot skill for full orchestration.",
)


@app.command()
def diff(
    target: str = typer.Argument("HEAD~1", help="Git diff target (e.g., HEAD~1, main)"),
    repo: str = typer.Option(None, help="Path to git repository (default: cwd)"),
) -> None:
    """Parse git diff and print structured summary."""
    raw_diff = get_diff(target, repo=repo)
    result = parse_diff(raw_diff)
    typer.echo(result.summary)
    typer.echo("---")
    typer.echo(raw_diff)


@app.command()
def report(
    issues_json: str = typer.Option(
        None, "--issues", help="JSON array of issues (or read from stdin)",
    ),
) -> None:
    """Generate a Markdown review report from JSON issues."""
    if issues_json:
        raw = issues_json
    else:
        raw = sys.stdin.read()

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        typer.echo("Error: invalid JSON input", err=True)
        raise typer.Exit(1)

    issues = [
        ReviewIssue(
            severity=item.get("severity", "info"),
            file_path=item.get("file", "unknown"),
            line=item.get("line"),
            description=item.get("description", ""),
            suggestion=item.get("suggestion", ""),
        )
        for item in data
    ]
    result = Report(issues=issues)
    typer.echo(render_markdown(result))


if __name__ == "__main__":
    app()
