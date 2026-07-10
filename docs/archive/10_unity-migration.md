> **📦 アーカイブ(旧・工場防衛版)** — 本書は旧ゲーム「トップダウン工場防衛」時代のドキュメントです。
> 現行はGodot版「移動車両型・協力Waveサバイバル」であり、[13_godot-redevelopment-spec.md](../13_godot-redevelopment-spec.md) 以降が正です。(アーカイブ日: 2026-07-11)

# Unity 移植 準備・計画

HTML5プロトタイプ(`prototype/`)を「仕様書兼リファレンス実装」として、Unityで作り直すための計画。
関連: [04_engine-decision.md](04_engine-decision.md)(なぜUnityか)。

## 0. 大前提

- **プロトタイプはまだ捨てない。** 面白さの検証と数値調整はHTML5で続ける
- Unity版は**プロトタイプを見ながら作り直す**(コードの1対1移植はしない)
- プロトタイプが「データ(config.js)」と「ロジック」と「描画(ui.js)」を分離してあるので、移植は素直に進む

## 1. いつ移植を始めるか(判断基準)

以下が揃ったら本格移植を開始:

```text
□ 2人以上で遊んで「もう1回」と言われる
□ レリック15個以上でビルドの多様性が確認できた
□ ベルトコンベアを入れる/入れないの結論が出た
```

それまでは「道具の準備」と「小さな縦スライス試作」まで。

## 2. 必要な道具(セットアップ対象)

| 道具 | 用途 | 備考 |
|---|---|---|
| Unity Hub | Unityのバージョン管理・起動 | 無料 |
| Unity 6 (6000.x LTS) | エンジン本体 | 2D URP か 2D(Built-in)テンプレート |
| Python 3.10+ | Unity MCP の動作に必要 | 現状この環境は未インストール |
| Unity MCP | Claude Codeからエディタを操作 | [CoplayDev/unity-mcp](https://github.com/CoplayDev/unity-mcp)(無料)など |
| Git LFS | Unityの画像・音声など大容量ファイル管理 | 既存のGitHubリポジトリをそのまま使う |

> Unity MCP を入れると、Claude Code から「GameObject作成 / スクリプト生成・アタッチ / コンソールのエラー読取・修正 / Play mode実行」ができる。これがUnityでもAIバイブコーディングを成立させる要。

## 3. リポジトリ構成(既存リポジトリに同居させる)

新しいリポジトリは作らず、**既存リポジトリにUnityプロジェクト用フォルダを足す**。
こうすると Discordの #リポジトリ更新 通知もそのまま効く。

```text
night-factory-defence/
  prototype/     … HTML5リファレンス実装(残す)
  unity/         … ここにUnityプロジェクトを新規作成
  docs/
```

- `unity/` 用の Unity向け `.gitignore` と Git LFS 設定(`.gitattributes`)を置く
- Library/ Temp/ などUnityの生成物はコミットしない(.gitignoreで除外)

## 4. Unity内のフォルダ構成(開発メモ準拠)

```text
unity/Assets/
  _Project/
    Scenes/        Main/ , Tests/
    Scripts/       Player/ Enemies/ Waves/ Building/ Factory/ Combat/ Relics/ UI/ (後で)Multiplayer/
    Prefabs/       Player/ Enemies/ Buildings/ Projectiles/ UI/
    ScriptableObjects/  EnemyData/ BuildingData/ RelicData/ WaveData/
    Art/  Audio/
```

自作物は `_Project/` にまとめ、アセットストア素材と混ざらないようにする。

## 5. プロトタイプ → Unity の対応表(設計の地図)

| プロトタイプ | Unityでの形 | メモ |
|---|---|---|
| `config.js`(全バランス数値) | **ScriptableObject**: EnemyData / BuildingData / RelicData / WaveConfig | ここが最大の勝ち筋。既にデータ分離済みなので素直にSO化できる |
| `state.js`(ゲーム状態) | `GameManager` / `GameState`(単一責任) | 後のマルチを見据え「サーバー権威」で持てる形に |
| `enemies.js` | `Enemy`(MonoBehaviour)+ `EnemySpawner`(WaveConfigを読む) | 敵コスト制の予算編成ロジックはそのまま移植 |
| `buildings.js` | グリッド系 + `Building` 派生(Wall/Turret/Miner/Smelter) | タイル→ワールド座標の変換を共通化 |
| `combat.js` | 弾の**オブジェクトプール** + ダメージ処理 | 弾は生成/破棄が多いのでプール推奨 |
| `relics.js` | `RelicManager`(RelicDataの効果=modsを適用) | 効果は「データ+適用関数」の形を維持 |
| `waves.js` | `WaveManager`(昼夜フェーズ・Wave進行) | |
| `ui.js` | uGUI もしくは UI Toolkit の HUD | 状態を読むだけ・状態は変えない分離を維持 |
| `utils.js` | 静的ヘルパークラス | |

## 6. 移植の順番(縦スライスで動くものを保つ)

```text
第1歩(縦スライス): プロジェクト作成 → プレイヤー移動 + カメラ + コア + 敵1種 + Waveスポーン
第2歩: 射撃 + 敵撃破 + コアダメージ + ゲームオーバー
第3歩: 建設(グリッド/壁/タレット)+ 資源
第4歩: 工場(採掘機/加工炉)+ 弾薬経済
第5歩: 昼夜ループ + Wave予算 + 10Wave
第6歩: レリック(ScriptableObject)+ Wave後3択
第7歩: 仕上げ(HUD/タイトル/リザルト)
--- ここまでで「プロトタイプ相当のUnity版」完成 ---
第8歩: マルチプレイ(Netcode for GameObjects、サーバー権威)
第9歩: Steam連携(Steamworks / Facepunch.Steamworks)
```

各段階で「常に遊べる状態」を維持する(プロトタイプ開発と同じ原則)。

## 7. マルチプレイの下準備(今から意識)

- `GameManager`/状態を**サーバー権威**前提で設計(シングルでもホストが真実を持つ形)
- 敵・弾・建物の生成は「サーバーが決めてクライアントに同期」できる構造に
- Netcode for GameObjects を採用予定。最初はローカル2人 → のちにオンライン

## 8. バージョン管理ルール(Unityで最重要)

Sceneとprefabの同時編集が最大の事故要因。最初に決める:

```text
1. Main Scene は同時に触らない(担当を1人に)
2. 機能ごとに Test_*.unity を分けて各自そこで作業
3. Prefabは担当者を決める
4. 作業前に必ず git pull、作業後に何を変えたか #できた報告 に書く
5. 画像・音声・モデルは Git LFS 管理
```

> 競合が頻発するようなら Unity Version Control(Smart Locks)への切替も検討。まずは Git + LFS + 上記ルールで始める。

## 9. 準備フェーズの具体タスク(移植本番の前にやれること)

```text
□ Unity Hub + Unity 6 LTS をインストール
□ Python 3.10+ をインストール(Unity MCP用)
□ 空のUnityプロジェクトを unity/ に作成(2Dテンプレート)
□ Unity用 .gitignore と .gitattributes(Git LFS)を設置
□ Unity MCP を導入し、Claude Codeから接続確認
□ 第1歩の縦スライスをMCP経由で試作(移植の感触を掴む)
```
