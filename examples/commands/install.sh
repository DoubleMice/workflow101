#!/usr/bin/env bash
# install.sh — 将 Review Bot 的 Claude Code 配置安装到目标项目
# 用法: ./install.sh <project-path> [--full]
# 示例:
#   ./install.sh ~/projects/my-app          # 安装 skills + agents + hooks
#   ./install.sh ~/projects/my-app --full   # 同上 + 安装 Python CLI 工具

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REVIEW_BOT="$REPO_ROOT/examples/review_bot"

TARGET="${1:?用法: $0 <project-path> [--full]}"
FULL_INSTALL=false
[ "${2:-}" = "--full" ] && FULL_INSTALL=true

# 验证目标路径
if [ ! -d "$TARGET" ]; then
    echo "错误: 目录不存在 — $TARGET"
    exit 1
fi

TARGET="$(cd "$TARGET" && pwd)"
installed=0

install_file() {
    local src="$1"
    local dest="$2"
    local label="$3"

    mkdir -p "$(dirname "$dest")"
    if [ -f "$dest" ]; then
        echo "  跳过 ${label}（已存在）"
    else
        cp "$src" "$dest"
        echo "  安装 $label"
        installed=$((installed + 1))
    fi
}

# 1. 安装 Skills（.claude/skills/）
echo "安装 Skills ..."
for dir in "$REVIEW_BOT"/.claude/skills/*/; do
    [ -d "$dir" ] || continue
    name="$(basename "$dir")"
    install_file "$dir/SKILL.md" "$TARGET/.claude/skills/$name/SKILL.md" ".claude/skills/$name/SKILL.md"
done

# 2. 安装 Agents（.claude/agents/）
echo "安装 Agents ..."
for f in "$REVIEW_BOT"/.claude/agents/*.md; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    install_file "$f" "$TARGET/.claude/agents/$name" ".claude/agents/$name"
done

# 3. 安装 Rules（.claude/rules/）
echo "安装 Rules ..."
for f in "$REVIEW_BOT"/.claude/rules/*.md; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    install_file "$f" "$TARGET/.claude/rules/$name" ".claude/rules/$name"
done

# 4. 安装 Hooks（.claude/settings.json）
echo "安装 Hooks ..."
install_file "$REVIEW_BOT/.claude/settings.json" "$TARGET/.claude/settings.json" ".claude/settings.json"

# 5. 安装 CLAUDE.md
echo "安装 CLAUDE.md ..."
install_file "$REVIEW_BOT/CLAUDE.md" "$TARGET/CLAUDE.md" "CLAUDE.md"

# 6. 安装 Python CLI（可选）
if $FULL_INSTALL; then
    echo "安装 Python CLI ..."
    if pip install -e "$REVIEW_BOT" -q 2>&1; then
        echo "  review-bot CLI 已安装"
        installed=$((installed + 1))
    else
        echo "  警告: pip install 失败，请手动运行: pip install -e $REVIEW_BOT"
    fi
fi

echo ""
echo "完成 — 安装了 $installed 个文件到 $TARGET"
echo ""
echo "已安装内容:"
echo "  .claude/skills/*/SKILL.md — Skill 模板（/review-bot, /test）"
echo "  .claude/agents/*.md      — Agent 定义（security, performance, style, logic）"
echo "  .claude/rules/*.md       — 项目规则（代码风格、测试要求）"
echo "  .claude/settings.json    — Hook 配置（commit 自动审查、自动测试）"
echo "  CLAUDE.md                — 项目级 Agent 指令"
if $FULL_INSTALL; then
    echo "  review-bot CLI        — Python 工具（diff 解析、报告生成）"
fi
echo ""
echo "在 Claude Code 中输入 /review-bot HEAD~3 开始审查"
