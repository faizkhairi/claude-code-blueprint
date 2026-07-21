<div align="center">

# Claude Code Blueprint

**가장 흔한 AI 코딩 실수를 방지하세요: 복사-붙여넣기 가능한 파일 라이브러리 (CLAUDE.md, hooks, agents)를 자신의 프로젝트에 섞어 넣어 Claude Code를 더 신뢰할 수 있게.**

60초 안에 한 파일을 복사하세요. 프로젝트가 커지면 더 복사하세요. 모든 언어, 모든 프레임워크, 모든 스킬 레벨에서 작동합니다.

[![Stars](https://img.shields.io/github/stars/faizkhairi/claude-code-blueprint?style=flat)](https://github.com/faizkhairi/claude-code-blueprint)
[![Forks](https://img.shields.io/github/forks/faizkhairi/claude-code-blueprint?style=flat)](https://github.com/faizkhairi/claude-code-blueprint/network/members)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](../LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-blueviolet)](https://docs.anthropic.com/en/docs/claude-code)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](../CONTRIBUTING.md)

**12 agents** · **18 skills** · **12 hooks** · **6 rules**, 실제 프로젝트에서 검증됨

[English](../README.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [简体中文](README.zh.md)

<img src="../assets/walkthrough.gif" alt="Claude Code Blueprint Walkthrough" width="680">

</div>

---

> **시작하기 전에:** 이것은 프로젝트 템플릿이 아니라 참조 저장소입니다. **이 저장소 내에서** Claude Code를 **실행하지 마세요.** (블루프린트 자체의 CLAUDE.md를 로드하여 당신의 프로젝트 규칙을 무시하게 됩니다.) 자신의 프로젝트에 fork하거나 개별 파일을 복사하세요. 전체 설정 안내는 [GETTING-STARTED.md](../GETTING-STARTED.md)를 참조하세요.
>
> 이 저장소로 작업하는 AI 어시스턴트용: 오리엔테이션은 [AGENTS.md](../AGENTS.md)를 참조하세요.

---

## Quick Start

하나의 파일을 복사하세요. 4개의 행동 규칙을 얻으세요. 60초 안에 완료.

```bash
# 프로젝트 루트에서
curl -o CLAUDE.md https://raw.githubusercontent.com/faizkhairi/claude-code-blueprint/main/CLAUDE.md
```

이렇게 하면 Claude Code에 가장 흔한 AI 코딩 실수를 방지하는 4가지 규칙을 제공합니다:

**Verify-After-Complete** · **Diagnose-First** · **Plan-First** · **Verify-Before-Exit-Plan**

더 알고 싶으신가요? [전체 도입 경로](#recommended-adoption-path)를 보거나 [30분 초보자 가이드](../GETTING-STARTED.md)를 참조하세요. Claude Code가 처음이신가요? [대상자](#who-is-this-for)를 확인하거나 [FAQ](../FAQ.md)를 참조하세요.

<details>
<summary><strong>CLAUDE.md 이상을 원하시나요?</strong> (hooks, agents, 설정)</summary>

CLAUDE.md가 작동하면 나머지도 추가하세요. 가장 쉬운 방법은 클론 또는 포크한 복사본에서 설치 프로그램을 실행하는 것입니다:

```bash
./setup.sh --preset=standard
```

또는 Claude에게 맡기세요. Claude Code 세션에 붙여넣기: *"Claude Code Blueprint을 설정해 주세요. CLAUDE.md를 프로젝트 루트에 복사하고, hooks와 설정을 ~/.claude/에 설정해 주세요. 각 단계를 보여주세요."*

모든 설치 옵션(fork / clone / cherry-pick / presets)과 검증 체크리스트는 **[SETUP.md](../SETUP.md)**를 참조하세요.
</details>

---

## What It Costs You (Token Budget)

복사하는 파일은 모두 세션마다 반복적으로 발생하는 컨텍스트 비용이 됩니다. 각 컴포넌트의 비용과 로드되는 시점을 아래에 정리했으니, 무엇을 추가할지 결정하는 데 참고하세요. 수치는 실제 파일에서 측정한 값입니다（1토큰당 약 4자）：

| 컴포넌트 | 토큰 비용 | 로드되는 시점 |
|-----------|-----------|--------------|
| **CLAUDE.md** | ~2,300 | 매 세션 시작 시 |
| **상시 활성 규칙**（session-lifecycle） | ~700 | 매 세션 |
| **경로 범위 규칙**（testing、schema、api） | ~850-1,450 | 해당 파일을 편집할 때만, 그 외에는 **제로** |
| **스킬**（review-full、test-check、deploy-check） | ~480-1,070 | 트리거 문구가 사용될 때만 |
| **Hooks**（전체） | **제로** | Claude의 컨텍스트 외부에서 실행됨 |
| **agent**（스폰당） | 전체 컨텍스트 윈도우 | 호출할 때만 |

**경제성:** hooks는 토큰을 소비하지 않고, 경로 범위 규칙은 해당 파일을 건드리기 전까지 비용이 없습니다. 반복 발생하는 기본 비용은 CLAUDE.md뿐입니다（~2,300 토큰, 일반적인 세션의 약 3-5%）. 재작업 한 번을 방지하는 것만으로 그 비용을 훨씬 초과하는 절약이 됩니다. [컴포넌트별 세부 내역 및 절약 계산](../docs/BENCHMARKS.md#token-cost-per-component)을 참조하세요.

---

## Who Is This For?

모든 개발자, 모든 프레임워크, 모든 스킬 레벨.

| 당신은 | 여기서 시작 | 가치 실현 시간 |
|--------|-----------|--------------|
| **완전 초보자** | [Start Here](../GETTING-STARTED.md#new-to-claude-code-start-here) | 1분: CLAUDE.md 복사만 하면 됩니다 |
| **솔로 개발자, 소규모 프로젝트** | [CLAUDE.md](../CLAUDE.md) + 2개 hooks | 5분 |
| **소규모 스타트업(2-5명)** | 위의 + 공유 규칙 + 2-3개 agents | [Team Setup](../GETTING-STARTED.md#setting-up-for-teams) 보기 |
| **기존 팀(5명 이상)** | 전체 블루프린트, 커스터마이즈됨 | 포크, 커스터마이즈, 공유 설정 커밋 |
| **코딩 학습 중** | [GETTING-STARTED.md](../GETTING-STARTED.md)만 | Agents/skills/memory는 편해질 때까지 무시 |
| **다른 도구에서 전환 중** | [CROSS-TOOL-GUIDE.md](../docs/CROSS-TOOL-GUIDE.md) | 개념은 이전됨; *Copilot/Cursor in depth* 섹션 참조 |

### Your Progression

**Level 1: 여기서 시작 (60초)**
CLAUDE.md를 프로젝트에 복사하세요. 4개의 행동 규칙. 즉각적인 효과.

**Level 2: 안전망 추가 (5분)**
2-3개 hooks를 추가하세요. 토큰 비용 제로. 자동화된 설정 보호와 편집 검증.

**Level 3: 성장하면서 커스터마이즈 (지속적)**
워크플로우가 성숙하면 agents, skills, rules, memory를 추가하세요. 준비된 설정은 [Presets](../docs/PRESETS.md)를 참조하세요.

---

## What Makes This Different

다른 저장소는 **수십 개의 agents**를 제공합니다. 우리는 **11개**를 제공하며, 각각이 왜 존재하는지 설명합니다.

| 이 블루프린트 | 범용 설정 저장소 |
|-------------|----------------|
| 모든 컴포넌트는 왜 존재하는지 설명하는 [실전 경험담](../docs/WHY.md)을 가지고 있습니다 | 컨텍스트 없는 설정 |
| AI 코딩 실수를 방지하는 [4개의 행동 규칙](../CLAUDE.md) | 복사할 설정 목록 |
| Copilot, Cursor, Cline, Roo Code, OpenCode 등 10개 도구를 위한 [교차 도구 가이드](../docs/CROSS-TOOL-GUIDE.md) | 단일 도구만 |
| [초보자 친화적](../GETTING-STARTED.md) 6개의 도입 페르소나 | 전문성 가정 |
| [43개 자동 테스트](../hooks/test-hooks.sh)를 통한 [스모크 테스트 hooks](../hooks/test-hooks.sh) | 테스트되지 않은 스크립트 |
| 안전 우선: [설정 배치 가이드](../GETTING-STARTED.md#where-config-belongs-project-vs-personal), 개인정보 경고, [우아한 성능 저하](../agents/README.md#agents-are-not-infallible) | 안전 지침 없음 |
| [프레임워크 비의존적](../FAQ.md#what-framework-or-language-does-this-work-with): 모든 언어와 스택에서 동작 | 특정 언어/프레임워크를 가정 |

---

## What's Inside

<details>
<summary><strong>12 Agents</strong>: 모델 티어링(opus/sonnet/haiku)을 갖춘 전문화된 sub-agent</summary>

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
| architecture-reviewer | sonnet | 의존성 방향, god 파일, 데드 코드, 모듈성 (읽기 전용) |
| memory-curator | sonnet | 메모리 디렉터리의 고아 파일, 인덱스 드리프트, 깨진 링크, 오래된 항목 감사 (보고 전용) |

[agents/README.md](../agents/README.md)에서 권한 모드, 비용 추정, maxTurns를 참조하세요.

</details>

<details>
<summary><strong>18 Skills</strong>: 자연어 트리거 워크플로우(슬래시 명령 필요 없음)</summary>

&nbsp;

| 범주 | Skills | 트리거 |
|-----|--------|--------|
| Code Quality | review-full, review-diff | "이게 안전한가?", "scan diff", "취약점 확인" |
| PR Review | pr-review | "이 PR 리뷰", "PR #N 리뷰", "PR 리뷰 게시" |
| Testing | test-check, e2e-check | "테스트 실행", "브라우저 테스트", "테스트가 통과했나?" |
| Deployment | deploy-check | "배포", "프로드 푸시", "배포 준비 완료" |
| Planning | sprint-plan, elicit-requirements | "빌드하자", "새로운 기능", 다중 단계 작업 |
| Session | load-session, save-session, session-end, save-diary | 세션 시작/종료, "저장", "안녕", "완료" |
| Project | scaffold-project, register-project, status, changelog | "새 프로젝트", "상태", "변경 로그" |
| Database | db-check | "스키마 확인", "모델 검증" |
| Utilities | tech-radar | "뭐가 새로워?", "업그레이드해야 할까?" |

[skills/README.md](../skills/README.md)에서 커스터마이제이션과 플레이스홀더 변수 설정을 참조하세요.

</details>

<details>
<summary><strong>12 Hooks</strong>: 결정적인 라이프사이클 자동화(100% 준수, CLAUDE.md 규칙은 항상 따르지 않는 것과 달리)</summary>

&nbsp;

| 이벤트 | Hook | 목적 |
|--------|------|------|
| SessionStart | session-start.sh | 작업공간 컨텍스트 주입 |
| InstructionsLoaded | instructions-loaded.sh | 어떤 규칙이 왜 로드되었는지 기록 |
| PreToolUse (Bash) | block-git-push.sh | 원격 저장소 보호 |
| PreToolUse (Bash) | pre-commit-secret-scan.sh | 시크릿이 포함된 커밋 차단 |
| PreToolUse (Write/Edit) | protect-config.sh | linter/build 설정 가드 |
| PostToolUse (Write/Edit) | notify-file-changed.sh | 검증 알림 |
| PostToolUse (Bash) | post-commit-review.sh | 커밋 후 검토 |
| PreCompact | precompact-state.sh | 상태를 디스크에 직렬화 |
| Stop | security check + cost-tracker.sh + session-checkpoint.sh | 최후 방어 + 메트릭 |
| SessionEnd | session-checkpoint.sh | 보장된 최종 저장 |

추가 2개 유틸리티 스크립트: `verify-mcp-sync.sh` (MCP 설정 확인) 및 `status-line.sh` (브랜치/프로젝트 상태). 둘 다 full 프리셋으로 배포됩니다. 폴더의 13번째 파일은 `test-hooks.sh`이며, 로컬 테스트 하네스로 `bash hooks/test-hooks.sh`로 실행하여 모든 hooks를 검증합니다. 이 파일만 `~/.claude/hooks/`에 배포되지 않으며, "12 hooks" 총합에도 포함되지 않습니다.

`bash hooks/test-hooks.sh`를 실행하여 모든 hooks가 통과하는지 확인하세요 (43개 자동 테스트).

[hooks/README.md](../hooks/README.md)에서 전체 라이프사이클, 테스트 가이드, 설계 원칙을 참조하세요.

</details>

<details>
<summary><strong>6 Rules</strong>: 경로 범위 행동 제약(일치하는 파일 편집 시에만 로드)</summary>

&nbsp;

| 규칙 | 활성화 | 목적 |
|------|--------|------|
| api-endpoints | `**/server/api/**/*.{js,ts}` | API 라우트 규칙 |
| database-schema | `**/prisma/**`, `**/drizzle/**`, `**/migrations/**` | 스키마 설계 패턴 |
| testing | `**/*.test.*`, `**/*.spec.*` | 테스트 작성 규칙 |
| testing-general | `**/*.test.*`, `**/*.spec.*` | 프레임워크에 구애받지 않는 테스트 규칙 (testing의 보완) |
| session-lifecycle | 항상 | 세션 시작/종료 동작 |
| memory-session | `**/memory/**` | 메모리 저장소 세션 관리 |

[rules/README.md](../rules/README.md)에서 커스텀 규칙 생성을 참조하세요.

</details>

**포함된 추가 항목:**

| 컴포넌트 | 목적 |
|---------|------|
| [**CLAUDE.md**](../CLAUDE.md) | 실전 검증된 행동 규칙 템플릿 |
| [**Settings Template**](../examples/settings-template.json) | 완전한 hook + 권한 설정 |
| [**Memory System**](../memory/) | 내장 옵트인: Claude가 실행 간에 환경설정과 세션 컨텍스트를 기억 (개인정보 보호를 위해 git 무시) |

---

## Philosophy

1. **집행은 hooks, 안내는 CLAUDE.md**: Hooks는 100% 발동합니다. CLAUDE.md 명령은 대부분 따르지만 보장되지 않습니다. 모델이 규칙을 잊거나 우선순위를 낮출 수 있습니다. 반드시 발생해야 하면 hook으로 만드세요.

2. **Agent 단위의 지식, 전역적 비대화가 아닌 지식**: 설계 원칙은 frontend agent에 두고, 모든 세션의 컨텍스트에 두지 않습니다. 보안 패턴은 security-reviewer에 두고, CLAUDE.md에 두지 않습니다.

3. **컨텍스트는 통화다**: 컨텍스트에 로드된 모든 토큰은 코드에 사용할 수 없는 토큰입니다. MEMORY.md는 100줄 미만으로 유지하세요. 주제 파일로 추출하세요. 관련 없는 규칙이 로드되지 않도록 경로 범위 규칙을 사용하세요.

4. **Hooks는 무료, 컨텍스트는 저렴**: 12개 hook 스크립트는 토큰 비용 제로입니다 (Claude 컨텍스트 외부에서 실행). CLAUDE.md는 세션당 약 2,300 토큰을 추가합니다. 일반 세션의 약 1-5%입니다. 블루프린트는 재시도 사이클 방지로 비용 이상의 토큰을 절약합니다. [BENCHMARKS.md](../docs/BENCHMARKS.md#token-cost-per-component) 참조.

5. **이론 위의 실전**: 이 저장소의 모든 규칙은 뭔가 잘못되었을 때 존재합니다. "왜"가 "뭐"보다 중요합니다.

---

## Getting Started

### Recommended adoption path

1. **[CLAUDE.md](../CLAUDE.md)부터 시작하세요**: 행동 규칙 템플릿. 설정 없이 가장 큰 영향.
2. **2-3개 hooks 추가하세요**: [`protect-config.sh`](../hooks/protect-config.sh) + [`notify-file-changed.sh`](../hooks/notify-file-changed.sh) + [`cost-tracker.sh`](../hooks/cost-tracker.sh). `~/.claude/hooks/`에 복사하고 [`settings.json`](../examples/settings-template.json)에 연결하세요.
3. **[WHY.md](../docs/WHY.md)를 읽으세요**: 논리를 이해하기 위해서입니다. 무조건 복사하지 말고 적응하세요.
4. **워크플로우가 성숙하면 agents를 추가하세요**: `verify-plan`과 `code-reviewer`부터 시작하세요.
5. **[Memory system](../memory/)은 `./setup.sh` 중에 opt-in입니다**: Y로 답하여 세션 간 지속 컨텍스트를 활성화하세요.

---

## Deep Dives

| | | |
|:--|:--|:--|
| **[Architecture](../docs/ARCHITECTURE.md)** | **[Settings Guide](../docs/SETTINGS-GUIDE.md)** | **[Battle Stories](../docs/WHY.md)** |
| 시스템 설계, hook 라이프사이클, 컴포넌트 관계 | 모든 환경 변수, 권한, hook 설명(비용 영향 포함) | 모든 컴포넌트 뒤의 사건과 교훈 |
| **[Benchmarks](../docs/BENCHMARKS.md)** | **[Presets](../docs/PRESETS.md)** | **[Cross-Tool Guide](../docs/CROSS-TOOL-GUIDE.md)** |
| 토큰 절감, 비용 영향, 품질 메트릭 | 솔로, 팀, CI/CD 환경을 위한 복사 준비된 설정 | Copilot, Cursor, Cline, Roo Code, OpenCode 등 10개 도구 |
| **[FAQ](../FAQ.md)** | **[Getting Started](../GETTING-STARTED.md)** | **[Troubleshooting](../TROUBLESHOOTING.md)** |
| 커뮤니티에서 자주 묻는 질문 | 제로에서 생산적으로 30분 | 일반적인 문제와 해결책 |
| **[Setup Guide](../SETUP.md)** | **[Case Studies](../docs/CASE-STUDIES.md)** | **[Roadmap](../docs/ROADMAP.md)** |
| 자동 설치 프로그램 + 검증 체크리스트 | 도입자 스토리와 before/after 메트릭 | 프로젝트 방향과 향후 계획 |
| **[Self-Monitoring](../docs/SELF-MONITORING.md)** | | |
| 선택적 패턴: gitleaks pre-commit + memory-curator agent | | |

---

## Common Questions

**내 프레임워크에서 동작하나요?** 네. 블루프린트는 프레임워크 비의존적입니다. Claude Code를 설정하며, 스택은 상관없습니다. [더 보기...](../FAQ.md#what-framework-or-language-does-this-work-with)

**너무 고급인가요?** 아니요. 하나의 파일(CLAUDE.md)부터 시작하세요. 필요할 때만 더 추가하세요. [더 보기...](../FAQ.md#im-a-juniorintermediate-developer-is-this-for-me)

**어떤 플랜이 필요한가요?** Pro, Max, Team, Enterprise, API 모두 지원합니다. Hooks는 모든 플랜에서 무료입니다. [더 보기...](../FAQ.md#which-claude-code-plan-do-i-need-does-this-work-with-pro--max--api)

**동료가 보내줬나요?** 여기서 시작하세요: [추천 퀵스타트](../FAQ.md#a-colleague-sent-me-this-link-what-do-i-do-first).

---

<details>
<summary><strong>Plugin Compatibility</strong></summary>

&nbsp;

이 블루프린트는 **독립형 설정**으로 설계되었습니다. 플러그인은 필요 없습니다. 실제로 플러그인은 커스텀 설정에 간섭할 수 있습니다:

**알려진 문제점:**
- **CLAUDE.md를 수정하는 플러그인**은 커스텀 행동 규칙을 덮어쓸 수 있습니다
- **hooks를 추가하는 플러그인**(예: Stop, PreToolUse과 같은 이벤트)은 당신의 hooks와 함께 쌓이며, 이는 느림이나 충돌하는 명령을 야기할 수 있습니다
- **컨텍스트를 주입하는 플러그인**은 컨텍스트 창에서 토큰을 소비하고, agents와 memory system을 위한 공간을 줄입니다
- **MCP 서버 플러그인**은 이 설정과 잘 작동합니다. rules이 아닌 tools를 추가하므로 충돌이 없습니다

**권장사항:** 이 블루프린트를 도입하면 설치된 플러그인을 감사하고 다음을 하는 플러그인을 비활성화하세요:
1. CLAUDE.md나 settings.json hooks를 무시합니다
2. SessionStart에 prompts를 주입합니다(session-lifecycle rule과 충돌)
3. 권한 제약을 무시하는 광범위한 권한을 추가합니다

커스텀 설정 > 범용 플러그인. 당신의 설정은 *당신 프로젝트의* 도메인 지식을 인코드하기 때문입니다. 플러그인은 아키텍처, 팀 규칙, 프로덕션 제약을 알 수 없습니다.

</details>

---

## Acknowledgments

이 블루프린트의 memory system 패턴은 Kiyoraka의 [Project-AI-MemoryCore](https://github.com/Kiyoraka/Project-AI-MemoryCore)에서 영감을 받았습니다. LRU 프로젝트 관리, 메모리 통합, 에코 회상 등 11개 기능 확장이 있는 포괄적인 AI 메모리 아키텍처입니다. 여기 포함된 가벼운 내장 버전보다 더 깊고 기능 풍부한 메모리 시스템을 원하면 그 프로젝트를 확인하세요.

**어떻게 다른가요:** 이 블루프린트는 *전체 Claude Code 설정*(agents, skills, hooks, rules, settings)을 다루며, `memory/`에 내장 opt-in 메모리를 함께 제공합니다. Project-AI-MemoryCore는 메모리 계층에 깊이 들어가며, 경쟁하지 않고 보완합니다.

## License

MIT
