# Claude Code 蓝图

经过实战验证的参考架构，为 Claude Code 高级用户设计。不是插件——是一份蓝图，用来学习和改进。

**可用语言：** [English](README.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [简体中文](README.zh.md)

> 最后验证版本：**Claude Code 2.1.83**（2026年3月）。核心模式在各版本通用；版本特定功能会在文中标注。

## 这是什么

本仓库记录了一套在真实开发工作中积累的生产级 Claude Code 配置。每个 agent、skill、hook 和规则都源于一个真实事件，教会我们它是必需的。

**这不是通用的入门工具包。** 这是一份参考架构，展示高级用户如何配置 Claude Code 以获得最高生产力，以及每个决策背后的思考过程。

**刚接触 Claude Code？** 从 [GETTING-STARTED.md](GETTING-STARTED.md) 开始——一份对初学者友好的指南，覆盖 CLI、MCP 服务器、插件和你的前 30 分钟体验。

## 包含的内容

| 组件 | 数量 | 用途 |
|------|------|------|
| [**Agents**](agents/) | 11 | 专用子 agents，支持模型分级（opus/sonnet/haiku） |
| [**Skills**](skills/) | 17 | 自然语言触发的工作流（无需斜杠命令） |
| [**Hooks**](hooks/) | 10 | 确定性的生命周期自动化（10个 hook 事件） |
| [**Rules**](rules/) | 5 | 路径作用域的行为约束 |
| [**Memory System**](memory-template/) | Dual | 自动内存 + 外部 git 备份持久化 |
| [**CLAUDE.md**](CLAUDE.md) | 模板 | 经过实战验证的行为规则 |
| [**Settings**](examples/settings-template.json) | 模板 | 完整的 hook + 权限配置 |

## 哲学

1. **Hook 用于强制执行，CLAUDE.md 用于指导** — Hook 100% 触发。CLAUDE.md 指令约 80% 被遵循。如果某些事必须发生，就把它做成 hook。

2. **Agent 范围的知识，不是全局臃肿** — 设计原则放在 frontend agent，而不是每次会话的上下文。安全模式放在 security-reviewer，而不是 CLAUDE.md。

3. **上下文是货币** — 加载到上下文的每个 token 都是无法用于代码的 token。保持 MEMORY.md 在 100 行以下。提取到专题文件。使用路径作用域规则，使无关规则不会加载。

4. **实战验证优于理论** — 本仓库的每条规则都存在，因为某个事件说明它是必需的。"为什么"比"是什么"重要得多。

## 快速开始

### 选项 A：Fork（推荐）
Fork 本仓库并将其定制为你自己的活文档参考。之后可以拉取上游更新，随着蓝图的演变而更新。

### 选项 B：Clone + Copy
Clone 仓库，然后有选择地将组件复制到你的 `~/.claude/` 目录。

### 选项 C：Cherry-pick
在 GitHub 上浏览仓库，只复制你需要的特定文件。无需安装。

### 推荐的采用路径

1. **从 [CLAUDE.md](CLAUDE.md) 开始** — 行为规则模板。最小设置，最大影响。
2. **添加 2-3 个 hook** — [`protect-config.sh`](hooks/protect-config.sh) + [`notify-file-changed.sh`](hooks/notify-file-changed.sh) + [`cost-tracker.sh`](hooks/cost-tracker.sh)。复制到 `~/.claude/hooks/` 并在 [`settings.json`](examples/settings-template.json) 中配置。
3. **阅读 [WHY.md](WHY.md)** 理解设计思路 — 改进，不要盲目复制。
4. **随着工作流成熟而添加 agents** — 从 `verify-plan` 和 `code-reviewer` 开始。
5. **当需要跨会话持久化时设置 [memory system](memory-template/)** 。

### 适合谁？

| 你的身份 | 从这里开始 | 采用 |
|---------|----------|------|
| **独立开发者，小项目** | [CLAUDE.md](CLAUDE.md) + 2 个 hook | 足够了。不要过度设计。 |
| **小初创（2-5 人）** | 上述 + 共享规则 + 2-3 个 agents | 参见 [Team Setup](GETTING-STARTED.md#setting-up-for-teams) |
| **成熟团队（5+ 人）** | 完整蓝图，根据需要改进 | Fork、定制、提交共享配置 |
| **学习编程** | 仅 [GETTING-STARTED.md](GETTING-STARTED.md) | 在熟悉前忽略 agents/skills/memory |
| **从其他工具迁移** | [CROSS-TOOL-GUIDE.md](CROSS-TOOL-GUIDE.md) | 概念可转移；根据需要改进 |

## 架构

参见 [ARCHITECTURE.md](ARCHITECTURE.md) 了解完整的系统设计、组件关系和 hook 生命周期图。

## 设置

参见 [SETTINGS-GUIDE.md](SETTINGS-GUIDE.md) 了解 [settings-template.json](examples/settings-template.json) 中每个环境变量、权限和 hook 的完整说明——包括成本影响和多 agent 工作流所需的 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 标志。

## 战斗故事

参见 [WHY.md](WHY.md) 了解每个组件背后的事件和教训。这是本仓库最有价值的文件——它解释了*为什么*每个部分存在。

## 与其他 AI 编程工具一起使用

虽然这个蓝图是为 Claude Code 构建的，但**概念是通用的**。参见 [CROSS-TOOL-GUIDE.md](CROSS-TOOL-GUIDE.md) 了解每个概念如何转移到 Cursor、Codex CLI、Gemini CLI 和 Windsurf。

## 入门预设

不确定从哪里开始？**[PRESETS.md](PRESETS.md)** 为独立开发者、团队和 CI/CD 管道提供了现成的文件列表——每个层级都有确切的 settings.json 代码片段。

## 基准测试

真实世界的性能数据。**[BENCHMARKS.md](BENCHMARKS.md)** 显示生产使用中的 token 节省、成本影响和质量指标。

## 故障排除

参见 [TROUBLESHOOTING.md](TROUBLESHOOTING.md) 了解常见问题的解决方案——hook 未触发、agent 失败、MCP 崩溃、成本意外和 Windows 特定问题。

## 插件兼容性

这个蓝图被设计为**独立配置** — 不需要插件。事实上，插件可能会干扰自定义设置：

### 已知问题
- **修改 CLAUDE.md 的插件** 可能会覆盖你的自定义行为规则
- **在相同事件上添加 hook 的插件**（例如 Stop、PreToolUse）会与你的 hook 堆叠——这可能导致速度变慢或指令冲突
- **注入上下文的插件** 消耗你上下文窗口的 token，为 agents 和内存系统留下更少空间
- **MCP 服务器插件** 与此设置配合良好——它们添加工具，不添加规则，所以没有冲突

### 建议
如果采用此蓝图，审计已安装的插件并禁用任何以下情况的插件：
1. 覆盖 CLAUDE.md 或 settings.json hooks
2. 在 SessionStart 上注入提示（与你的会话生命周期规则冲突）
3. 添加绕过你权限限制的广泛权限

自定义设置 > 通用插件，因为你的设置编码了你项目的领域知识。插件无法了解你的架构、团队的约定或生产约束。

## 致谢

本蓝图中的内存系统模式受到 Kiyoraka 的 [Project-AI-MemoryCore](https://github.com/Kiyoraka/Project-AI-MemoryCore) 启发——一个包含 11 个功能扩展的综合 AI 内存架构（LRU 项目管理、内存整合、回声召回等）。如果你想要比这里包含的最小框架更深、功能更丰富的内存系统，请查看那个项目。

**它们的区别：** 本蓝图涵盖*完整的 Claude Code 配置*（agents、skills、hooks、规则、设置）。这里的 `memory-template/` 是轻量级框架。Project-AI-MemoryCore 深入内存层——它们是互补的，不是竞争的。

## 许可证

MIT
