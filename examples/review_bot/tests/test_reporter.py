"""Tests for report generator."""
from review_bot.agents.base import ReviewIssue
from review_bot.reporter import Report, Verdict, render_markdown


def _make_issue(severity: str = "warning") -> ReviewIssue:
    return ReviewIssue(
        severity=severity,
        file_path="parser.c",
        line=10,
        description="test issue",
        suggestion="fix it",
    )


def test_verdict_pass():
    report = Report(issues=[])
    assert report.verdict == Verdict.PASS


def test_verdict_warn():
    report = Report(issues=[_make_issue("warning")])
    assert report.verdict == Verdict.WARN


def test_verdict_fail():
    report = Report(issues=[_make_issue("critical")])
    assert report.verdict == Verdict.FAIL


def test_render_markdown_contains_verdict():
    report = Report(issues=[_make_issue("critical")])
    md = render_markdown(report)
    assert "CRITICAL" in md
    assert "parser.c:10" in md
