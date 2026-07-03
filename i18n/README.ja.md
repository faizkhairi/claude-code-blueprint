<div align="center">

# Claude Code Blueprint

**AI コーディングで最も起こりがちなミスを防ぐ：コピペ可能なファイルのライブラリ（CLAUDE.md、hooks、agents）を自分のプロジェクトに組み込んで、Claude Code をより信頼できるものに。**

60秒で1ファイルをコピー。プロジェクトが成長したらもっとコピー。あらゆる言語、あらゆるフレームワーク、あらゆるスキルレベルで動作します。

[![Stars](https://img.shields.io/github/stars/faizkhairi/claude-code-blueprint?style=flat)](https://github.com/faizkhairi/claude-code-blueprint/stargazers)
[![Forks](https://img.shields.io/github/forks/faizkhairi/claude-code-blueprint?style=flat)](https://github.com/faizkhairi/claude-code-blueprint/network/members)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](../LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-blueviolet)](https://docs.anthropic.com/en/docs/claude-code)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](../CONTRIBUTING.md)

**11 agents** · **17 skills** · **12 hooks** · **6 rules**、実際のプロジェクトで検証済み

[English](../README.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [简体中文](README.zh.md)

<img src="../assets/walkthrough.gif" alt="Claude Code Blueprint Walkthrough" width="680">

</div>

---

> **開始前に：** これは参照リポジトリであり、プロジェクトテンプレートではありません。**このリポジトリ内で** Claude Code を**実行しないでください**。ブループリント自体の CLAUDE.md を読み込み、プロジェクトのルールが無視されます。自分のプロジェクトに fork するか、個別のファイルをコピーしてください。完全なセットアップ手順は [GETTING-STARTED.md](../GETTING-STARTED.md) を参照してください。
>
> このリポジトリで作業する AI アシスタント向け：オリエンテーションは [AGENTS.md](../AGENTS.md) を参照してください。

---

## Quick Start

ファイル1つをコピー。4つの行動ルールを取得。60秒で完了。

```bash
# プロジェクトルートで
curl -o CLAUDE.md https://raw.githubusercontent.com/faizkhairi/claude-code-blueprint/main/CLAUDE.md
```

このコマンドで Claude Code に4つのルールが追加され、AI コーディングの一般的なミスを防ぎます：

**Verify-After-Complete** · **Diagnose-First** · **Plan-First** · **Verify-Before-Exit-Plan**

もっと知りたいですか？ [採用パス（全体図）](#recommended-adoption-path)または[30分の初心者ガイド](../GETTING-STARTED.md)を参照してください。Claude Code は初めてですか？ [対象者](#who-is-this-for)または [FAQ](../FAQ.md) をご覧ください。

<details>
<summary><strong>CLAUDE.md 以上が必要ですか？</strong>（hooks、agents、設定）</summary>

CLAUDE.md が機能したら、残りを追加しましょう。最も簡単な方法は、クローンまたはフォークしたコピーからインストーラーを実行することです：

```bash
./setup.sh --preset=standard
```

または Claude に設定を任せましょう。Claude Code セッションに貼り付け: *「Claude Code Blueprint をセットアップしてください。CLAUDE.md をプロジェクトルートにコピーし、hook と設定を ~/.claude/ に設定してください。各ステップを見せてください。」*

すべてのセットアップオプション（fork / clone / cherry-pick / presets）と検証チェックリストについては **[SETUP.md](../SETUP.md)** をご覧ください。
</details>

---

## What It Costs You (Token Budget)

コピーするファイルはすべて、セッションごとに繰り返し発生するコンテキストコストになります。各コンポーネントのコストとロードされるタイミングを以下に示しますので、何を追加するか判断の参考にしてください。数値は実際のファイルから計測したものです（1トークンあたり約4文字）：

| コンポーネント | トークンコスト | ロードされるタイミング |
|-----------|-----------|---------------|
| **CLAUDE.md** | ~2,300 | 毎セッション開始時 |
| **常時オンのルール**（session-lifecycle） | ~700 | 毎セッション |
| **パススコープルール**（testing、schema、api） | ~850-1,450 | 対象ファイルを編集するときのみ。それ以外は**ゼロ** |
| **スキル**（review-full、test-check、deploy-check） | ~480-1,070 | そのトリガーフレーズが使われたときのみ |
| **Hooks**（すべて） | **ゼロ** | Claude のコンテキスト外で実行される |
| **agent**（スポーンごと） | フルコンテキストウィンドウ | 呼び出したときのみ |

**経済性：** hooks はトークンを消費せず、パススコープルールは対象ファイルに触れるまでコストがかかりません。繰り返し発生するベースラインは CLAUDE.md のみ（~2,300 トークン、典型的なセッションの約 3-5%）であり、やり直しを一度防ぐだけでそれをはるかに上回る節約になります。[コンポーネントごとの詳細な内訳と節約計算](../docs/BENCHMARKS.md#token-cost-per-component)をご覧ください。

---

## Who Is This For?

あらゆる開発者、あらゆるフレームワーク、あらゆるスキルレベル。

| あなたは | ここから始める | 価値実現までの時間 |
|---------|-----------|---------------|
| **完全な初心者** | [Start Here](../GETTING-STARTED.md#new-to-claude-code-start-here) | 1分：CLAUDE.md をコピーするだけ |
| **ソロ開発、小規模プロジェクト** | [CLAUDE.md](../CLAUDE.md) + 2 hooks | 5分 |
| **小規模スタートアップ（2-5 開発者）** | 上記 + 共有ルール + 2-3 agents | [Team Setup](../GETTING-STARTED.md#setting-up-for-teams) を参照 |
| **確立されたチーム（5 開発者以上）** | 完全なブループリント、適応版 | Fork、カスタマイズ、共有設定をコミット |
| **コーディング学習中** | [GETTING-STARTED.md](../GETTING-STARTED.md) のみ | 快適になるまで agents/skills/memory は無視 |
| **別のツールからの移行** | [CROSS-TOOL-GUIDE.md](../docs/CROSS-TOOL-GUIDE.md) | 概念は転用可能。*Copilot/Cursor in depth* セクションを参照 |

### Your Progression

**Level 1：CLAUDE.md をコピー（60秒）**
CLAUDE.md をプロジェクトにコピー。4つの行動ルール。即時効果。

**Level 2：2-3 個の hook を追加（5分）**
2-3 個の hook を追加。トークンコストゼロ。設定保護と編集検証の自動化。

**Level 3：フルブループリント（継続的）**
agents、skills、rules、memory をワークフローの成熟に合わせて追加。すぐにコピー可能な設定は [Presets](../docs/PRESETS.md) を参照。

---

## What Makes This Different

他のリポジトリは **何十もの agent** を大量に提供します。私たちは **11個** だけを提供し、それぞれが存在する理由を説明します。

| このブループリント | 汎用設定リポジトリ |
|---------------|---------------------|
| すべてのコンポーネントに[戦闘報告](../docs/WHY.md)があり、なぜ存在するのか説明 | コンテキストなしの設定 |
| AI コーディングミスを防ぐ[4つの行動ルール](../CLAUDE.md) | コピーする設定リスト |
| [クロスツールガイド](../docs/CROSS-TOOL-GUIDE.md)：Copilot、Cursor、Cline、Roo Code、OpenCode 他10ツール対応 | 単一ツールのみ |
| [初心者向け](../GETTING-STARTED.md)：6つの採用ペルソナ | 専門知識を前提 |
| [スモークテスト済み hook](../hooks/test-hooks.sh)：43個の自動テスト | テストなしのスクリプト |
| 安全性優先：[設定配置ガイド](../GETTING-STARTED.md#where-config-belongs-project-vs-personal)、プライバシー警告、[段階的劣化](../agents/README.md#agents-are-not-infallible) | 安全性ガイダンスなし |
| [フレームワーク非依存](../FAQ.md#what-framework-or-language-does-this-work-with)：あらゆる言語とスタックで動作 | 特定の言語/フレームワークを前提 |

---

## What's Inside

<details>
<summary><strong>11 Agents</strong>：モデル層別（opus/sonnet/haiku）の専用 sub-agent</summary>

&nbsp;

| Agent | Model | 役割 |
|-------|-------|------|
| project-architect | opus | システム設計、アーキテクチャ決定、技術選択 |
| backend-specialist | sonnet | API エンドポイント、サービス、データベース操作、ミドルウェア |
| frontend-specialist | sonnet | UI コンポーネント、状態管理、フォーム、スタイリング |
| code-reviewer | sonnet | コード品質、パターン、ベストプラクティス（読み取り専用） |
| security-reviewer | sonnet | OWASP Top 10、認証の脆弱性、インジェクション攻撃（読み取り専用） |
| db-analyst | sonnet | スキーマ分析、クエリ最適化、マイグレーション計画（読み取り専用） |
| devops-engineer | sonnet | デプロイ設定、CI/CD、Docker、インフラ（読み取り専用） |
| qa-tester | sonnet | ユニットテスト、統合テスト、E2E テスト |
| verify-plan | sonnet | 7点の機械的計画検証（読み取り専用） |
| docs-writer | haiku | README、API ドキュメント、チェンジログ、アーキテクチャドキュメント |
| architecture-reviewer | sonnet | 依存関係の方向、god ファイル、デッドコード、モジュール性（読み取り専用） |

詳細は [agents/README.md](../agents/README.md) のパーミッションモード、コスト推定、maxTurns を参照。

</details>

<details>
<summary><strong>17 Skills</strong>：自然言語トリガーのワークフロー（スラッシュコマンド不要）</summary>

&nbsp;

| カテゴリ | Skill | トリガー |
|----------|--------|----------|
| コード品質 | review-full、review-diff | "これはセキュアですか？"、"scan diff"、"脆弱性をチェック" |
| テスト | test-check、e2e-check | "テスト実行"、"ブラウザテスト"、"テストパスしてますか？" |
| デプロイ | deploy-check | "デプロイ"、"本番へプッシュ"、"リリース準備完了" |
| 計画 | sprint-plan、elicit-requirements | "ビルドしよう"、"新機能"、複数ステップのタスク |
| セッション | load-session、save-session、session-end、save-diary | セッション開始/終了、"保存"、"さようなら"、"完了" |
| プロジェクト | scaffold-project、register-project、status、changelog | "新規プロジェクト"、"ステータス"、"チェンジログ" |
| データベース | db-check | "スキーマをチェック"、"モデル検証" |
| ユーティリティ | tech-radar | "新機能は？"、"アップグレードすべき？" |

カスタマイズとプレースホルダ変数設定については [skills/README.md](../skills/README.md) を参照。

</details>

<details>
<summary><strong>12 Hooks</strong>：決定的なライフサイクル自動化（決定的に毎回発火、CLAUDE.md ルールは必ずしも守られない点と異なり）</summary>

&nbsp;

| イベント | Hook | 目的 |
|-------|------|---------|
| SessionStart | session-start.sh | ワークスペースコンテキストを注入 |
| InstructionsLoaded | instructions-loaded.sh | どのルールが、なぜロードされたかを記録 |
| PreToolUse (Bash) | block-git-push.sh | リモートリポジトリを保護 |
| PreToolUse (Bash) | pre-commit-secret-scan.sh | シークレットを含むコミットをブロック |
| PreToolUse (Write/Edit) | protect-config.sh | Linter/ビルド設定をガード |
| PostToolUse (Write/Edit) | notify-file-changed.sh | 検証リマインダー |
| PostToolUse (Bash) | post-commit-review.sh | コミット後レビュー |
| PreCompact | precompact-state.sh | 状態をディスクにシリアライズ |
| Stop | security check + cost-tracker.sh + session-checkpoint.sh | 最終防御 + メトリクス |
| SessionEnd | session-checkpoint.sh | 保証された最終保存 |

プラス2つのユーティリティスクリプト：`verify-mcp-sync.sh`（MCP 設定チェッカー）と`status-line.sh`（ブランチ/プロジェクトステータス）。どちらも full プリセットでデプロイされます。フォルダ内の13番目のファイルは `test-hooks.sh` で、ローカルテストハーネスとして `bash hooks/test-hooks.sh` で実行しすべての hook を検証します。これは `~/.claude/hooks/` にデプロイされない唯一のファイルであり、「12 hooks」の合計には含まれません。

すべての hook が動作することを確認するには `bash hooks/test-hooks.sh` を実行してください（43の自動テスト）。

詳細は [hooks/README.md](../hooks/README.md) のフルライフサイクル、テストガイド、デザイン原則を参照。

</details>

<details>
<summary><strong>6 Rules</strong>：パススコープの動作制約（マッチングファイル編集時のみロード）</summary>

&nbsp;

| Rule | アクティベーション | 目的 |
|------|-------------|---------|
| api-endpoints | `**/server/api/**/*.{js,ts}` | API ルート規約 |
| database-schema | `**/prisma/**`、`**/drizzle/**`、`**/migrations/**` | スキーマ設計パターン |
| testing | `**/*.test.*`、`**/*.spec.*` | テスト作成規約 |
| testing-general | `**/*.test.*`、`**/*.spec.*` | フレームワーク非依存のテスト規約（testing の補完） |
| session-lifecycle | 常に | セッション開始/終了の動作 |
| memory-session | `**/memory/**` | メモリリポジトリのセッション管理 |

カスタムルール作成については [rules/README.md](../rules/README.md) を参照。

</details>

**その他含まれるもの：**

| コンポーネント | 目的 |
|-----------|---------|
| [**CLAUDE.md**](../CLAUDE.md) | 本番環境で検証された行動ルールテンプレート |
| [**Settings Template**](../examples/settings-template.json) | Hook とパーミッション設定完全版 |
| [**Memory System**](../memory/) | 組み込みのオプトイン式：Claude が実行間で設定とセッションコンテキストを記憶（プライバシーのため git 無視） |

---

## Philosophy

1. **強制には hook、ガイダンスには CLAUDE.md を使う**：Hook は 100% の確率で発火します。CLAUDE.md の指示はほとんどの場合従われますが、保証はありません。モデルがルールを忘れたり、優先度を下げることがあります。何かが「必須」なら、hook にしましょう。

2. **エージェント単位のナレッジを持ち、グローバルな肥大化を避ける**：デザイン原則は frontend agent に置くべきであり、毎セッションのコンテキストに置くべきではありません。セキュリティパターンは security-reviewer に置くべきで、CLAUDE.md にはありません。

3. **コンテキストは通貨である**：コンテキストに読み込まれるすべてのトークンは、コードに使えないトークンです。MEMORY.md は 100 行以下に保ちましょう。topic ファイルに抽出します。パススコープルールを使って、無関係なルールがロードされないようにします。

4. **Hook は無料、コンテキストは安い**：12 個の hook スクリプトはトークンコストゼロです（Claude のコンテキスト外で実行されます）。CLAUDE.md はセッションあたり約 2,300 トークンを追加します。これは通常セッションの約 1-5% です。ブループリントはリトライサイクルの防止により、コスト以上のトークンを節約します。[BENCHMARKS.md](../docs/BENCHMARKS.md#token-cost-per-component) を参照してください。

5. **理論より実戦経験**：このリポジトリのすべてのルールは、それがなければ何か問題が起きたから存在します。「WHY」が「WHAT」より重要です。

---

## Getting Started

### Recommended adoption path

1. **[CLAUDE.md](../CLAUDE.md) から始める**：動作ルールのテンプレート。セットアップなしで最大の効果。
2. **2～3 個の hook を追加する**：[`protect-config.sh`](../hooks/protect-config.sh) + [`notify-file-changed.sh`](../hooks/notify-file-changed.sh) + [`cost-tracker.sh`](../hooks/cost-tracker.sh)。`~/.claude/hooks/` にコピーして [`settings.json`](../examples/settings-template.json) に接続します。
3. **[WHY.md](../docs/WHY.md) を読む**：理由を理解するためです。盲目的にコピーするのではなく、適応させます。
4. **ワークフロー成熟時に agent を追加する**：`verify-plan` と `code-reviewer` から始めます。
5. **[Memory system](../memory/) は `./setup.sh` 中の opt-in** です。Y と答えてセッション間で永続的なコンテキストを有効化します。

---

## Deep Dives

| | | |
|:--|:--|:--|
| **[Architecture](../docs/ARCHITECTURE.md)** | **[Settings Guide](../docs/SETTINGS-GUIDE.md)** | **[Battle Stories](../docs/WHY.md)** |
| システム設計、hook ライフサイクル、コンポーネント関係 | すべての環境変数、パーミッション、hook と根拠を説明 | すべてのコンポーネント背景にあるインシデントと教訓 |
| **[Benchmarks](../docs/BENCHMARKS.md)** | **[Presets](../docs/PRESETS.md)** | **[Cross-Tool Guide](../docs/CROSS-TOOL-GUIDE.md)** |
| トークン削減、コスト影響、品質メトリクス | ソロ、チーム、CI/CD 用のコピー可能設定 | Copilot、Cursor、Cline、Roo Code、OpenCode 他10ツール |
| **[FAQ](../FAQ.md)** | **[Getting Started](../GETTING-STARTED.md)** | **[Troubleshooting](../TROUBLESHOOTING.md)** |
| コミュニティからのよくある質問 | ゼロから生産的に 30 分で | 一般的な問題と解決策 |
| **[Setup Guide](../SETUP.md)** | **[Case Studies](../docs/CASE-STUDIES.md)** | **[Roadmap](../docs/ROADMAP.md)** |
| 自動インストーラー + 検証チェックリスト | 採用者のストーリーと before/after メトリクス | プロジェクトの方向性と今後の予定 |
| **[Self-Monitoring](../docs/SELF-MONITORING.md)** | | |
| オプションのパターン：gitleaks pre-commit + memory-curator agent | | |

---

## Common Questions

**フレームワーク対応？** はい。ブループリントはフレームワーク非依存です。Claude Code の動作を設定するものであり、スタックを問いません。[詳細...](../FAQ.md#what-framework-or-language-does-this-work-with)

**上級者向け？** いいえ。CLAUDE.md 1 ファイルから始めます。必要になったときだけ追加します。[詳細...](../FAQ.md#im-a-juniorintermediate-developer-is-this-for-me)

**どのプランが必要？** Pro、Max、Team、Enterprise、API すべて対応。Hook はすべてのプランで無料。[詳細...](../FAQ.md#which-claude-code-plan-do-i-need-does-this-work-with-pro--max--api)

**同僚から紹介された？** クイックスタートへ：[紹介された方向けガイド](../FAQ.md#a-colleague-sent-me-this-link-what-do-i-do-first)。

---

<details>
<summary><strong>Plugin Compatibility</strong></summary>

&nbsp;

このブループリントは**スタンドアロン設定**として設計されています。プラグインは不要です。実際、プラグインはカスタムセットアップに干渉することがあります：

**既知の問題：**
- **CLAUDE.md を修正するプラグイン** はカスタム動作ルールを上書きすることがあります
- **Hook を追加するプラグイン** は同じイベント（Stop、PreToolUse など）で積み重なる可能性があり、これは低下や競合指示を引き起こします
- **コンテキスト注入プラグイン** はコンテキストウィンドウからトークンを消費し、agents とメモリシステム用の領域が減ります
- **MCP サーバープラグイン** はこのセットアップと並行して機能します。ツールを追加するだけで、ルールを追加するわけではないため競合しません

**推奨事項：** このブループリントを導入する場合、インストール済みプラグインを監査して、以下を実行するプラグインを無効にしてください：
1. CLAUDE.md または settings.json hook をオーバーライド
2. SessionStart にプロンプト注入（セッションライフサイクルルールと競合）
3. パーミッション制限をバイパスする広範パーミッション追加

カスタムセットアップ > 汎用プラグイン。あなたのセットアップはあなたのプロジェクトのドメイン知識をエンコードしているからです。プラグインはあなたのアーキテクチャ、チームの慣例、プロダクション制約を知ることはできません。

</details>

---

## Acknowledgments

このブループリントのメモリシステムパターンは、Kiyoraka による [Project-AI-MemoryCore](https://github.com/Kiyoraka/Project-AI-MemoryCore) にインスパイアされました。LRU プロジェクト管理、メモリ統合、エコーリコール、その他を含む 11 個の機能拡張を備えた包括的な AI メモリアーキテクチャです。ここに含まれるリーンなビルトイン版よりも深く、より機能豊富なメモリシステムが必要なら、そのプロジェクトをチェックしてください。

**違いは何か：** このブループリントは*完全な Claude Code 設定*（agents、skills、hooks、rules、settings）をカバーし、ビルトイン opt-in のメモリを `memory/` に同梱しています。Project-AI-MemoryCore はメモリレイヤーに深く掘り下げたものであり、補完的であって競合しません。

## License

MIT
