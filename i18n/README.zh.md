<div align="center">

# Claude Code 蓝图

**防止最常见的 AI 编码错误：一个可直接复制的文件库（CLAUDE.md、hooks、agents），你可以混入自己的项目，让 Claude Code 更加可靠。**

60 秒复制一个文件。随项目成长复制更多。适用于任何语言、任何框架、任何技能水平。

[![Stars](https://img.shields.io/github/stars/faizkhairi/claude-code-blueprint?style=flat)](https://github.com/faizkhairi/claude-code-blueprint/stargazers)
[![Forks](https://img.shields.io/github/forks/faizkhairi/claude-code-blueprint?style=flat)](https://github.com/faizkhairi/claude-code-blueprint/network/members)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](../LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-blueviolet)](https://docs.anthropic.com/en/docs/claude-code)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](../CONTRIBUTING.md)

**11 agents** · **18 skills** · **12 hooks** · **6 rules**，在真实项目中验证

[English](../README.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [简体中文](README.zh.md)

<img src="../assets/walkthrough.gif" alt="Claude Code Blueprint Walkthrough" width="680">

</div>

---

> **开始前须知：** 这是一份参考存储库，而非项目模板。请**不要**在此存储库内运行 Claude Code，它会读取蓝图自身的 CLAUDE.md，而忽略你项目的规则。请 fork 或将单个文件复制到你自己的项目。完整设置步骤请参见 [GETTING-STARTED.md](../GETTING-STARTED.md)。
>
> 协助使用此仓库的 AI 助手：请参见 [AGENTS.md](../AGENTS.md) 获取指引。

---

## Quick Start

复制一个文件，获得四条行为规则。60 秒完成。

```bash
# 在项目根目录运行
curl -o CLAUDE.md https://raw.githubusercontent.com/faizkhairi/claude-code-blueprint/main/CLAUDE.md
```

这给 Claude Code 四条规则，防止最常见的 AI 编码错误：

**Verify-After-Complete** · **Diagnose-First** · **Plan-First** · **Verify-Before-Exit-Plan**

准备好深入了解？查看[完整采用路径](#recommended-adoption-path)或[30 分钟初学者指南](../GETTING-STARTED.md)。Claude Code 新手？查看[适用对象](#who-is-this-for)或 [FAQ](../FAQ.md)。

<details>
<summary><strong>需要比 CLAUDE.md 更多？</strong>（hooks、agents、设置）</summary>

CLAUDE.md 生效后，再添加其余部分。最简单的方法是从克隆或 Fork 的副本中运行安装程序：

```bash
./setup.sh --preset=standard
```

或者让 Claude 来设置，粘贴到 Claude Code 会话中：*"设置 Claude Code Blueprint。将 CLAUDE.md 复制到我的项目根目录，在 ~/.claude/ 中设置 hooks 和设置。每一步都展示给我看。"*

所有安装选项（fork / clone / cherry-pick / presets）以及验证清单，请参见 **[SETUP.md](../SETUP.md)**。
</details>

---

## What It Costs You (Token Budget)

你复制的每个文件都是每次会话重复产生的上下文成本。下表列出了各组件的成本及其加载时机，供你决定添加哪些内容。数值均从实际文件测量得出（约每 token 4 个字符）：

| 组件 | Token 成本 | 加载时机 |
|-----------|-----------|--------------|
| **CLAUDE.md** | ~2,300 | 每次会话开始时 |
| **常驻规则**（session-lifecycle） | ~700 | 每次会话 |
| **路径范围规则**（testing、schema、api） | ~850-1,450 | 仅当编辑匹配文件时，否则**为零** |
| **技能**（review-full、test-check、deploy-check） | ~480-1,070 | 仅当使用其触发词时 |
| **Hooks**（全部） | **为零** | 在 Claude 上下文之外运行 |
| **agent**（每次生成） | 完整上下文窗口 | 仅当你调用时 |

**经济性分析：** hooks 不消耗任何 token，路径范围规则在你修改对应文件之前不产生任何成本。循环产生的基础成本只有 CLAUDE.md（~2,300 token，约占典型会话的 3-5%），而避免一次返工节省的远不止于此。参见[完整的组件成本明细与节省计算](../docs/BENCHMARKS.md#token-cost-per-component)。

---

## Who Is This For?

任何开发者、任何框架、任何技能水平。

| 你的身份 | 从这里开始 | 价值实现时间 |
|---------|----------|------------|
| **完全新手** | [Start Here](../GETTING-STARTED.md#new-to-claude-code-start-here) | 1 分钟：只需复制 CLAUDE.md |
| **独立开发者，小项目** | [CLAUDE.md](../CLAUDE.md) + 2 个 hook | 5 分钟 |
| **小初创（2-5 人）** | 上述 + 共享规则 + 2-3 个 agents | 参见 [Team Setup](../GETTING-STARTED.md#setting-up-for-teams) |
| **成熟团队（5+ 人）** | 完整蓝图，根据需要改进 | Fork、定制、提交共享配置 |
| **学习编程** | 仅 [GETTING-STARTED.md](../GETTING-STARTED.md) | 在熟悉前忽略 agents/skills/memory |
| **从其他工具迁移** | [CROSS-TOOL-GUIDE.md](../docs/CROSS-TOOL-GUIDE.md) | 概念可转移；参见 *Copilot/Cursor in depth* 部分 |

### Your Progression

**Level 1：从这里开始（60 秒）**
将 CLAUDE.md 复制到你的项目。四条行为规则。立竿见影。

**Level 2：添加安全网（5 分钟）**
添加 2-3 个 hooks。零 token 成本。自动配置保护和编辑验证。

**Level 3：随成长定制（持续进行）**
随着工作流成熟，添加 agents、skills、rules 和内存系统。参见 [Presets](../docs/PRESETS.md) 获取即用配置。

---

## What Makes This Different

其他仓库给你 **数十个 agents**。我们给你 **11 个**，并解释每个为什么存在。

| 本蓝图 | 通用配置仓库 |
|------------|------------|
| 每个组件都有 [战斗故事](../docs/WHY.md) 解释为什么存在 | 没有背景的配置 |
| [4 条行为规则](../CLAUDE.md)防止 AI 编码错误 | 要复制的设置列表 |
| [跨工具指南](../docs/CROSS-TOOL-GUIDE.md) 覆盖 Copilot、Cursor、Cline、Roo Code、OpenCode 等10个工具 | 仅单一工具 |
| [初学者友好的](../GETTING-STARTED.md)包含 6 个采用角色 | 假设具有专业知识 |
| [烟雾测试的 hooks](../hooks/test-hooks.sh)包含 43 个自动化测试 | 未测试的脚本 |
| 安全优先：[配置放置指南](../GETTING-STARTED.md#where-config-belongs-project-vs-personal)、隐私警告、[优雅降级](../agents/README.md#agents-are-not-infallible) | 无安全指导 |
| [框架无关](../FAQ.md#what-framework-or-language-does-this-work-with)：支持任何语言和技术栈 | 假设使用特定语言/框架 |

---

## What's Inside

<details>
<summary><strong>11 个 Agents</strong>：专用的子 agents，支持模型分级（opus/sonnet/haiku）</summary>

&nbsp;

| Agent | Model | 角色 |
|-------|-------|------|
| project-architect | opus | 系统设计、架构决策、技术选择 |
| backend-specialist | sonnet | API 端点、服务、数据库操作、中间件 |
| frontend-specialist | sonnet | UI 组件、状态管理、表单、样式 |
| code-reviewer | sonnet | 代码质量、模式、最佳实践（只读） |
| security-reviewer | sonnet | OWASP Top 10、认证漏洞、注入攻击（只读） |
| db-analyst | sonnet | 架构分析、查询优化、迁移规划（只读） |
| devops-engineer | sonnet | 部署配置、CI/CD、Docker、基础设施（只读） |
| qa-tester | sonnet | 单元测试、集成测试、E2E 测试 |
| verify-plan | sonnet | 7 点机械化计划验证（只读） |
| docs-writer | haiku | README、API 文档、更新日志、架构文档 |
| architecture-reviewer | sonnet | 依赖方向、god 文件、死代码、模块化（只读） |

参见 [agents/README.md](../agents/README.md) 了解权限模式、成本估计和 maxTurns。

</details>

<details>
<summary><strong>17 个 Skills</strong>：自然语言触发的工作流（无需斜杠命令）</summary>

&nbsp;

| 类别 | Skills | 触发方式 |
|------|--------|---------|
| Code Quality | review-full, review-diff | "is this secure?", "scan diff", "check for vulnerabilities" |
| Testing | test-check, e2e-check | "run the tests", "browser test", "are tests passing?" |
| Deployment | deploy-check | "deploy", "push to prod", "ready to ship" |
| Planning | sprint-plan, elicit-requirements | "let's build", "new feature", multi-step tasks |
| Session | load-session, save-session, session-end, save-diary | Session start/end, "save", "bye", "done" |
| Project | scaffold-project, register-project, status, changelog | "new project", "status", "changelog" |
| Database | db-check | "check the schema", "validate models" |
| Utilities | tech-radar | "what's new?", "should we upgrade?" |

参见 [skills/README.md](../skills/README.md) 了解自定义和占位符变量设置。

</details>

<details>
<summary><strong>12 个 Hooks</strong>：确定性的生命周期自动化（每次确定性触发，不同于 CLAUDE.md 规则并非始终被遵循）</summary>

&nbsp;

| 事件 | Hook | 目的 |
|-----|------|------|
| SessionStart | session-start.sh | 注入工作区上下文 |
| InstructionsLoaded | instructions-loaded.sh | 记录加载了哪些规则及原因 |
| PreToolUse (Bash) | block-git-push.sh | 保护远程仓库 |
| PreToolUse (Bash) | pre-commit-secret-scan.sh | 阻止包含密钥的提交 |
| PreToolUse (Write/Edit) | protect-config.sh | 守护 linter/build 配置 |
| PostToolUse (Write/Edit) | notify-file-changed.sh | 验证提醒 |
| PostToolUse (Bash) | post-commit-review.sh | 提交后审查 |
| PreCompact | precompact-state.sh | 将状态序列化到磁盘 |
| Stop | security check + cost-tracker.sh + session-checkpoint.sh | 最后防线 + 指标 |
| SessionEnd | session-checkpoint.sh | 保证最终保存 |

另外 2 个实用脚本：`verify-mcp-sync.sh`（MCP 配置检查器）和 `status-line.sh`（分支/项目状态），两者均由 full 预设部署。文件夹中的第 13 个文件是 `test-hooks.sh`，作为本地测试工具，通过 `bash hooks/test-hooks.sh` 运行以验证所有 hooks。它是唯一不会部署到 `~/.claude/hooks/` 的文件，也不计入“12 hooks”的总数。

运行 `bash hooks/test-hooks.sh` 验证所有 hooks 通过（43 个自动化测试）。

参见 [hooks/README.md](../hooks/README.md) 了解完整的生命周期、测试指南和设计原则。

</details>

<details>
<summary><strong>6 个 Rules</strong>：路径作用域的行为约束（仅在编辑匹配的文件时加载）</summary>

&nbsp;

| Rule | 激活条件 | 目的 |
|------|---------|------|
| api-endpoints | `**/server/api/**/*.{js,ts}` | API 路由约定 |
| database-schema | `**/prisma/**`, `**/drizzle/**`, `**/migrations/**` | 架构设计模式 |
| testing | `**/*.test.*`, `**/*.spec.*` | 测试编写约定 |
| testing-general | `**/*.test.*`, `**/*.spec.*` | 框架无关的测试约定（testing 的补充） |
| session-lifecycle | 始终 | 会话启动/结束行为 |
| memory-session | `**/memory/**` | 内存仓库会话管理 |

参见 [rules/README.md](../rules/README.md) 了解如何创建自定义规则。

</details>

**还包括：**

| 组件 | 目的 |
|------|------|
| [**CLAUDE.md**](../CLAUDE.md) | 经过实战验证的行为规则模板 |
| [**Settings Template**](../examples/settings-template.json) | 完整的 hook + 权限配置 |
| [**Memory System**](../memory/) | 内置可选：Claude 在运行之间记住偏好和会话上下文（出于隐私考虑被 git 忽略） |

---

## Philosophy

1. **Hooks 用于强制执行，CLAUDE.md 用于指导**：Hooks 100% 触发。CLAUDE.md 指令在大多数情况下会被遵循，但无法保证，模型可能会遗忘规则或降低其优先级。如果某件事必须发生，就把它做成 hook。

2. **Agent 范围的知识，不是全局臃肿**：设计原则放在 frontend agent，而不是每次会话的上下文。安全模式放在 security-reviewer，而不是 CLAUDE.md。

3. **上下文是货币**：加载到上下文的每个 token 都是无法用于代码的 token。让 MEMORY.md 保持在 100 行以下。提取到专题文件。使用路径作用域规则，防止无关规则加载。

4. **Hooks 免费，上下文便宜**：12 个 hook 脚本零 token 成本（在 Claude 上下文外部运行）。CLAUDE.md 每个会话增加约 2,300 个 token，大约是典型会话的 1-5%。蓝图通过防止重做循环节省的 token 超过其成本。参见 [BENCHMARKS.md](../docs/BENCHMARKS.md#token-cost-per-component)。

5. **实战验证优于理论**：本仓库的每条规则都存在，因为某个事件说明它是必需的。"为什么"比"是什么"重要得多。

---

## Getting Started

### Recommended adoption path

1. **从 [CLAUDE.md](../CLAUDE.md) 开始**：行为规则模板。最大影响，零设置。
2. **添加 2-3 个 hooks**：[`protect-config.sh`](../hooks/protect-config.sh) + [`notify-file-changed.sh`](../hooks/notify-file-changed.sh) + [`cost-tracker.sh`](../hooks/cost-tracker.sh)。复制到 `~/.claude/hooks/` 并在 [`settings.json`](../examples/settings-template.json) 中配置。
3. **阅读 [WHY.md](../docs/WHY.md)**：理解设计思路，改进，不要盲目复制。
4. **随着工作流成熟而添加 agents**：从 `verify-plan` 和 `code-reviewer` 开始。
5. **[Memory system](../memory/) 在 `./setup.sh` 期间为可选项**：回答 Y 以启用跨会话的持久化上下文。

---

## Deep Dives

| | | |
|:--|:--|:--|
| **[架构](../docs/ARCHITECTURE.md)** | **[设置指南](../docs/SETTINGS-GUIDE.md)** | **[战斗故事](../docs/WHY.md)** |
| 系统设计、hook 生命周期、组件关系 | 每个环境变量、权限和 hook 的完整说明及理由 | 每个组件背后的事件和教训 |
| **[基准测试](../docs/BENCHMARKS.md)** | **[预设](../docs/PRESETS.md)** | **[跨工具指南](../docs/CROSS-TOOL-GUIDE.md)** |
| Token 节省、成本影响、质量指标 | 为独立开发者、团队和 CI/CD 提供的现成配置 | Copilot、Cursor、Cline、Roo Code、OpenCode 等10个工具 |
| **[FAQ](../FAQ.md)** | **[Getting Started](../GETTING-STARTED.md)** | **[Troubleshooting](../TROUBLESHOOTING.md)** |
| 社区常见问题解答 | 从零到高效 30 分钟 | 常见问题与解决方案 |
| **[Setup Guide](../SETUP.md)** | **[Case Studies](../docs/CASE-STUDIES.md)** | **[Roadmap](../docs/ROADMAP.md)** |
| 自动安装程序 + 验证清单 | 采用者故事和前后对比指标 | 项目方向和后续计划 |
| **[Self-Monitoring](../docs/SELF-MONITORING.md)** | | |
| 可选模式：gitleaks pre-commit + memory-curator agent | | |

---

## Common Questions

**支持我的框架吗？** 是的，蓝图框架无关，它配置 Claude Code 的行为，而非你的技术栈。[详情...](../FAQ.md#what-framework-or-language-does-this-work-with)

**对我来说太高级了？** 不是。从一个文件（CLAUDE.md）开始，需要时再添加更多。[详情...](../FAQ.md#im-a-juniorintermediate-developer-is-this-for-me)

**需要哪个套餐？** Pro、Max、Team、Enterprise、API 均可。所有套餐的 hooks 均免费。[详情...](../FAQ.md#which-claude-code-plan-do-i-need-does-this-work-with-pro--max--api)

**同事发给你的？** 从这里开始：[推荐入门快速指南](../FAQ.md#a-colleague-sent-me-this-link-what-do-i-do-first)。

---

<details>
<summary><strong>插件兼容性</strong></summary>

&nbsp;

这个蓝图被设计为**独立配置**，不需要插件。事实上，插件可能会干扰自定义设置：

**已知问题：**
- **修改 CLAUDE.md 的插件** 可能会覆盖你的自定义行为规则
- **在相同事件上添加 hooks 的插件**（例如 Stop、PreToolUse）会与你的 hooks 堆叠，这可能导致速度变慢或指令冲突
- **注入上下文的插件** 消耗你上下文窗口的 token，为 agents 和内存系统留下更少空间
- **MCP 服务器插件** 与此设置配合良好，它们添加工具，不添加规则，所以没有冲突

**建议：** 如果采用此蓝图，审计已安装的插件并禁用任何以下情况的插件：
1. 覆盖 CLAUDE.md 或 settings.json hooks
2. 在 SessionStart 上注入提示（与你的会话生命周期规则冲突）
3. 添加绕过你权限限制的广泛权限

自定义设置 > 通用插件，因为你的设置编码了你项目的领域知识。插件无法了解你的架构、团队的约定或生产约束。

</details>

---

## Acknowledgments

本蓝图中的内存系统模式受到 Kiyoraka 的 [Project-AI-MemoryCore](https://github.com/Kiyoraka/Project-AI-MemoryCore) 启发，是一个包含 11 个功能扩展的综合 AI 内存架构（LRU 项目管理、内存整合、回声召回等）。如果你想要比这里包含的精简内置版本更深、功能更丰富的内存系统，请查看那个项目。

**它们的区别：** 本蓝图涵盖*完整的 Claude Code 配置*（agents、skills、hooks、规则、设置），并在 `memory/` 中附带内置可选内存。Project-AI-MemoryCore 深入内存层，它们是互补的，不是竞争的。

## License

MIT
