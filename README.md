# Night Factory Defence

2〜4人で拠点を作り、昼に小さな生産ラインを組み、夜にゾンビウェーブを防衛する軽量ローグライト工場ゲーム。

## 🎮 今すぐ遊ぶ(インストール不要・ブラウザで開くだけ)

**▶ https://gengenz719-lab.github.io/night-factory-defence/**

このリンクを開くだけでUnity WebGL版を遊べます。GitHubアカウントもダウンロードも不要。パートナーにはこのリンクを渡してください。

### ローカルで遊ぶ場合

```text
Unity Editorで unity/Assets/_Project/Scenes/PlayableSlice.unity を開いて Play。
```

WebGLビルド済みファイルをローカルで確認する場合:

```powershell
npx serve .
```

### 操作方法

| 操作 | キー |
|---|---|
| 移動 | WASD / 矢印キー |
| 射撃 | マウス左クリック(長押し可) |
| Wave開始 | Space |
| リスタート | R |

### ゲームの流れ

```text
昼(45秒): 鉄を掘る施設・弾薬工場・タレット・壁を建てる
夜: ゾンビの群れが拠点コアを狙って襲来。撃って守る
Waveクリア: 3択レリックで強化
10 Wave 生存で勝利。コアが壊れたら敗北
```

## プロジェクト構成

```text
play/        … GitHub Pagesで配信するUnity WebGLテストプレイ版
unity/       … Unityプロジェクト
prototype/   … 旧HTML5プロトタイプ
docs/        … 企画・仕様・ルール・アイデア置き場
CLAUDE.md    … AI(Claude Code / Cursor等)向けの開発ルール
```

## はじめて参加する人へ

[docs/05_team-onboarding.md](docs/05_team-onboarding.md) を読んでください。
プログラミング未経験でもAIと一緒に開発クエストをこなせる座組みになっています。

## ドキュメント一覧

| ファイル | 内容 |
|---|---|
| [docs/00_game-constitution.md](docs/00_game-constitution.md) | ゲームの憲法(絶対にブレさせない方針) |
| [docs/01_prototype-spec.md](docs/01_prototype-spec.md) | プロトタイプ仕様と実装状況 |
| [docs/02_not-todo.md](docs/02_not-todo.md) | やらないことリスト |
| [docs/03_roadmap.md](docs/03_roadmap.md) | 開発ロードマップと週次クエスト |
| [docs/04_engine-decision.md](docs/04_engine-decision.md) | 技術選定の理由とエンジン移行計画 |
| [docs/05_team-onboarding.md](docs/05_team-onboarding.md) | パートナー向け参加ガイド |
| [docs/06_ai-collab-guide.md](docs/06_ai-collab-guide.md) | AIバイブコーディングの回し方 |
| [docs/07_ideas.md](docs/07_ideas.md) | レリック案・敵案のストック |
| [docs/08_github-guide.md](docs/08_github-guide.md) | GitHub参加ガイド(クローン・作業フロー) |
| [docs/09_discord-setup.md](docs/09_discord-setup.md) | Discord開発サーバーの設計図 |
| [docs/10_unity-migration.md](docs/10_unity-migration.md) | Unity移植の準備・計画 |
| [docs/11_unity-milestones.md](docs/11_unity-milestones.md) | Unity版のマイルストーンとタスク分解 |
