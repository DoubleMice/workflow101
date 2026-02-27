# Skills 最佳实践与模板

Claude Code 自定义 Skill 模板集合。复制到项目的 `.claude/skills/` 目录即可使用。

## 目录结构

```
.claude/skills/             ← 项目根目录下
├── review/
│   └── SKILL.md            → /review
├── test/
│   └── SKILL.md            → /test
├── audit/
│   └── SKILL.md            → /audit
├── commit/
│   └── SKILL.md            → /commit
├── doc/
│   └── SKILL.md            → /doc
└── db/
    └── migrate/
        └── SKILL.md        → /db:migrate
```

目录名决定触发命令。嵌套目录用 `:` 分隔（`db/migrate/SKILL.md` → `/db:migrate`）。

## 快速安装

```bash
# macOS / Linux
./install.sh ~/projects/my-app

# Windows
install.bat C:\projects\my-app
```

## 模板清单

| 文件 | 命令 | 用途 |
|------|------|------|
| review.md | `/review-bot` | 并行 4-agent 代码审查 |
| test.md | `/test` | 跑测试 + 分析失败原因 |
| audit.md | `/audit` | 安全审计报告 |
| commit.md | `/commit` | 生成 Conventional Commits 消息 |
| doc.md | `/doc` | 生成/更新文档 |
| db/migrate.md | `/db:migrate` | 数据库迁移 |

## 编写最佳实践

### 1. 结构：目标 → 步骤 → 输出

```markdown
[第一行：一句话说清这个 skill 做什么]

1. [步骤 1 — 具体动作]
2. [步骤 2 — 具体动作]
3. [步骤 3 — 具体动作]

Output: [描述输出格式]
```

第一行是 Claude 理解的任务目标，步骤越具体执行越稳定。

### 2. 用英文写 prompt

Claude 对英文指令的遵循度更高。注释和文档可以用中文，但 skill 的 prompt 本体建议用英文。

### 3. 善用 $ARGUMENTS

`$ARGUMENTS` 是唯一的内置变量，会被替换为用户在 `/command` 后输入的内容。

```markdown
# 好 — 写明默认值
Run tests for $ARGUMENTS (default: all tests)

# 不好 — 没参数时 Claude 不知道该干嘛
Run tests for $ARGUMENTS
```

### 4. 步骤要具体，不要模糊

```markdown
# 好 — Claude 知道该启动哪些 agent
Launch 4 parallel review agents:
  - Security reviewer
  - Performance reviewer
  - Style reviewer
  - Logic reviewer

# 不好 — Claude 会自由发挥，结果不可预测
Review the code thoroughly
```

### 5. 定义输出格式

```markdown
# 好 — 结构化输出，方便后续处理
Each finding must include:
- severity: critical | warning | info
- file: <file path>
- line: <line number>
- description: <what's wrong>
- suggestion: <how to fix>

# 不好 — 输出格式随机
Report any issues you find
```

### 6. 不要硬编码项目信息

Skill 应该保持通用。项目特定的配置（代码规范、技术栈、目录约定）放在 `CLAUDE.md` 里，Skill 只负责流程编排。

### 7. 危险操作要确认

```markdown
# 好 — 等用户确认
Show the migration and wait for confirmation before applying

# 不好 — 直接执行
Apply the migration immediately
```

## 自定义你的 Skill

1. 复制一个最接近的模板
2. 修改步骤和输出格式
3. 放到项目的 `.claude/skills/<name>/` 下
4. 在 Claude Code 中输入 `/` 查看可用命令
