# AI開発ルール(Claude Code / Cursor / Copilot 共通)

このプロジェクトは「移動車両型・協力Waveサバイバル」ローグライトです。
1〜4人のクルーが、走り続ける小型車両の中を動き回り、車両を改装しながらゾンビWaveを耐えます。

**開発の主戦場は `godot/`(Godot 4.7 stable・型付きGDScript)。**
`prototype/`(旧HTML5工場防衛)と `unity/`(旧Unity版)は凍結済みの参考実装で、**変更しない**。

## 最初に読むもの

- docs/13_godot-redevelopment-spec.md … マスターゲーム仕様(§0がゲームの憲法。これに反する提案はしない)
- docs/14_godot-technical-spec.md … 技術仕様(フォルダ構成・命名・ネットワーク・データ構造・「未導入を固定する技術」)
- docs/15_preproduction-review.md … 決定事項D-01〜D-10と変更ルール
- docs/16〜18 … バランス数値・成長カタログ・HUD/受け入れ条件
- docs/20_godot-roadmap.md … 現在のロードマップと次の一手

旧ゲーム(工場防衛)のドキュメントは docs/archive/ にある。参照はよいが更新しない。

## コーディング方針

- **型付きGDScript**に統一(C#と混在させない)。型注釈を省略しない
- 初心者にも読めるコードを書く。コメントは日本語で多めに
- 1ファイル1責務。巨大なRunManagerに処理を集約しない
- **バランス数値(HP・コスト・速度・時間など)はロジックに直書きしない。** データ定義(カスタムResource `.tres`、当面はデータ専用の定数群)に置く
- 命名は docs/14 §3 に従う: ファイル/変数/関数=snake_case、クラス/Node=PascalCase、定数=UPPER_SNAKE_CASE、Resource ID=`カテゴリ_内容`
- フォルダ構成は docs/14 §2 を目標形とする(assets/ data/ scenes/ scripts/ tests/)
- Autoloadは AppState / GameCatalog / NetworkSession / SaveService / AudioService の5つまで。**ラン固有状態をAutoloadに置かない**
- **マルチプレイ前提で書く**: クライアントは「意図」を送り、結果はホストが確定する(docs/14 §6〜7)。ゲームルールの乱数と見た目の乱数を分離する(docs/14 §9)
- docs/14 §19「未導入を固定する技術」(ECS・外部DI・独自プロトコル等)を勝手に導入しない
- 未説明の高度な設計パターンを使わない。既存コードの書き方に合わせる

## 動作確認

- ローカル実行: `godot/PLAY_TEST.bat`(Godot 4.7本体はGit管理外の `.tools/godot-4.7/` に配置)
- スモークテスト(コミット前に通すこと):

```powershell
# godot/ ディレクトリで実行。成功時は SMOKE_TEST_PASS を出力
..\.tools\godot-4.7\Godot_v4.7-stable_win64_console.exe --headless --path . -- --smoke-test
```

## アート

- Godot版のアートは新規制作のみ。Unity版素材を流用しない
- 生成AI利用時は制作方法・元シートを `godot/assets/art/README.md` に記録する(Steam申請時のAI開示に使う)
- アート基準は docs/art/godot-art-direction-v1.png と docs/godot-gameplay-concept-v1.png

## 作業の進め方

- 変更は小さく。1回の作業で1機能
- ゲームルールに関わる変更は docs/13〜18 の該当箇所を更新する。D-01〜D-10を変える場合は docs/15 に理由と影響範囲を記録する
- バランス調整の意図は docs/16_combat-vehicle-balance.md の該当表・メモに残す
- スモークテストが通らない状態でコミットしない
