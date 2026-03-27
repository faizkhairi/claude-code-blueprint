<div align="center">

# Claude Code Blueprint

**実際の開発で磨かれたリファレンスアーキテクチャ。プラグインではなく、学び、適応させるためのブループリント。**

[![Stars](https://img.shields.io/github/stars/faizkhairi/claude-code-blueprint?style=flat)](https://github.com/faizkhairi/claude-code-blueprint/stargazers)
[![Forks](https://img.shields.io/github/forks/faizkhairi/claude-code-blueprint?style=flat)](https://github.com/faizkhairi/claude-code-blueprint/network/members)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-2.1.85-blueviolet)](https://docs.anthropic.com/en/docs/claude-code)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**11 agents** · **17 skills** · **10 hooks** · **5 rules** -- すべて実戦で検証済み

[English](README.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [简体中文](README.zh.md)

<img src="assets/walkthrough.gif" alt="Claude Code Blueprint Walkthrough" width="680">

</div>

---

## Quick Start

ファイル1つをコピー。3つの行動ルールを取得。60秒で完了。

```bash
# プロジェクトルートで
curl -o CLAUDE.md https://raw.githubusercontent.com/faizkhairi/claude-code-blueprint/main/CLAUDE.md
```

このコマンドで Claude Code に3つのルールが追加され、AI コーディングの一般的なミスを防ぎます：

**Verify-After-Complete** · **Diagnose-First** · **Plan-Before-Execute**

もっと知りたいですか？ [採用パス（全体図）](#recommended-adoption-path)または[30分の初心者ガイド](GETTING-STARTED.md)を参照してください。

---

### Before You Start

> **重要：** これはプロジェクトテンプレートではなく、参照アーキテクチャです。このリポジトリ内で Claude Code を実行しないでください。ブループリント自体の CLAUDE.md を読み込んでしまい、プロジェクトのルールが無視されます。自分のプロジェクトにファイルをフォークするか、選び取ってください。
>
> 複数のファイルはプレースホルダ変数（`{MEMORYCORE_PATH}`、`{PROJECTS_ROOT}`）を含み、実際のパスに置き換える必要があります。Hook と設定はプロジェクトディレクトリではなく、**ユーザーレベル** の設定（`~/.claude/`）に配置すべきです。詳細は [GETTING-STARTED.md](GETTING-STARTED.md) を参照してください。

---

## What Makes This Different

他のリポジトリは **135個の agent** を提供します。私たちは **11個** だけを提供し、それぞれが存在する理由を説明します。

| このブループリント | 汎用設定リポジトリ |
|---------------|---------------------|
| すべてのコンポーネントに[戦闘報告](WHY.md)があり、なぜ存在するのか説明 | コンテキストなしの設定 |
| AI コーディングミスを防ぐ[3つの行動ルール](CLAUDE.md) | コピーする設定リスト |
| [クロスツールガイド](CROSS-TOOL-GUIDE.md) - Cursor、Codex、Gemini、Windsurf 対応 | 単一ツールのみ |
| [初心者向け](GETTING-STARTED.md) - 6つの採用ペルソナ | 専門知識を前提 |
| [スモークテスト済み hook](hooks/test-hooks.sh) - 35個の自動テスト | テストなしのスクリプト |
| セーフティ優先：[設定配置ガイド](GETTING-STARTED.md#where-config-belongs-project-vs-personal)、プライバシー警告、[段階的劣化](agents/README.md#agents-are-not-infallible) | セーフティガイダンスなし |

---

## What's Inside

<details>
<summary><strong>11 Agents</strong> -- モデル層別（opus/sonnet/haiku）の専用サブエージェント</summary>

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
| api-documenter | haiku | OpenAPI スペック、統合ガイド（読み取り専用） |

詳細は [agents/README.md](agents/README.md) のパーミッションモード、コスト推定、maxTurns を参照。

</details>

<details>
<summary><strong>17 Skills</strong> -- 自然言語トリガーのワークフロー（スラッシュコマンド不要）</summary>

&nbsp;

| カテゴリ | スキル | トリガー |
|----------|--------|----------|
| コード品質 | review、review-diff | "これはセキュアですか？"、"scan diff"、"脆弱性をチェック" |
| テスト | test-check、e2e-check | "テスト実行"、"ブラウザテスト"、"テストパスしてますか？" |
| デプロイ | deploy-check | "デプロイ"、"本番へプッシュ"、"リリース準備完了" |
| 計画 | sprint-plan、elicit-requirements | "ビルドしよう"、"新機能"、複数ステップのタスク |
| セッション | load-session、save-session、session-end、save-diary | セッション開始/終了、"保存"、"さようなら"、"完了" |
| プロジェクト | init-project、register-project、status、changelog | "新規プロジェクト"、"ステータス"、"チェンジログ" |
| データベース | db-check | "スキーマをチェック"、"モデル検証" |
| ユーティリティ | tech-radar | "新機能は？"、"アップグレードすべき？" |

カスタマイズとプレースホルダ変数設定については [skills/README.md](skills/README.md) を参照。

</details>

<details>
<summary><strong>10 Hooks</strong> -- 決定的なライフサイクル自動化（100%準拠、CLAUDE.md の~80%と異なり）</summary>

&nbsp;

| イベント | Hook | 目的 |
|-------|------|---------|
| SessionStart | session-start.sh | ワークスペースコンテキストを注入 |
| PreToolUse (Bash) | block-git-push.sh | リモートリポジトリを保護 |
| PreToolUse (Write/Edit) | protect-config.sh | Linter/ビルド設定をガード |
| PostToolUse (Write/Edit) | notify-file-changed.sh | 検証リマインダー |
| PostToolUse (Bash) | post-commit-review.sh | コミット後レビュー |
| PreCompact | precompact-state.sh | 状態をディスクにシリアライズ |
| Stop | security check + cost-tracker.sh | 最終防御 + メトリクス |
| SessionEnd | session-checkpoint.sh | 保証された最終保存 |

プラス2つのユーティリティスクリプト：`verify-mcp-sync.sh`（MCP 設定チェッカー）と`status-line.sh`（ブランチ/プロジェクトステータス）。

すべての hook が動作することを確認するには `bash hooks/test-hooks.sh` を実行してください（35の自動テスト）。

詳細は [hooks/README.md](hooks/README.md) のフルライフサイクル、テストガイド、デザイン原則を参照。

</details>

<details>
<summary><strong>5 Rules</strong> -- パススコープの動作制約（マッチングファイル編集時のみロード）</summary>

&nbsp;

| ルール | アクティベーション | 目的 |
|------|-------------|---------|
| api-endpoints | `**/server/api/**/*.{js,ts}` | API ルート規約 |
| database-schema | `**/prisma/**`、`**/drizzle/**`、`**/migrations/**` | スキーマ設計パターン |
| testing | `**/*.test.*`、`**/*.spec.*` | テスト作成規約 |
| session-lifecycle | 常に | セッション開始/終了の動作 |
| memorycore-session | `**/memory-core/**` | 外部メモリ統合 |

カスタムルール作成については [rules/README.md](rules/README.md) を参照。

</details>

**その他含まれるもの：**

| コンポーネント | 目的 |
|-----------|---------|
| [**CLAUDE.md**](CLAUDE.md) | 本番環境で検証された行動ルールテンプレート |
| [**Settings Template**](examples/settings-template.json) | Hook とパーミッション設定完全版 |
| [**Memory System**](memory-template/) | デュアル：自動メモリ + 外部 git ベース永続化 |

---

## Philosophy

1. **強制には hook、ガイダンスには CLAUDE.md** -- Hook は 100% の確率で発火します。CLAUDE.md の指示は約 80% の確率で従われます。何かが「必須」なら、hook にしましょう。

2. **エージェントスコープのナレッジ、グローバルブロートではなく** -- デザイン原則は frontend agent に住むべきであり、毎セッション読み込むべきではありません。セキュリティパターンは security-reviewer に住むべきで、CLAUDE.md にはありません。

3. **コンテキストは通貨** -- コンテキストに読み込まれるすべてのトークンは、コードに使えないトークンです。MEMORY.md は 100 行以下に保ちましょう。topic ファイルに抽出します。パススコープルールを使って、無関係なルールがロードされないようにします。

4. **Hook は無料、コンテキストは安い** -- 10 個の hook スクリプトはトークンコストゼロです（Claude のコンテキスト外で実行されます）。CLAUDE.md はセッションあたり約 2,300 トークンを追加します -- 通常セッションの約 1-5% です。ブループリントはリトライサイクルの防止により、コスト以上のトークンを節約します。[BENCHMARKS.md](BENCHMARKS.md#token-cost-per-component) を参照してください。

5. **理論より実戦経験** -- このリポジトリのすべてのルールは、それがなければ何か問題が起きたから存在します。「WHY」が「WHAT」より重要です。

---

## Getting Started

### Who is this for?

| あなたは | ここから始める | 導入 |
|---------|-----------|-------|
| **完全な初心者** | [Start Here](GETTING-STARTED.md#new-to-claude-code-start-here) | 1分セットアップ：CLAUDE.md をコピーするだけ |
| **ソロ開発、小規模プロジェクト** | [CLAUDE.md](CLAUDE.md) + 2 hooks | これで十分。過度に設計しません。 |
| **小規模スタートアップ（2-5 開発者）** | 上記 + 共有ルール + 2-3 agents | [Team Setup](GETTING-STARTED.md#setting-up-for-teams) を参照 |
| **確立されたチーム（5 開発者以上）** | 完全なブループリント、適応版 | Fork、カスタマイズ、共有設定をコミット |
| **コーディング学習中** | [GETTING-STARTED.md](GETTING-STARTED.md) のみ | 快適になるまで agents/skills/memory は無視 |
| **別のツールからの移行** | [CROSS-TOOL-GUIDE.md](CROSS-TOOL-GUIDE.md) | 概念は転用可能。必要なものを適応させます |

### Option A: Fork（推奨）
このリポジトリを fork してあなた自身のリビングリファレンスにカスタマイズします。後でブループリントが進化したらアップストリーム更新をプルできます。

### Option B: Clone + Copy
リポジトリをクローンしてから、コンポーネントを選んで `~/.claude/` ディレクトリにコピーします。

### Option C: Cherry-pick
GitHub でリポジトリを見て、必要な特定のファイルだけをコピーします。インストール不要です。

### Recommended adoption path

1. **[CLAUDE.md](CLAUDE.md) から始める** -- 動作ルールのテンプレート。セットアップなしで最大の効果。
2. **2～3 個の hook を追加する** -- [`protect-config.sh`](hooks/protect-config.sh) + [`notify-file-changed.sh`](hooks/notify-file-changed.sh) + [`cost-tracker.sh`](hooks/cost-tracker.sh)。`~/.claude/hooks/` にコピーして [`settings.json`](examples/settings-template.json) に接続します。
3. **[WHY.md](WHY.md) を読む** 理由を理解するため -- 盲目的にコピーするのではなく、適応させます。
4. **ワークフロー成熟時に agent を追加** -- `verify-plan` と `code-reviewer` から始めます。
5. **クロスセッション永続化が必要なら [memory system](memory-template/) をセットアップ** します。

---

## Deep Dives

| | | |
|:--|:--|:--|
| **[Architecture](ARCHITECTURE.md)** | **[Settings Guide](SETTINGS-GUIDE.md)** | **[Battle Stories](WHY.md)** |
| システム設計、hook ライフサイクル、コンポーネント関係 | すべての環境変数、パーミッション、hook と根拠を説明 | すべてのコンポーネント背景にあるインシデントと教訓 |
| **[Benchmarks](BENCHMARKS.md)** | **[Presets](PRESETS.md)** | **[Cross-Tool Guide](CROSS-TOOL-GUIDE.md)** |
| トークン削減、コスト影響、品質メトリクス | ソロ、チーム、CI/CD 用のコピー可能設定 | Cursor、Codex CLI、Gemini CLI、Windsurf |

---

## Troubleshooting

Hook が発火しない、エージェント失敗、MCP クラッシュ、コスト誤算、Windows 固有の問題など、一般的な問題への解決策については [TROUBLESHOOTING.md](TROUBLESHOOTING.md) を参照してください。

---

<details>
<summary><strong>Plugin Compatibility</strong></summary>

&nbsp;

このブループリントは**スタンドアロン設定**として設計されています -- プラグイン不要です。実際、プラグインはカスタムセットアップに干渉することがあります：

**既知の問題：**
- **CLAUDE.md を修正するプラグイン** はカスタム動作ルールを上書きすることがあります
- **Hook を追加するプラグイン** は同じイベント（Stop、PreToolUse など）で積み重なる可能性があります -- これは低下や競合指示を引き起こします
- **コンテキスト注入プラグイン** はコンテキストウィンドウからトークンを消費し、agents とメモリシステム用の領域が減ります
- **MCP サーバープラグイン** このセットアップと並行して機能します -- ツールを追加するだけで、ルール追加なので競合しません

**推奨事項：** このブループリントを導入する場合、インストール済みプラグインを監査して、以下を実行するプラグインを無効にしてください：
1. CLAUDE.md または settings.json hook をオーバーライド
2. SessionStart にプロンプト注入（セッションライフサイクルルールと競合）
3. パーミッション制限をバイパスする広範パーミッション追加

カスタムセットアップ > 汎用プラグイン。あなたのセットアップはあなたのプロジェクトのドメイン知識をエンコードしているから。プラグインはあなたのアーキテクチャ、チームの慣例、プロダクション制約を知ることはできません。

</details>

---

## Acknowledgments

このブループリントのメモリシステムパターンは、Kiyoraka による [Project-AI-MemoryCore](https://github.com/Kiyoraka/Project-AI-MemoryCore) にインスパイアされました。LRU プロジェクト管理、メモリ統合、エコーリコール、その他を含む 11 個の機能拡張を備えた包括的な AI メモリアーキテクチャです。ここに含まれるミニマルスキャフォルドより深く、より機能豊富なメモリシステムが必要なら、そのプロジェクトをチェックしてください。

**違いは何か：** このブループリントは*完全な Claude Code 設定*（agents、skills、hooks、rules、settings）をカバーします。ここの `memory-template/` はライトウェイトスキャフォルドです。Project-AI-MemoryCore はメモリレイヤーに深く掘り下げています。補完的ですが、競合しません。

## License

MIT
