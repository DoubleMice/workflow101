"""CLI entry point for Review Bot."""
import typer

from review_bot.diff_parser import get_diff, parse_diff

app = typer.Typer(
    name="review-bot",
    help="Automated code review powered by AI agents.",
)


@app.command()
def review(
    diff: str = typer.Option("HEAD~1", help="Git diff target"),
    output: str = typer.Option("markdown", help="Output format"),
) -> None:
    """Run code review on git diff."""
    typer.echo(f"Analyzing diff: {diff}")

    raw_diff = get_diff(diff)
    result = parse_diff(raw_diff)

    typer.echo(result.summary)
    for f in result.files:
        typer.echo(f"  {f.path}: +{f.additions} -{f.deletions}")


if __name__ == "__main__":
    app()
