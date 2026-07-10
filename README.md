# Night Factory Defence(仮題・改名予定)

1〜4人のクルーが、走り続ける小型車両の中を動き回り、車両を改装しながら
ゾンビと怪物のWaveを耐え、分岐する終末世界を走破する**協力ローグライト**。

Godot 4.7で開発中。仕様の全体像は [docs/13_godot-redevelopment-spec.md](docs/13_godot-redevelopment-spec.md) を参照。

## 🎮 今すぐ遊ぶ(インストール不要・ブラウザで開くだけ)

**▶ https://gengenz719-lab.github.io/night-factory-defence/godot-play/**

現在はソロのテストプレイ版です(車内移動・射撃・敵3種・修理・2Wave・レリック3択)。

### ローカルで遊ぶ・開発する場合

```text
godot/PLAY_TEST.bat をダブルクリック。
(Godot 4.7 stable を .tools/godot-4.7/ に配置しておく。本体はGit管理外)
```

### 操作方法

| 操作 | キー |
|---|---|
| 左右移動 | A / D、左右キー |
| ジャンプ / はしごを上る | Space(はしご付近はW) |
| はしごを下りる | S |
| 照準・射撃 | マウス・左クリック |
| 修理 | 下階中央の緑色端末付近でE長押し |
| 準備短縮 / Wave短縮(テスト用) | F1 / F2 |
| リザルトから再開 | R |

## プロジェクト構成

```text
godot/       … 開発の主戦場(Godot 4.7・型付きGDScript)
godot-play/  … GitHub Pagesで配信するGodot Web書き出し
docs/        … 仕様・バランス・ロードマップ(13以降が現行)
docs/archive/… 旧・工場防衛版のドキュメント(凍結)
unity/       … 旧Unity版(凍結・参考実装)
prototype/   … 旧HTML5プロトタイプ(凍結・参考実装)
play/        … 旧Unity WebGL版の配信物(凍結)
CLAUDE.md    … AI(Claude Code / Cursor等)向けの開発ルール
```

## はじめて参加する人へ

[docs/05_team-onboarding.md](docs/05_team-onboarding.md) を読んでください。
プログラミング未経験でもAIと一緒に開発クエストをこなせる座組みになっています。

## ドキュメント一覧

### 現行(Godot版・移動車両サバイバル)

| ファイル | 内容 |
|---|---|
| [docs/13_godot-redevelopment-spec.md](docs/13_godot-redevelopment-spec.md) | マスターゲーム仕様(§0=ゲームの憲法) |
| [docs/14_godot-technical-spec.md](docs/14_godot-technical-spec.md) | 技術仕様(構成・命名・ネットワーク・データ) |
| [docs/15_preproduction-review.md](docs/15_preproduction-review.md) | 決定事項D-01〜D-10と変更ルール |
| [docs/16_combat-vehicle-balance.md](docs/16_combat-vehicle-balance.md) | Wave・敵・武器・車両のバランス数値 |
| [docs/17_progression-catalog.md](docs/17_progression-catalog.md) | レリック24種・個人スキル48種 |
| [docs/18_route-ui-acceptance.md](docs/18_route-ui-acceptance.md) | ルートマップ・HUD・受け入れテスト |
| [docs/19_spec-completion-audit.md](docs/19_spec-completion-audit.md) | 仕様完成監査 |
| [docs/20_godot-roadmap.md](docs/20_godot-roadmap.md) | ロードマップ・週次クエスト・未決定事項 |

### 共通(参加・運用ガイド)

| ファイル | 内容 |
|---|---|
| [docs/05_team-onboarding.md](docs/05_team-onboarding.md) | パートナー向け参加ガイド |
| [docs/06_ai-collab-guide.md](docs/06_ai-collab-guide.md) | AIバイブコーディングの回し方 |
| [docs/07_ideas.md](docs/07_ideas.md) | アイデア置き場 |
| [docs/08_github-guide.md](docs/08_github-guide.md) | GitHub参加ガイド(クローン・作業フロー) |
| [docs/09_discord-setup.md](docs/09_discord-setup.md) | Discord開発サーバーの設計図 |

### 旧・工場防衛版(凍結)

[docs/archive/](docs/archive/README.md) に保管。旧Unity WebGL版は
[こちら](https://gengenz719-lab.github.io/night-factory-defence/play/)、
旧HTML5プロトタイプは [こちら](https://gengenz719-lab.github.io/night-factory-defence/prototype/) で今も遊べます。
