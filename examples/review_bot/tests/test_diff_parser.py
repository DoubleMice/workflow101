"""Tests for diff parser."""
import pytest

from review_bot.diff_parser import FileChange, DiffResult, parse_diff


SAMPLE_DIFF = """\
diff --git a/parser.c b/parser.c
index abc1234..def5678 100644
--- a/parser.c
+++ b/parser.c
@@ -1,3 +1,5 @@
 #include <stdio.h>
+#include <stdlib.h>
+#include <string.h>

 void parse()
-    return;
+    printf("parsing");
"""


def test_parse_diff_file_count():
    result = parse_diff(SAMPLE_DIFF)
    assert len(result.files) == 1
    assert result.files[0].path == "parser.c"


def test_parse_diff_additions():
    result = parse_diff(SAMPLE_DIFF)
    assert result.files[0].additions == 3  # stdlib.h, string.h, printf


def test_parse_diff_deletions():
    result = parse_diff(SAMPLE_DIFF)
    assert result.files[0].deletions == 1  # return;


def test_parse_diff_empty():
    result = parse_diff("")
    assert len(result.files) == 0
    assert result.total_additions == 0


def test_summary():
    result = parse_diff(SAMPLE_DIFF)
    assert "1 files changed" in result.summary
