# 课后作业：Workflow 实战

> **本章目标**：独立完成 4 个 Workflow 作业，综合运用全书所学
>
> | 章节 | 关键词 |
> |:-----|:------|
> | Ch0 生态概览 | 工具选型 · 开发模式 |
> | Ch1 项目规划 | Plan Agent · 需求分析 |
> | Ch2 项目脚手架 | CLAUDE.md · CLI 搭建 |
> | Ch3 理解变更 | Explore Agent · Git Diff |
> | Ch4 设计审查团队 | Agent 设计 · Prompt 工程 |
> | Ch5 并行审查 | Fan-out/Fan-in · 并行执行 |
> | Ch6 报告生成 | 结果聚合 · 条件逻辑 |
> | Ch7 自动化 | Hooks · Skills |
> | Ch8 质量保障 | 测试策略 · TDD |
> | Ch9 模板库 | 模式提炼 · 最佳实践 |
> | **► 附录 课后作业** | **Workflow 实战** |

> 学完了全部章节，是时候自己动手了。这次没有手把手教程，只有需求。

---

## 作业列表

4 个作业覆盖软件开发生命周期的不同阶段，每个作业侧重不同的模式组合：

| # | 作业 | 场景 | 核心模式 |
|---|------|------|----------|
| 1 | [Develop Workflow](10a_develop_workflow.md) | 从需求到可运行代码的全流程 | Explore → Specialized Agent → Sequential → Test-Driven |
| 2 | [Test Workflow](10b_test_workflow.md) | 自动生成测试套件并驱动质量闭环 | Explore → Fan-out/Fan-in → Test-Driven → Event-Driven |
| 3 | [Security Audit Workflow](10c_audit_workflow.md) | 扫描项目安全隐患并生成审计报告 | Explore → Specialized Agent → Fan-out/Fan-in → Sequential |
| 4 | [Compliance Test Workflow](10d_compliance_workflow.md) | 检查终端设备/移动 OS 是否符合工信部及网络安全法规 | Explore → Specialized Agent → Fan-out/Fan-in → Event-Driven |

---

## 共同背景

作业 1-3 共享同一个目标项目：一个 C/C++ 网络库，包含 HTTP 协议解析器和 TCP 连接池，约 60 个文件，12000 行代码。作业 4 的目标项目是一个国产移动操作系统的系统级组件（同样是 C/C++ 实现）。

你可以用任何现有的开源项目作为练习对象，也可以自己搭一个最小骨架。

---

## 建议顺序

1. 先做 **Develop Workflow**——最基础的 Sequential 编排，流程固定，帮你热身
2. 再做 **Test Workflow**——加入 Fan-out 和 Test-Driven 循环，需要自己决定测试生成的拆分策略
3. 然后做 **Security Audit Workflow**——纯分析型任务，agent 架构、误报控制、评级体系全部自己设计
4. 最后做 **Compliance Test Workflow**——最综合，需要把法规领域知识映射到 agent 架构，还涉及自动整改

当然，你也可以按自己的兴趣随意挑选。

---

> 没有标准答案。用你在这本教程中学到的模式，设计你自己的方案。祝你编排愉快。

---

[上一章: Ch9 — 模板库](09_templates.md)
