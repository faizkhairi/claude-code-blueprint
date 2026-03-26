# Claude Code Blueprint

**Available in:** [English](README.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [简体中文](README.zh.md)

실전에서 검증된 Claude Code 파워 유저를 위한 참조 아키텍처입니다. 설치하는 플러그인이 아니라 배우고 적응하는 블루프린트입니다.

> **Claude Code 2.1.83**(2026년 3월)으로 마지막 검증됨. 핵심 패턴은 버전 간에 작동하며, 버전별 기능은 본문에 명시되어 있습니다.

## 이것이 뭔가요

이 저장소는 수많은 실제 개발 세션을 통해 구축된 프로덕션 Claude Code 설정을 문서화합니다. 모든 agent, skill, hook, rule은 실제 사건이 필요함을 가르쳐줬기에 존재합니다.

**이것은 범용 스타터 킷이 아닙니다.** 파워 유저가 Claude Code를 최대한 생산성 있게 설정하는 방법을 보여주는 참조 아키텍처이며, 모든 결정의 논리를 담고 있습니다.

**Claude Code가 처음인가요?** [GETTING-STARTED.md](GETTING-STARTED.md)부터 시작하세요 — CLI, MCP 서버, 플러그인, 그리고 처음 30분을 다루는 초보자 친화적 가이드입니다.

## 무엇이 포함되어 있나요

| 컴포넌트 | 개수 | 목적 |
|---------|------|------|
| [**Agents**](agents/) | 11개 | 모델 티어링(opus/sonnet/haiku)을 갖춘 전문화된 서브 에이전트 |
| [**Skills**](skills/) | 17개 | 자연어 트리거 워크플로우(슬래시 명령 필요 없음) |
| [**Hooks**](hooks/) | 10개 | 결정적인 라이프사이클 자동화(10개 훅 이벤트) |
| [**Rules**](rules/) | 5개 | 경로 범위 행동 제약 |
| [**Memory System**](memory-template/) | 이중 | 자동 메모리 + 외부 Git 기반 지속성 |
| [**CLAUDE.md**](CLAUDE.md) | 템플릿 | 실전 검증된 행동 규칙 |
| [**Settings**](examples/settings-template.json) | 템플릿 | 완전한 hook + 권한 설정 |

## 철학

1. **집행은 hooks, 안내는 CLAUDE.md** — Hooks는 100% 발동합니다. CLAUDE.md 명령은 약 80% 따릅니다. 반드시 발생해야 하면 hook으로 만드세요.

2. **Agent 범위 지식, 전역 복잡성 아니오** — 설계 원칙은 프론트엔드 에이전트에, 모든 세션의 컨텍스트에 아닙니다. 보안 패턴은 security-reviewer에, CLAUDE.md에 아닙니다.

3. **컨텍스트는 통화다** — 컨텍스트에 로드된 모든 토큰은 코드에 사용할 수 없는 토큰입니다. MEMORY.md는 100줄 미만으로 유지하세요. 주제 파일로 추출하세요. 관련 없는 규칙이 로드되지 않도록 경로 범위 규칙을 사용하세요.

4. **Hooks는 무료, 컨텍스트는 저렴** — 10개 hook 스크립트는 토큰 비용 제로입니다 (Claude 컨텍스트 외부에서 실행). CLAUDE.md는 세션당 약 2,300 토큰을 추가합니다 — 일반 세션의 약 1-5%. 블루프린트는 재시도 사이클 방지로 비용 이상의 토큰을 절약합니다. [BENCHMARKS.md](BENCHMARKS.md#token-cost-per-component) 참조.

5. **이론 위의 실전** — 이 저장소의 모든 규칙은 뭔가 잘못되었을 때 존재합니다. "왜"가 "뭐"보다 중요합니다.

## 시작하기

### 옵션 A: 포크(권장)
이 저장소를 포크해서 자신만의 살아있는 참조로 커스터마이즈하세요. 나중에 블루프린트가 진화하면 업스트림 업데이트를 가져올 수 있습니다.

### 옵션 B: 클론 + 복사
저장소를 클론한 다음 `~/.claude/` 디렉토리에 선택적으로 컴포넌트를 복사하세요.

### 옵션 C: 원하는 것만 선택
GitHub에서 저장소를 찾아보고 필요한 특정 파일만 복사하세요. 설치 필요 없습니다.

### 권장 도입 경로

1. **[CLAUDE.md](CLAUDE.md)부터 시작하세요** — 행동 규칙 템플릿. 설정 없이 가장 큰 영향.
2. **2-3개 hooks 추가하세요** — [`protect-config.sh`](hooks/protect-config.sh) + [`notify-file-changed.sh`](hooks/notify-file-changed.sh) + [`cost-tracker.sh`](hooks/cost-tracker.sh). `~/.claude/hooks/`에 복사하고 [`settings.json`](examples/settings-template.json)에 연결하세요.
3. **[WHY.md](WHY.md)를 읽으세요** 논리를 이해하기 위해 — 무조건 복사하지 말고 적응하세요.
4. **워크플로우가 성숙하면 agents를 추가하세요** — `verify-plan`과 `code-reviewer`부터 시작하세요.
5. **교차 세션 지속성이 필요할 때 [memory system](memory-template/)을 설정하세요**.

### 누구를 위한 것인가요

| 당신은 | 여기서 시작 | 도입 |
|--------|-----------|------|
| **완전 초보자** | [Start Here](GETTING-STARTED.md#new-to-claude-code-start-here) | 1분 설정: CLAUDE.md 복사만 하면 됩니다 |
| **솔로 개발자, 소규모 프로젝트** | [CLAUDE.md](CLAUDE.md) + 2개 hooks | 충분합니다. 과하게 엔지니어링하지 마세요. |
| **소규모 스타트업(2-5명)** | 위의 + 공유 규칙 + 2-3개 agents | [Team Setup](GETTING-STARTED.md#setting-up-for-teams) 보기 |
| **기존 팀(5명 이상)** | 전체 블루프린트, 커스터마이즈됨 | 포크, 커스터마이즈, 공유 설정 커밋 |
| **코딩 학습 중** | [GETTING-STARTED.md](GETTING-STARTED.md)만 | Agents/skills/memory는 편해질 때까지 무시 |
| **다른 도구에서 전환 중** | [CROSS-TOOL-GUIDE.md](CROSS-TOOL-GUIDE.md) | 개념은 이전되고, 필요한 것만 적응하세요 |

## 아키텍처

전체 시스템 설계, 컴포넌트 관계, hook 라이프사이클 다이어그램은 [ARCHITECTURE.md](ARCHITECTURE.md)를 참조하세요.

## 설정

[settings-template.json](examples/settings-template.json)의 모든 환경 변수, 권한, hook에 대한 완전한 설명(비용 영향 포함 및 다중 에이전트 워크플로우에 필요한 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 플래그)은 [SETTINGS-GUIDE.md](SETTINGS-GUIDE.md)를 참조하세요.

## 실전 경험담

모든 컴포넌트 뒤의 사건과 교훈은 [WHY.md](WHY.md)를 참조하세요. 이것은 저장소에서 가장 소중한 파일입니다 — *왜* 각 부분이 존재하는지 설명합니다.

## 다른 AI 코딩 도구와 함께 사용

이 블루프린트는 Claude Code용으로 구축되었지만, **개념은 범용적입니다**. 각 개념이 Cursor, Codex CLI, Gemini CLI, Windsurf로 어떻게 변환되는지는 [CROSS-TOOL-GUIDE.md](CROSS-TOOL-GUIDE.md)를 참조하세요.

## 스타터 프리셋

어디서 시작해야 할지 모르시나요? **[PRESETS.md](PRESETS.md)**에는 솔로 개발자, 팀, CI/CD 파이프라인용 복사 준비가 된 파일 목록이 있습니다 — 각 티어별 정확한 settings.json 스니펫이 포함됩니다.

## 벤치마크

실제 성능 데이터. **[BENCHMARKS.md](BENCHMARKS.md)**는 프로덕션 사용에서 토큰 절감, 비용 영향, 품질 메트릭을 보여줍니다.

## 문제 해결

Hooks가 발동하지 않음, agents 실패, MCP 크래시, 비용 놀라움, Windows 특정 문제에 대한 해결책은 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)를 참조하세요.

## 플러그인 호환성

이 블루프린트는 **독립형 설정**으로 설계되었습니다 — 플러그인 필요 없음. 실제로 플러그인은 커스텀 설정에 간섭할 수 있습니다:

### 알려진 문제점
- **CLAUDE.md를 수정하는 플러그인**은 커스텀 행동 규칙을 덮어쓸 수 있습니다
- **hooks를 추가하는 플러그인**(예: Stop, PreToolUse과 같은 이벤트)은 당신의 hooks와 함께 쌓입니다 — 이는 느림이나 충돌하는 명령을 야기할 수 있습니다
- **컨텍스트를 주입하는 플러그인**은 컨텍스트 창에서 토큰을 소비하고, agents와 memory system을 위한 공간을 남깁니다
- **MCP 서버 플러그인**은 이 설정과 잘 작동합니다 — rules이 아닌 tools를 추가하므로 충돌이 없습니다

### 권장사항
이 블루프린트를 도입하면 설치된 플러그인을 감사하고 다음을 하는 플러그인을 비활성화하세요:
1. CLAUDE.md나 settings.json hooks를 무시합니다
2. SessionStart에 prompts를 주입합니다(session-lifecycle rule과 충돌)
3. 권한 제약을 무시하는 광범위한 권한을 추가합니다

커스텀 설정 > 범용 플러그인. 당신의 설정은 *당신 프로젝트의* 도메인 지식을 인코드하기 때문입니다. 플러그인은 아키텍처, 팀 규칙, 프로덕션 제약을 알 수 없습니다.

## 감사의 말

이 블루프린트의 memory system 패턴은 Kiyoraka의 [Project-AI-MemoryCore](https://github.com/Kiyoraka/Project-AI-MemoryCore)에서 영감을 받았습니다 — LRU 프로젝트 관리, 메모리 통합, 에코 회상 등 11개 기능 확장이 있는 포괄적인 AI 메모리 아키텍처입니다. 여기 포함된 최소한의 스캐폴드보다 더 깊고 기능 풍부한 메모리 시스템을 원하면 그 프로젝트를 확인하세요.

**어떻게 다른가요:** 이 블루프린트는 *전체 Claude Code 설정*(agents, skills, hooks, rules, settings)을 다룹니다. 여기 `memory-template/`는 가벼운 스캐폴드입니다. Project-AI-MemoryCore는 메모리 계층에 깊이 가집니다 — 경쟁하지 않고 보완합니다.

## 라이선스

MIT
