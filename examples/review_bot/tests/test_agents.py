"""Tests for review agents."""
from review_bot.agents.registry import (
    SECURITY_AGENT,
    PERFORMANCE_AGENT,
    STYLE_AGENT,
    LOGIC_AGENT,
    ALL_AGENTS,
)


FAKE_DIFF = "diff --git a/parser.c b/parser.c\n+#include <stdlib.h>\n"


def test_all_agents_registered():
    assert len(ALL_AGENTS) == 4


def test_agent_names_unique():
    names = [a.name for a in ALL_AGENTS]
    assert len(names) == len(set(names))


def test_build_prompt_injects_diff():
    prompt = SECURITY_AGENT.build_prompt(FAKE_DIFF)
    assert FAKE_DIFF in prompt
    assert "security" in prompt.lower()


def test_each_agent_has_output_format():
    """Every agent prompt must specify the output format."""
    for agent in ALL_AGENTS:
        prompt = agent.build_prompt(FAKE_DIFF)
        assert "severity" in prompt, f"{agent.name} missing severity format"
        assert "suggestion" in prompt, f"{agent.name} missing suggestion format"


def test_each_agent_has_boundary():
    """Every agent prompt must have a 'Focus ONLY' boundary."""
    for agent in ALL_AGENTS:
        prompt = agent.build_prompt(FAKE_DIFF)
        assert "Focus ONLY" in prompt, f"{agent.name} missing focus boundary"
