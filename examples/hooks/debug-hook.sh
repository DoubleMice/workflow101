#!/bin/bash
# Hook 调试脚本 — 记录触发信息到日志文件
# 用法: 将 hook 的 command 设为 "bash examples/hooks/debug-hook.sh"

LOG_FILE="/tmp/hook-debug.log"
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

echo "$(date '+%Y-%m-%d %H:%M:%S') | tool=$tool_name | file=$file_path" >> "$LOG_FILE"
echo "Hook triggered: $tool_name on $file_path"
