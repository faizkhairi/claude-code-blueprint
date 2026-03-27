<div align="center">

# Claude Code 蓝图

**经过实战验证的参考架构，为 Claude Code 高级用户设计。不是插件——是一份蓝图，用来学习和改进。**

[![Stars](https://img.shields.io/github/stars/faizkhairi/claude-code-blueprint?style=flat)](https://github.com/faizkhairi/claude-code-blueprint/stargazers)
[![Forks](https://img.shields.io/github/forks/faizkhairi/claude-code-blueprint?style=flat)](https://github.com/faizkhairi/claude-code-blueprint/network/members)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-2.1.85-blueviolet)](https://docs.anthropic.com/en/docs/claude-code)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**11 agents** · **17 skills** · **10 hooks** · **5 rules** -- 每一个都经过实战验证

[English](README.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [简体中文](README.zh.md)

<img src="assets/walkthrough.gif" alt="Claude Code Blueprint Walkthrough" width="680">

</div>

---

## 快速开始

复制一个文件，获得三条行为规则。60 秒完成。

```bash
# 在项目根目录运行
curl -o CLAUDE.md https://raw.githubusercontent.com/faizkhairi/claude-code-blueprint/main/CLAUDE.md
```

这给 Claude Code 三条规则，防止最常见的 AI 编码错误：

**Verify-After-Complete** · **Diagnose-First** · **Plan-Before-Execute**

准备好深入了解？查看[完整采用路径](#推荐的采用路径)或[30 分钟初学者指南](GETTING-STARTED.md)。

---

### 开始前须知

> **重要：** 这是一份参考架构，而非项目模板。请**不要**在此存储库内运行 Claude Code — 它会读取蓝图自身的 CLAUDE.md，而忽略你项目的规则。请 Fork 或将文件选择性地移入你自己的项目。
>
> 某些文件包含占位符变量（`{MEMORYCORE_PATH}`、`{PROJECTS_ROOT}`），需要替换为实际路径。Hooks 和设置应该放在**用户级**配置（`~/.claude/`）中，而不是项目目录。完整的设置指南请参见 [GETTING-STARTED.md](GETTING-STARTED.md)。

---

## 与众不同之处

其他仓库给你 **135 个 agents**。我们给你 **11 个** — 并解释每个为什么存在。

| 本蓝图 | 通用配置仓库 |
|------------|------------|
| 每个组件都有 [战斗故事](WHY.md)解释为什么存在 | 没有背景的配置 |
| [3 条行为规则](CLAUDE.md)防止 AI 编码错误 | 要复制的设置列表 |
| [跨工具指南](CROSS-TOOL-GUIDE.md)为 Cursor、Codex、Gemini、Windsurf | 仅单一工具 |
| [初学者友好的](GETTING-STARTED.md)包含 6 个采用角色 | 假设具有专业知识 |
| [烟雾测试的 hooks](hooks/test-hooks.sh)包含 35 个自动化测试 | 未测试的脚本 |
| 安全优先：[配置放置指南](GETTING-STARTED.md#where-config-belongs-project-vs-personal)、隐私警告、[优雅降级](agents/README.md#agents-are-not-infallible) | 无安全指导 |

---

## 包含的内容

<details>
<summary><strong>11 个 Agents</strong> -- 专用的子 agents，支持模型分级（opus/sonnet/haiku）</summary>

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
| api-documenter | haiku | OpenAPI 规范、集成指南（只读） |

参见 [agents/README.md](agents/README.md) 了解权限模式、成本估计和 maxTurns。

</details>

<details>
<summary><strong>17 个 Skills</strong> -- 自然语言触发的工作流（无需斜杠命令）</summary>

&nbsp;

| 类别 | Skills | 触发方式 |
|------|--------|---------|
| Code Quality | review, review-diff | "is this secure?", "scan diff", "check for vulnerabilities" |
| Testing | test-check, e2e-check | "run the tests", "browser test", "are tests passing?" |
| Deployment | deploy-check | "deploy", "push to prod", "ready to ship" |
| Planning | sprint-plan, elicit-requirements | "let's build", "new feature", multi-step tasks |
| Session | load-session, save-session, session-end, save-diary | Session start/end, "save", "bye", "done" |
| Project | init-project, register-project, status, changelog | "new project", "status", "changelog" |
| Database | db-check | "check the schema", "validate models" |
| Utilities | tech-radar | "what's new?", "should we upgrade?" |

参见 [skills/README.md](skills/README.md) 了解自定义和占位符变量设置。

</details>

<details>
<summary><strong>10 个 Hooks</strong> -- 确定性的生命周期自动化（100% 遵循率，不同于 CLAUDE.md 规则的约 80%）</summary>

&nbsp;

| 事件 | Hook | 目的 |
|-----|------|------|
| SessionStart | session-start.sh | 注入工作区上下文 |
| PreToolUse (Bash) | block-git-push.sh | 保护远程仓库 |
| PreToolUse (Write/Edit) | protect-config.sh | 守护 linter/build 配置 |
| PostToolUse (Write/Edit) | notify-file-changed.sh | 验证提醒 |
| PostToolUse (Bash) | post-commit-review.sh | 提交后审查 |
| PreCompact | precompact-state.sh | 将状态序列化到磁盘 |
| Stop | security check + cost-tracker.sh | 最后防线 + 指标 |
| SessionEnd | session-checkpoint.sh | 保证最终保存 |

另外 2 个实用脚本：`verify-mcp-sync.sh`（MCP 配置检查器）和 `status-line.sh`（分支/项目状态）。

运行 `bash hooks/test-hooks.sh` 验证所有 hooks 通过（35 个自动化测试）。

参见 [hooks/README.md](hooks/README.md) 了解完整的生命周期、测试指南和设计原则。

</details>

<details>
<summary><strong>5 个 Rules</strong> -- 路径作用域的行为约束（仅在编辑匹配的文件时加载）</summary>

&nbsp;

| Rule | 激活条件 | 目的 |
|------|---------|------|
| api-endpoints | `**/server/api/**/*.{js,ts}` | API 路由约定 |
| database-schema | `**/prisma/**`, `**/drizzle/**`, `**/migrations/**` | 架构设计模式 |
| testing | `**/*.test.*`, `**/*.spec.*` | 测试编写约定 |
| session-lifecycle | 始终 | 会话启动/结束行为 |
| memorycore-session | `**/memory-core/**` | 外部内存集成 |

参见 [rules/README.md](rules/README.md) 了解如何创建自定义规则。

</details>

**还包括：**

| 组件 | 目的 |
|------|------|
| [**CLAUDE.md**](CLAUDE.md) | 经过实战验证的行为规则模板 |
| [**Settings Template**](examples/settings-template.json) | 完整的 hook + 权限配置 |
| [**Memory System**](memory-template/) | 双重：自动内存 + 外部 git 备份持久化 |

---

## 哲学

1. **Hooks 用于强制执行，CLAUDE.md 用于指导** -- Hooks 100% 触发。CLAUDE.md 指令约 80% 被遵循。如果某件事必须发生，就把它做成 hook。

2. **Agent 范围的知识，不是全局臃肿** -- 设计原则放在 frontend agent，而不是每次会话的上下文。安全模式放在 security-reviewer，而不是 CLAUDE.md。

3. **上下文是货币** -- 加载到上下文的每个 token 都是无法用于代码的 token。保持 MEMORY.md 在 100 行以下。提取到专题文件。使用路径作用域规则，使无关规则不会加载。

4. **Hooks 免费，上下文便宜** -- 10 个 hook 脚本零 token 成本（在 Claude 上下文外部运行）。CLAUDE.md 每个会话增加约 2,300 个 token — 大约是典型会话的 1-5%。蓝图通过防止重做循环节省的 token 超过其成本。参见 [BENCHMARKS.md](BENCHMARKS.md#token-cost-per-component)。

5. **实战验证优于理论** -- 本仓库的每条规则都存在，因为某个事件说明它是必需的。"为什么"比"是什么"重要得多。

---

## 开始使用

### 这是为谁准备的？

| 你的身份 | 从这里开始 | 采用 |
|---------|----------|------|
| **完全新手** | [Start Here](GETTING-STARTED.md#new-to-claude-code-start-here) | 1 分钟设置：只需复制 CLAUDE.md |
| **独立开发者，小项目** | [CLAUDE.md](CLAUDE.md) + 2 个 hook | 足够了。不要过度设计。 |
| **小初创（2-5 人）** | 上述 + 共享规则 + 2-3 个 agents | 参见 [Team Setup](GETTING-STARTED.md#setting-up-for-teams) |
| **成熟团队（5+ 人）** | 完整蓝图，根据需要改进 | Fork、定制、提交共享配置 |
| **学习编程** | 仅 [GETTING-STARTED.md](GETTING-STARTED.md) | 在熟悉前忽略 agents/skills/memory |
| **从其他工具迁移** | [CROSS-TOOL-GUIDE.md](CROSS-TOOL-GUIDE.md) | 概念可转移；根据需要改进 |

### 选项 A：Fork（推荐）
Fork 本仓库并将其定制为你自己的活文档参考。之后可以拉取上游更新，随着蓝图的演变而更新。

### 选项 B：Clone + Copy
Clone 仓库，然后有选择地将组件复制到你的 `~/.claude/` 目录。

### 选项 C：Cherry-pick
在 GitHub 上浏览仓库，只复制你需要的特定文件。无需安装。

### 推荐的采用路径

1. **从 [CLAUDE.md](CLAUDE.md) 开始** -- 行为规则模板。最大影响，零设置。
2. **添加 2-3 个 hooks** -- [`protect-config.sh`](hooks/protect-config.sh) + [`notify-file-changed.sh`](hooks/notify-file-changed.sh) + [`cost-tracker.sh`](hooks/cost-tracker.sh)。复制到 `~/.claude/hooks/` 并在 [`settings.json`](examples/settings-template.json) 中配置。
3. **阅读 [WHY.md](WHY.md)** 理解设计思路 -- 改进，不要盲目复制。
4. **随着工作流成熟而添加 agents** -- 从 `verify-plan` 和 `code-reviewer` 开始。
5. **当需要跨会话持久化时设置 [memory system](memory-template/)**。

---

## 深入学习

| | | |
|:--|:--|:--|
| **[架构](ARCHITECTURE.md)** | **[设置指南](SETTINGS-GUIDE.md)** | **[战斗故事](WHY.md)** |
| 系统设计、hook 生命周期、组件关系 | 每个环境变量、权限和 hook 的完整说明及理由 | 每个组件背后的事件和教训 |
| **[基准测试](BENCHMARKS.md)** | **[预设](PRESETS.md)** | **[跨工具指南](CROSS-TOOL-GUIDE.md)** |
| Token 节省、成本影响、质量指标 | 为独立开发者、团队和 CI/CD 提供的现成配置 | Cursor、Codex CLI、Gemini CLI、Windsurf |

---

## 故障排除

参见 [TROUBLESHOOTING.md](TROUBLESHOOTING.md) 了解常见问题的解决方案 -- hooks 未触发、agents 失败、MCP 崩溃、成本意外、Windows 特定问题等。

---

<details>
<summary><strong>插件兼容性</strong></summary>

&nbsp;

这个蓝图被设计为**独立配置** -- 不需要插件。事实上，插件可能会干扰自定义设置：

**已知问题：**
- **修改 CLAUDE.md 的插件** 可能会覆盖你的自定义行为规则
- **在相同事件上添加 hooks 的插件**（例如 Stop、PreToolUse）会与你的 hooks 堆叠 -- 这可能导致速度变慢或指令冲突
- **注入上下文的插件** 消耗你上下文窗口的 token，为 agents 和内存系统留下更少空间
- **MCP 服务器插件** 与此设置配合良好 -- 它们添加工具，不添加规则，所以没有冲突

**建议：** 如果采用此蓝图，审计已安装的插件并禁用任何以下情况的插件：
1. 覆盖 CLAUDE.md 或 settings.json hooks
2. 在 SessionStart 上注入提示（与你的会话生命周期规则冲突）
3. 添加绕过你权限限制的广泛权限

自定义设置 > 通用插件，因为你的设置编码了你项目的领域知识。插件无法了解你的架构、团队的约定或生产约束。

</details>

---

## 致谢

本蓝图中的内存系统模式受到 Kiyoraka 的 [Project-AI-MemoryCore](https://github.com/Kiyoraka/Project-AI-MemoryCore) 启发 -- 一个包含 11 个功能扩展的综合 AI 内存架构（LRU 项目管理、内存整合、回声召回等）。如果你想要比这里包含的最小框架更深、功能更丰富的内存系统，请查看那个项目。

**它们的区别：** 本蓝图涵盖*完整的 Claude Code 配置*（agents、skills、hooks、规则、设置）。这里的 `memory-template/` 是轻量级框架。Project-AI-MemoryCore 深入内存层 -- 它们是互补的，不是竞争的。

## 许可证

MIT
