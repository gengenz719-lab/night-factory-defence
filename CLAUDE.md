# AI開発ルール(Claude Code / Cursor / Copilot 共通)

このプロジェクトは「協力型ゾンビ防衛ローグライト工場ゲーム」です。
現在は `prototype/` のHTML5プロトタイプを開発中。素のJavaScript + Canvas 2D、ビルドツールなし。

## 最初に読むもの

- docs/00_game-constitution.md … ゲームの方向性(これに反する提案はしない)
- docs/01_prototype-spec.md … 現在の仕様
- docs/02_not-todo.md … やらないことリスト(ここにある機能は実装しない)

## コーディング方針

- 初心者にも読めるJavaScriptを書く。コメントは日本語で多めに
- 1ファイル1責任。巨大な一枚コードにしない
- 数値バランス(HP・コスト・速度など)は必ず `js/config.js` に置く。ロジック内に直書きしない
- 外部ライブラリ・npmパッケージ・ビルドツールを勝手に追加しない(index.htmlをダブルクリックで動く状態を守る)
- 将来のマルチプレイ化を考慮し、「ゲーム状態(state.js)」と「描画(ui.js)」を混ぜない
- 未説明の高度な設計パターンを使わない。既存コードの書き方に合わせる

## prototype/js のファイル責任分担

| ファイル | 責任 |
|---|---|
| config.js | 全バランス数値・敵/建物/レリック定義(データのみ) |
| state.js | ゲーム状態の定義と初期化 |
| utils.js | 汎用関数(距離計算・乱数など) |
| input.js | キーボード・マウス入力 |
| player.js | プレイヤーの移動・射撃・被弾 |
| enemies.js | 敵AI・Wave予算からの敵編成生成 |
| buildings.js | グリッド・建設・工場の生産処理 |
| combat.js | 弾丸・当たり判定・ダメージ |
| relics.js | レリック効果の適用 |
| waves.js | 昼夜フェーズ・Wave進行の管理 |
| ui.js | HUD描画・メニューDOM操作 |
| main.js | ゲームループ・初期化 |

## 作業の進め方

- 変更は小さく。1回の作業で1機能
- 機能を追加・変更したら docs/01_prototype-spec.md の実装状況表を更新する
- バランス調整の意図は docs/01_prototype-spec.md の設計メモに残す
- 動かない状態でコミットしない
