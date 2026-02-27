# Ch9: 六种编排模式 — 从一个项目到一套方法论

> 做完一个项目不算本事，能把经验变成可复用的模板才是真功夫。
>
> | 章节 | 关键词 |
> |:-----|:------|
> | Ch0 工具选型 | 工具选型 · 开发模式 |
> | Ch1 需求分析 | Plan Agent · 需求分析 |
> | Ch2 搭建脚手架 | CLAUDE.md · CLI 搭建 |
> | Ch3 解析 Git Diff | Explore Agent · Git Diff |
> | Ch4 Agent 设计 | Agent 设计 · Prompt 工程 |
> | Ch5 Fan-out/Fan-in | Fan-out/Fan-in · 并行执行 |
> | Ch6 结果聚合 | 结果聚合 · 条件逻辑 |
> | Ch7 Hooks 与 Skills | Hooks · Skills |
> | Ch8 测试驱动 | 测试策略 · TDD |
> | **► Ch9 六种编排模式** | **模式提炼 · 最佳实践** |
> | 附录 课后作业 | Workflow 实战 |

**术语**

- Orchestration（编排，按逻辑组织多个 Agent 协同工作）
- CI/CD（Continuous Integration/Continuous Delivery，持续集成/持续交付）
- PRD（Product Requirements Document，产品需求文档）
- CRUD（Create/Read/Update/Delete，增删改查）
- Pipeline（流水线，数据依次流经多个处理阶段的模式）

## 9.1 场景引入

Review Bot 完工了。回头看看，构建过程中用到了这些编排模式：

- 顺序工作流（Ch2: 搭脚手架）
- Explore Agent（Ch3: 理解变更）
- Agent 设计（Ch4: 专业化分工）
- Fan-out / Fan-in（Ch5: 并行审查）
- 结果聚合（Ch6: 报告生成）
- Hooks + Skills（Ch7: 自动化）
- 测试工作流（Ch8: 质量保障）

这些模式不只适用于 Code Review。它们是通用的 workflow 编排模式，可以套用到任何场景。

---

## 9.2 模式总结

### 模式 1: Sequential（顺序执行）

```
A → B → C → D
```

**适用场景**: 步骤之间有严格依赖，后一步需要前一步的输出。

**Review Bot 中的应用**: 搭建脚手架（创建配置 → 生成代码 → 安装依赖 → 验证）

**模板**:
```
Step 1: [准备] → 验证 ✓
Step 2: [执行] → 验证 ✓
Step 3: [收尾] → 验证 ✓
```

### 模式 2: Fan-out / Fan-in（分发-收集）

```
        ┌── Agent A ──┐
Input ──┼── Agent B ──┼── Aggregate
        └── Agent C ──┘
```

**适用场景**: 多个独立任务可以并行，最后汇总结果。

**Review Bot 中的应用**: 4 个审查 agent 并行执行，汇总报告。

**模板**:
```
1. 准备共享输入
2. 同时派出 N 个 agent（各自独立上下文）
3. 等待所有 agent 完成
4. 聚合结果 + 条件判断
```

### 模式 3: Explore（探索-理解）

```
目标 → Explore Agent → 结构化理解 → 下一步决策
```

**适用场景**: 面对不熟悉的代码/数据，需要先理解再行动。

**Review Bot 中的应用**: 用 Explore agent 理解 git diff 的结构和变更范围。

**模板**:
```
1. 明确探索目标（"理解 X 的结构"）
2. 派出 Explore agent（只读，不修改）
3. 收集探索结果
4. 基于理解做出决策
```

**其他应用**:
- 接手新项目时，先探索代码库结构
- 调试 bug 时，先理解相关模块的调用链
- 做技术选型时，先探索现有依赖和约束

### 模式 4: Event-Driven（事件驱动）

```
事件 → Hook 触发 → 自动执行 → 反馈
```

**适用场景**: 某些操作应该在特定事件发生时自动执行，不需要人工干预。

**Review Bot 中的应用**: commit 后自动触发审查，代码修改后自动格式化。

**模板**:
```
1. 定义触发事件（哪个工具、什么模式）
2. PreToolUse: 前置校验（可选，可拦截）
3. 核心操作执行
4. PostToolUse: 后置处理（格式化、测试、通知）
```

**其他应用**:
- 写完代码自动跑 linter
- 创建文件时自动添加 license header
- 执行危险命令前自动确认

### 模式 5: Test-Driven（测试驱动）

```
写代码 → 自动测试 → 失败 → 修复 → 重新测试 → 通过 ✓
```

**适用场景**: 需要持续验证代码质量，确保修改不会破坏已有功能。

**Review Bot 中的应用**: Hook 自动跑 pytest，失败时 agent 自动修复。

**模板**:
```
1. 编写/修改代码
2. Hook 自动触发测试
3. 测试失败 → Agent 分析错误 → 修复 → 回到 2
   测试通过 → 继续下一步
```

### 模式 6: Specialized Agent（专业化分工）

```
通用任务 → 拆分为专业维度 → 每个维度一个专家 agent
```

**适用场景**: 任务涉及多个专业领域，单个 agent 难以面面俱到。

**Review Bot 中的应用**: 安全、性能、风格、逻辑四个专业 agent。

**模板**:
```
1. 识别任务的专业维度
2. 为每个维度设计 agent（角色 + 能力 + 约束）
3. 统一输出格式（在设计阶段就定好）
4. 编排执行（串行或并行）
```

---

## 9.3 模式组合：Review Bot 的完整编排

回顾 Review Bot 的完整流程，你会发现它不是单一模式，而是多种模式的组合：

```
Plan（规划）
  ↓
Sequential（搭建脚手架）
  ↓
Explore（理解 git diff）
  ↓
Specialized Agent（设计 4 个专家）
  ↓
Fan-out / Fan-in（并行审查 + 汇总）
  ↓
Event-Driven（Hook 自动触发）
  ↓
Test-Driven（持续验证质量）
```

这就是 workflow 编排的本质：**把简单模式像乐高一样拼起来，解决复杂问题**。

### 9.3.1 套用到其他场景

| 场景 | 可能用到的模式组合 |
|------|--------------------|
| 功能开发 | Explore → Specialized Agent → Sequential → Test-Driven |
| 测试生成 | Explore → Fan-out/Fan-in → Test-Driven → Event-Driven |
| 安全审计 | Explore → Specialized Agent → Fan-out/Fan-in → Sequential |
| 合规检测 | Explore → Specialized Agent → Fan-out/Fan-in → Event-Driven |

---

## 9.4 小结

- 6 种核心模式：Sequential、Fan-out/Fan-in、Explore、Event-Driven、Test-Driven、Specialized Agent
- 模式不是孤立的，真实项目往往是多种模式的组合
- 先理解每种模式的适用场景，再根据需求自由组合
- 模板是起点，不是终点——根据实际情况调整

---

