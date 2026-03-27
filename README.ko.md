<div align="center">

# Claude Code Blueprint

**실전에서 검증된 Claude Code 참조 아키텍처입니다. 설치하는 플러그인이 아니라 배우고 적응하는 블루프린트입니다.**

[![Stars](https://img.shields.io/github/stars/faizkhairi/claude-code-blueprint?style=flat)](https://github.com/faizkhairi/claude-code-blueprint/stargazers)
[![Forks](https://img.shields.io/github/forks/faizkhairi/claude-code-blueprint?style=flat)](https://github.com/faizkhairi/claude-code-blueprint/network/members)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-2.1.85-blueviolet)](https://docs.anthropic.com/en/docs/claude-code)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**11 agents** · **17 skills** · **10 hooks** · **5 rules** -- 모두 실전에서 검증됨

[English](README.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [简体中文](README.zh.md)

<img src="assets/walkthrough.gif" alt="Claude Code Blueprint Walkthrough" width="680">

</div>

---

## Quick Start

하나의 파일을 복사하세요. 3개의 행동 규칙을 얻으세요. 60초 안에 완료.

```bash
# 프로젝트 루트에서
curl -o CLAUDE.md https://raw.githubusercontent.com/faizkhairi/claude-code-blueprint/main/CLAUDE.md
```

이렇게 하면 Claude Code에 가장 흔한 AI 코딩 실수를 방지하는 3가지 규칙을 제공합니다:

**Verify-After-Complete** · **Diagnose-First** · **Plan-Before-Execute**

더 알고 싶으신가요? [전체 도입 경로](#recommended-adoption-path)를 보거나 [30분 초보자 가이드](GETTING-STARTED.md)를 참조하세요.

---

### Before You Start

> **중요:** 이것은 프로젝트 템플릿이 아니라 참조 아키텍처입니다. 이 저장소 내에서 Claude Code를 실행하지 마세요 — 블루프린트 자체의 CLAUDE.md를 읽어들여 당신의 프로젝트 규칙을 무시합니다. 자신의 프로젝트에 Fork하거나 파일을 선택적으로 가져가세요.
>
> 여러 파일은 플레이스홀더 변수(`{MEMORYCORE_PATH}`, `{PROJECTS_ROOT}`)를 포함하며 실제 경로로 바꿔야 합니다. Hooks와 설정은 프로젝트 디렉토리가 아니라 **사용자 수준** 설정(`~/.claude/`)에 있어야 합니다. 전체 설정 가이드는 [GETTING-STARTED.md](GETTING-STARTED.md)를 참조하세요.

---

## What Makes This Different

다른 저장소는 **135개 agents**를 제공합니다. 우리는 **11개**를 제공합니다 -- 그리고 각각이 왜 존재하는지 설명합니다.

| 이 블루프린트 | 범용 설정 저장소 |
|-------------|----------------|
| 모든 컴포넌트는 왜 존재하는지 설명하는 [실전 경험담](WHY.md)을 가지고 있습니다 | 컨텍스트 없는 설정 |
| AI 코딩 실수를 방지하는 [3개의 행동 규칙](CLAUDE.md) | 복사할 설정 목록 |
| Cursor, Codex, Gemini, Windsurf를 위한 [교차 도구 가이드](CROSS-TOOL-GUIDE.md) | 단일 도구만 |
| [초보자 친화적](GETTING-STARTED.md) 6개의 도입 페르소나 | 전문성 가정 |
| [35개 자동 테스트](hooks/test-hooks.sh)를 통한 [스모크 테스트 hooks](hooks/test-hooks.sh) | 테스트되지 않은 스크립트 |
| Safety-first: [설정 배치 가이드](GETTING-STARTED.md#where-config-belongs-project-vs-personal), 개인정보 경고, [우아한 성능 저하](agents/README.md#agents-are-not-infallible) | 안전 지침 없음 |

---

## What's Inside

<details>
<summary><strong>11 Agents</strong> -- 모델 티어링(opus/sonnet/haiku)을 갖춘 전문화된 서브 에이전트</summary>

&nbsp;

| Agent | Model | 역할 |
|-------|-------|------|
| project-architect | opus | 시스템 설계, 아키텍처 결정, 기술 선택 |
| backend-specialist | sonnet | API 끝점, 서비스, 데이터베이스 작동, 미들웨어 |
| frontend-specialist | sonnet | UI 컴포넌트, 상태 관리, 폼, 스타일링 |
| code-reviewer | sonnet | 코드 품질, 패턴, 모범 사례 (읽기 전용) |
| security-reviewer | sonnet | OWASP Top 10, 인증 결함, 주입 공격 (읽기 전용) |
| db-analyst | sonnet | 스키마 분석, 쿼리 최적화, 마이그레이션 계획 (읽기 전용) |
| devops-engineer | sonnet | 배포 설정, CI/CD, Docker, 인프라 (읽기 전용) |
| qa-tester | sonnet | 단위 테스트, 통합 테스트, E2E 테스트 |
| verify-plan | sonnet | 7포인트 기계적 계획 검증 (읽기 전용) |
| docs-writer | haiku | README, API 문서, 변경 로그, 아키텍처 문서 |
| api-documenter | haiku | OpenAPI 스펙, 통합 가이드 (읽기 전용) |

[agents/README.md](agents/README.md)에서 권한 모드, 비용 추정, maxTurns를 참조하세요.

</details>

<details>
<summary><strong>17 Skills</strong> -- 자연어 트리거 워크플로우(슬래시 명령 필요 없음)</summary>

&nbsp;

| 범주 | Skills | 트리거 |
|-----|--------|--------|
| Code Quality | review, review-diff | "이게 안전한가?", "scan diff", "취약점 확인" |
| Testing | test-check, e2e-check | "테스트 실행", "브라우저 테스트", "테스트가 통과했나?" |
| Deployment | deploy-check | "배포", "프로드 푸시", "배포 준비 완료" |
| Planning | sprint-plan, elicit-requirements | "빌드하자", "새로운 기능", 다중 단계 작업 |
| Session | load-session, save-session, session-end, save-diary | 세션 시작/종료, "저장", "안녕", "완료" |
| Project | init-project, register-project, status, changelog | "새 프로젝트", "상태", "변경 로그" |
| Database | db-check | "스키마 확인", "모델 검증" |
| Utilities | tech-radar | "뭐가 새로워?", "업그레이드해야 할까?" |

[skills/README.md](skills/README.md)에서 커스터마이제이션과 플레이스홀더 변수 설정을 참조하세요.

</details>

<details>
<summary><strong>10 Hooks</strong> -- 결정적인 라이프사이클 자동화(100% 준수, CLAUDE.md 규칙은 ~80%)</summary>

&nbsp;

| 이벤트 | Hook | 목적 |
|--------|------|------|
| SessionStart | session-start.sh | 작업공간 컨텍스트 주입 |
| PreToolUse (Bash) | block-git-push.sh | 원격 저장소 보호 |
| PreToolUse (Write/Edit) | protect-config.sh | linter/build 설정 가드 |
| PostToolUse (Write/Edit) | notify-file-changed.sh | 검증 알림 |
| PostToolUse (Bash) | post-commit-review.sh | 커밋 후 검토 |
| PreCompact | precompact-state.sh | 상태를 디스크에 직렬화 |
| Stop | security check + cost-tracker.sh | 최후 방어 + 메트릭 |
| SessionEnd | session-checkpoint.sh | 보장된 최종 저장 |

추가 2개 유틸리티 스크립트: `verify-mcp-sync.sh` (MCP 설정 확인) 및 `status-line.sh` (브랜치/프로젝트 상태).

`bash hooks/test-hooks.sh`를 실행하여 모든 hooks가 통과하는지 확인하세요 (35개 자동 테스트).

[hooks/README.md](hooks/README.md)에서 전체 라이프사이클, 테스트 가이드, 설계 원칙을 참조하세요.

</details>

<details>
<summary><strong>5 Rules</strong> -- 경로 범위 행동 제약(일치하는 파일 편집 시에만 로드)</summary>

&nbsp;

| 규칙 | 활성화 | 목적 |
|------|--------|------|
| api-endpoints | `**/server/api/**/*.{js,ts}` | API 라우트 규칙 |
| database-schema | `**/prisma/**`, `**/drizzle/**`, `**/migrations/**` | 스키마 설계 패턴 |
| testing | `**/*.test.*`, `**/*.spec.*` | 테스트 작성 규칙 |
| session-lifecycle | 항상 | 세션 시작/종료 동작 |
| memorycore-session | `**/memory-core/**` | 외부 메모리 통합 |

[rules/README.md](rules/README.md)에서 커스텀 규칙 생성을 참조하세요.

</details>

**포함된 추가 항목:**

| 컴포넌트 | 목적 |
|---------|------|
| [**CLAUDE.md**](CLAUDE.md) | 실전 검증된 행동 규칙 템플릿 |
| [**Settings Template**](examples/settings-template.json) | 완전한 hook + 권한 설정 |
| [**Memory System**](memory-template/) | 이중: 자동 메모리 + 외부 Git 기반 지속성 |

---

## Philosophy

1. **집행은 hooks, 안내는 CLAUDE.md** -- Hooks는 100% 발동합니다. CLAUDE.md 명령은 약 80% 따릅니다. 반드시 발생해야 하면 hook으로 만드세요.

2. **Agent 범위 지식, 전역 복잡성 아니오** -- 설계 원칙은 프론트엔드 에이전트에, 모든 세션의 컨텍스트에 아닙니다. 보안 패턴은 security-reviewer에, CLAUDE.md에 아닙니다.

3. **컨텍스트는 통화다** -- 컨텍스트에 로드된 모든 토큰은 코드에 사용할 수 없는 토큰입니다. MEMORY.md는 100줄 미만으로 유지하세요. 주제 파일로 추출하세요. 관련 없는 규칙이 로드되지 않도록 경로 범위 규칙을 사용하세요.

4. **Hooks는 무료, 컨텍스트는 저렴** -- 10개 hook 스크립트는 토큰 비용 제로입니다 (Claude 컨텍스트 외부에서 실행). CLAUDE.md는 세션당 약 2,300 토큰을 추가합니다 -- 일반 세션의 약 1-5%. 블루프린트는 재시도 사이클 방지로 비용 이상의 토큰을 절약합니다. [BENCHMARKS.md](BENCHMARKS.md#token-cost-per-component) 참조.

5. **이론 위의 실전** -- 이 저장소의 모든 규칙은 뭔가 잘못되었을 때 존재합니다. "왜"가 "뭐"보다 중요합니다.

---

## Getting Started

### 누구를 위한 것인가요

| 당신은 | 여기서 시작 | 도입 |
|--------|-----------|------|
| **완전 초보자** | [Start Here](GETTING-STARTED.md#new-to-claude-code-start-here) | 1분 설정: CLAUDE.md 복사만 하면 됩니다 |
| **솔로 개발자, 소규모 프로젝트** | [CLAUDE.md](CLAUDE.md) + 2개 hooks | 충분합니다. 과하게 엔지니어링하지 마세요. |
| **소규모 스타트업(2-5명)** | 위의 + 공유 규칙 + 2-3개 agents | [Team Setup](GETTING-STARTED.md#setting-up-for-teams) 보기 |
| **기존 팀(5명 이상)** | 전체 블루프린트, 커스터마이즈됨 | 포크, 커스터마이즈, 공유 설정 커밋 |
| **코딩 학습 중** | [GETTING-STARTED.md](GETTING-STARTED.md)만 | Agents/skills/memory는 편해질 때까지 무시 |
| **다른 도구에서 전환 중** | [CROSS-TOOL-GUIDE.md](CROSS-TOOL-GUIDE.md) | 개념은 이전되고, 필요한 것만 적응하세요 |

### Option A: Fork (권장)

이 저장소를 포크해서 자신만의 살아있는 참조로 커스터마이즈하세요. 나중에 블루프린트가 진화하면 업스트림 업데이트를 가져올 수 있습니다.

### Option B: Clone + Copy

저장소를 클론한 다음 `~/.claude/` 디렉토리에 선택적으로 컴포넌트를 복사하세요.

### Option C: Cherry-pick

GitHub에서 저장소를 찾아보고 필요한 특정 파일만 복사하세요. 설치 필요 없습니다.

### Recommended adoption path

1. **[CLAUDE.md](CLAUDE.md)부터 시작하세요** -- 행동 규칙 템플릿. 설정 없이 가장 큰 영향.
2. **2-3개 hooks 추가하세요** -- [`protect-config.sh`](hooks/protect-config.sh) + [`notify-file-changed.sh`](hooks/notify-file-changed.sh) + [`cost-tracker.sh`](hooks/cost-tracker.sh). `~/.claude/hooks/`에 복사하고 [`settings.json`](examples/settings-template.json)에 연결하세요.
3. **[WHY.md](WHY.md)를 읽으세요** 논리를 이해하기 위해 -- 무조건 복사하지 말고 적응하세요.
4. **워크플로우가 성숙하면 agents를 추가하세요** -- `verify-plan`과 `code-reviewer`부터 시작하세요.
5. **교차 세션 지속성이 필요할 때 [memory system](memory-template/)을 설정하세요**.

---

## Deep Dives

| | | |
|:--|:--|:--|
| **[Architecture](ARCHITECTURE.md)** | **[Settings Guide](SETTINGS-GUIDE.md)** | **[Battle Stories](WHY.md)** |
| 시스템 설계, hook 라이프사이클, 컴포넌트 관계 | 모든 환경 변수, 권한, hook 설명(비용 영향 포함) | 모든 컴포넌트 뒤의 사건과 교훈 |
| **[Benchmarks](BENCHMARKS.md)** | **[Presets](PRESETS.md)** | **[Cross-Tool Guide](CROSS-TOOL-GUIDE.md)** |
| 토큰 절감, 비용 영향, 품질 메트릭 | 솔로, 팀, CI/CD 환경을 위한 복사 준비된 설정 | Cursor, Codex CLI, Gemini CLI, Windsurf |

---

## Troubleshooting

Hooks가 발동하지 않음, agents 실패, MCP 크래시, 비용 놀라움, Windows 특정 문제에 대한 해결책은 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)를 참조하세요.

---

<details>
<summary><strong>Plugin Compatibility</strong></summary>

&nbsp;

이 블루프린트는 **독립형 설정**으로 설계되었습니다 -- 플러그인 필요 없음. 실제로 플러그인은 커스텀 설정에 간섭할 수 있습니다:

**알려진 문제점:**
- **CLAUDE.md를 수정하는 플러그인**은 커스텀 행동 규칙을 덮어쓸 수 있습니다
- **hooks를 추가하는 플러그인**(예: Stop, PreToolUse과 같은 이벤트)은 당신의 hooks와 함께 쌓입니다 -- 이는 느림이나 충돌하는 명령을 야기할 수 있습니다
- **컨텍스트를 주입하는 플러그인**은 컨텍스트 창에서 토큰을 소비하고, agents와 memory system을 위한 공간을 줄입니다
- **MCP 서버 플러그인**은 이 설정과 잘 작동합니다 -- rules이 아닌 tools를 추가하므로 충돌이 없습니다

**권장사항:** 이 블루프린트를 도입하면 설치된 플러그인을 감사하고 다음을 하는 플러그인을 비활성화하세요:
1. CLAUDE.md나 settings.json hooks를 무시합니다
2. SessionStart에 prompts를 주입합니다(session-lifecycle rule과 충돌)
3. 권한 제약을 무시하는 광범위한 권한을 추가합니다

커스텀 설정 > 범용 플러그인. 당신의 설정은 *당신 프로젝트의* 도메인 지식을 인코드하기 때문입니다. 플러그인은 아키텍처, 팀 규칙, 프로덕션 제약을 알 수 없습니다.

</details>

---

## Acknowledgments

이 블루프린트의 memory system 패턴은 Kiyoraka의 [Project-AI-MemoryCore](https://github.com/Kiyoraka/Project-AI-MemoryCore)에서 영감을 받았습니다 -- LRU 프로젝트 관리, 메모리 통합, 에코 회상 등 11개 기능 확장이 있는 포괄적인 AI 메모리 아키텍처입니다. 여기 포함된 최소한의 스캐폴드보다 더 깊고 기능 풍부한 메모리 시스템을 원하면 그 프로젝트를 확인하세요.

**어떻게 다른가요:** 이 블루프린트는 *전체 Claude Code 설정*(agents, skills, hooks, rules, settings)을 다룹니다. 여기 `memory-template/`는 가벼운 스캐폴드입니다. Project-AI-MemoryCore는 메모리 계층에 깊이 가집니다 -- 경쟁하지 않고 보완합니다.

## License

MIT
