# CI/CD 集成示例

将 Claude Code 集成到 CI/CD 流水线的配置模板。

## GitHub Actions

`github-actions-review.yml` 展示了如何在 PR 时自动触发 AI 代码审查。

### 使用方式

```bash
cp examples/ci/github-actions-review.yml your-project/.github/workflows/
```

### 前置要求

- 在 GitHub Secrets 中配置 `ANTHROPIC_API_KEY`
- 安装 Claude Code: `npm install -g @anthropic-ai/claude-code`
