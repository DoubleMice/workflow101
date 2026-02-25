# MCP 配置示例

Model Context Protocol (MCP) Server 配置模板。

## 添加方式

```bash
# 添加 GitHub MCP Server
claude mcp add github -- npx -y @modelcontextprotocol/server-github

# 添加文件系统 MCP Server
claude mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem /path/to/dir

# 添加 SQLite MCP Server
claude mcp add sqlite -- npx -y @modelcontextprotocol/server-sqlite /path/to/db.sqlite
```

## 配置文件

以下 JSON 文件可直接放入 `.claude/` 目录使用。

| 文件 | 用途 |
|------|------|
| github-mcp.json | GitHub 仓库操作（PR、Issue、代码搜索） |
| filesystem-mcp.json | 受限目录的文件系统访问 |
| sqlite-mcp.json | SQLite 数据库查询 |
