"""Integration tests — full pipeline from diff to report."""
from review_bot.agents.base import ReviewIssue
from review_bot.diff_parser import parse_diff
from review_bot.reporter import Report, Verdict, render_markdown


MULTI_FILE_DIFF = """\
diff --git a/parser.c b/parser.c
--- a/parser.c
+++ b/parser.c
@@ -1,2 +1,3 @@
 #include <stdio.h>
+#include <stdlib.h>
diff --git a/conn_pool.c b/conn_pool.c
--- a/conn_pool.c
+++ b/conn_pool.c
@@ -5,3 +5,2 @@
-old_alloc()
+new_alloc()
"""


def test_full_pipeline_pass():
    """No issues → PASS verdict."""
    diff = parse_diff(MULTI_FILE_DIFF)
    assert len(diff.files) == 2

    report = Report(issues=[])
    assert report.verdict == Verdict.PASS
    md = render_markdown(report)
    assert "通过" in md


def test_full_pipeline_fail():
    """Critical issue → FAIL verdict with details in report."""
    diff = parse_diff(MULTI_FILE_DIFF)

    issues = [
        ReviewIssue(
            severity="critical",
            file_path=diff.files[0].path,
            line=2,
            description="Buffer overflow — read() exceeds buffer size",
            suggestion="Use bounded read with sizeof(buf)",
        )
    ]
    report = Report(issues=issues)
    assert report.verdict == Verdict.FAIL

    md = render_markdown(report)
    assert "CRITICAL" in md
    assert "parser.c:2" in md
    assert "Buffer overflow" in md
