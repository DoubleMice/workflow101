# Workflow 编排示例

演示 Claude Code 最佳实践：`commands/` + `skills/` + `agents/` + Hooks + CLAUDE.md 五层协同。

## 目录结构

```
project-root/
├── CLAUDE.md                              # 项目级指令（约定、规则）
└── .claude/
    ├── settings.json                      # Hooks（事件驱动自动化）
    ├── commands/                          # 用户触发的 Workflow（/slash-command）
    │   ├── ship.md                        #   /ship — 顺序流水线
    │   ├── preflight.md                   #   /preflight — 并行检查
    │   └── hotfix.md                      #   /hotfix — 快速通道
    ├── skills/                            # 自动应用的领域知识
    │   └── code-standards/
    │       └── SKILL.md                   #   代码规范（Claude 写代码时自动遵守）
    └── agents/                            # 可复用的 subagent 定义
        ├── security-reviewer.md           #   安全审查专家
        ├── performance-reviewer.md        #   性能审查专家
        ├── style-reviewer.md              #   风格审查专家
        └── logic-reviewer.md              #   逻辑审查专家
```

## 五层各司其职

| 层 | 位置 | 职责 | 触发方式 |
|---|---|---|---|
| CLAUDE.md | 项目根目录 | 项目约定：分支规范、测试命令、commit 风格 | 每次对话自动加载 |
| commands/ | `.claude/commands/` | 编排逻辑：定义多步骤工作流 | 用户输入 `/name` |
| skills/ | `.claude/skills/` | 领域知识：代码规范、安全规则 | Claude 判断相关时自动应用 |
| agents/ | `.claude/agents/` | 专家能力：每个 agent 专注一个审查维度 | 被 commands 作为 subagent 调用 |
| Hooks | `.claude/settings.json` | 自动化触发：格式化、分支保护 | 工具调用前后自动执行 |

## 三个 Workflow 对比

| | /ship | /preflight | /hotfix |
|---|---|---|---|
| 编排模式 | 顺序（Sequential） | 并行（Fan-out/Fan-in） | 顺序（精简版） |
| 代码审查 | 4 agent 并行 | 4 agent 并行 | 仅安全检查 |
| 测试 | 全量 | 全量 + 覆盖率 | 仅相关测试 |
| 安全审计 | 作为审查的一部分 | 独立 agent | 仅关键项 |
| 文档检查 | 无 | 有 | 无 |
| 自动提交 | 是（需确认） | 否（只报告） | 是（需确认） |
| 适用场景 | 日常开发 | PR 提交前 | 紧急修复 |

## 编排模式详解

### /ship — 顺序流水线 + 门控

```
pre-check → review → [gate] → test → [gate] → commit → summary
                        │                │
                   critical?          failed?
                   → 停止              → 停止
```

每一步是下一步的前置条件。review 发现 critical 问题就停下来，不浪费时间跑测试。

### /preflight — 并行扇出 + 聚合

```
identify scope
      │
      ├── Security Audit  ──┐
      ├── Code Review     ──┤
      ├── Test Runner     ──┼──→ Aggregate → Report
      └── Doc Check       ──┘
```

四个 agent 同时启动，互不依赖。全部完成后聚合成一份报告。比 /ship 快，但不做 commit。

### /hotfix — 精简快速通道

```
create branch → security check → [gate] → test → [gate] → commit
```

跳过 style review、performance review、doc check。只保留安全和测试两个硬门控。

## 组合原理

commands 负责编排流程，agents 负责具体审查，skills 提供背景知识：

```
commands（编排）          agents（执行）           skills（知识）
──────────────          ──────────────          ──────────────
/ship Step 2  ────────→ security-reviewer.md
              ────────→ performance-reviewer.md
              ────────→ style-reviewer.md       ← code-standards/
              ────────→ logic-reviewer.md          SKILL.md
                                                   (自动生效)
/preflight    ────────→ security-reviewer.md
              ────────→ logic-reviewer.md
              ────────→ style-reviewer.md

/hotfix       ────────→ security-reviewer.md
```

**设计原则**：
- commands 只写编排逻辑（步骤、门控、聚合），不写审查细节
- agents 只写审查能力（关注点、输出格式、规则），不管流程
- skills 只写领域知识（代码规范、安全规则），Claude 自动应用
- CLAUDE.md 只写项目约定（测试命令、分支规范），所有层共享
- Hooks 只做轻量自动化（格式化、提醒），不做重逻辑

## 如何安装到你的项目

```bash
# 复制整个 .claude 目录（包含 commands + skills + agents + hooks）
cp -r .claude/ ~/projects/my-app/.claude/

# 复制 CLAUDE.md（按需修改项目约定）
cp CLAUDE.md ~/projects/my-app/
```

也可以按需只装部分：

```bash
# 只装 commands（workflow 编排）
cp .claude/commands/*.md ~/projects/my-app/.claude/commands/

# 只装 agents（审查专家）
cp .claude/agents/*.md ~/projects/my-app/.claude/agents/

# 只装 skills（领域知识）
cp -r .claude/skills/ ~/projects/my-app/.claude/skills/
```

## 自定义你的 Workflow

1. **改 CLAUDE.md** — 填入你的项目约定（测试命令、分支规范、语言版本）
2. **改 agents/** — 调整审查关注点，或增减 agent（比如加一个 `a11y-reviewer.md`）
3. **改 skills/** — 替换为你的代码规范（命名约定、错误处理策略、安全规则）
4. **改 commands/** — 调整门控条件（哪些问题阻断流程，哪些只警告）
5. **改 settings.json** — 按需增减 Hook（自动格式化、分支保护、commit 提醒）
