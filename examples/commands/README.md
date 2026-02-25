# Skill / Command 模板

Claude Code 自定义命令模板。放入项目的 `.claude/commands/` 目录即可使用。

## 使用方式

```bash
# 将模板复制到项目
cp examples/commands/review.md your-project/.claude/commands/

# 在 Claude Code 中使用
/review HEAD~3
```

| 文件 | 触发命令 | 用途 |
|------|---------|------|
| review.md | `/review` | 运行完整代码审查 |
| test.md | `/test` | 运行测试并分析失败 |
| audit.md | `/audit` | 运行安全审计 |
