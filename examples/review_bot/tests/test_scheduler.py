"""Tests for result aggregation and agent output parsing."""
from review_bot.agents.base import ReviewIssue
from review_bot.scheduler import (
    AgentResult,
    ReviewSession,
    parse_agent_output,
)


def test_parse_agent_output_with_json_issues():
    raw = """Here are the security issues found:
{"severity": "critical", "file": "parser.c", "line": 10, "description": "Buffer overflow", "suggestion": "Use bounded read"}
Some other text
{"severity": "warning", "file": "conn.c", "line": null, "description": "Unchecked return", "suggestion": "Check retval"}
"""
    result = parse_agent_output("security", raw)
    assert result.agent_name == "security"
    assert len(result.issues) == 2
    assert result.issues[0].severity == "critical"
    assert result.issues[1].file_path == "conn.c"


def test_parse_agent_output_no_issues():
    raw = "No security issues detected."
    result = parse_agent_output("security", raw)
    assert len(result.issues) == 0


def test_parse_agent_output_invalid_json():
    raw = "{not valid json}\n{also bad"
    result = parse_agent_output("test", raw)
    assert len(result.issues) == 0


def test_review_session_aggregation():
    r1 = AgentResult(agent_name="security", issues=[
        ReviewIssue("critical", "a.c", 1, "desc", "fix"),
    ])
    r2 = AgentResult(agent_name="style", issues=[
        ReviewIssue("info", "b.c", 2, "desc2", "fix2"),
    ])
    session = ReviewSession(results=[r1, r2])
    assert len(session.all_issues) == 2
    assert session.has_critical is True
