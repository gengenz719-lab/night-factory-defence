# Godot再開発 技術仕様 v0.1

> ゲームルールは [13_godot-redevelopment-spec.md](13_godot-redevelopment-spec.md) を正とする。
> 本書は実装を開始する前の技術的な固定事項を定める。

## 1. 採用技術

| 項目 | 決定 |
|---|---|
| エンジン | Godot 4.7 stable |
| 言語 | 型付きGDScript |
| 描画 | 2D / Compatibility rendererを初期値 |
| 物理 | Godot Physics 2D |
| ネットワーク | MultiplayerAPI + ENetMultiplayerPeer |
| トポロジ | プレイヤーホスト型、最大4接続 |
| データ | カスタムResource (`.tres`) |
| セーブ | バージョン付きJSON、ローカル保存 |
| 対象OS | Windows 10/11を初期対象 |
| 入力 | キーボード/マウス、XInput系ゲームパッド |
| 配信統合 | 技術検証はENet直結、Steam統合はフルラン・アルファ前 |

### 選定理由

- 2026-07-10時点でGodot 4.7が最新stable。4.7.1 RCや4.8 devは採用しない。
- Godotの高レベルマルチプレイはENet実装を標準で持ち、ホスト/クライアント検証を外部SDKなしで始められる。
- Resourceはシリアライズ可能なデータコンテナで、旧Unity版のScriptableObjectと同じ役割へ移しやすい。
- 型付きGDScriptに統一し、GDScriptとC#の混在を避ける。

### 公式資料

- [Godot公式リリースアーカイブ](https://godotengine.org/download/archive/)
- [High-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
- [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html)

## 2. リポジトリ配置

既存版を削除せず、Godot版を新しいルートに置く。

```text
night-factory-defence/
├─ godot/                  # 新しいGodotプロジェクト
│  ├─ project.godot
│  ├─ assets/
│  │  ├─ audio/
│  │  ├─ fonts/
│  │  ├─ sprites/
│  │  ├─ shaders/
│  │  └─ themes/
│  ├─ data/
│  │  ├─ characters/
│  │  ├─ enemies/
│  │  ├─ modules/
│  │  ├─ relics/
│  │  ├─ skills/
│  │  ├─ stages/
│  │  └─ weapons/
│  ├─ scenes/
│  │  ├─ app/
│  │  ├─ game/
│  │  ├─ actors/
│  │  ├─ vehicle/
│  │  ├─ ui/
│  │  └─ tests/
│  ├─ scripts/
│  │  ├─ autoload/
│  │  ├─ data/
│  │  ├─ game/
│  │  ├─ net/
│  │  ├─ ui/
│  │  └─ utils/
│  └─ tests/
├─ unity/                  # 旧参考実装、変更しない
├─ prototype/              # 旧HTML5参考実装、変更しない
└─ docs/
```

## 3. 命名規則

- ファイルとフォルダ: `snake_case`
- GDScriptクラス: `PascalCase`
- 変数、関数、signal: `snake_case`
- 定数: `UPPER_SNAKE_CASE`
- Resource ID: `カテゴリ_内容`のASCII小文字。例 `enemy_walker`, `relic_rapid_fire`。
- Node名: `PascalCase`。RPC対象ノードは全端末で同じNodePathになる名前を固定する。
- private用途は先頭 `_`。型注釈を省略しない。
- 1ファイル1責務。1つの巨大なRunManagerへ処理を集約しない。

## 4. Autoload

Autoloadは次の5つまでを初期上限とする。

| 名前 | 責務 |
|---|---|
| AppState | 画面遷移、起動状態 |
| GameCatalog | ResourceのID検索と検証 |
| NetworkSession | 接続、切断、peer管理 |
| SaveService | 設定、メタ進行、中断データ |
| AudioService | BGM、SE、音量バス |

- Wave進行、敵、車両、投票などラン固有状態をAutoloadに置かない。
- ラン固有状態はRunシーンの子ノードが所有し、終了時に破棄する。

## 5. 主要責務

| クラス/ノード | 責務 |
|---|---|
| RunCoordinator | ラン状態機械と各システムの調停 |
| StageDirector | Wave時間、危険イベント、離脱 |
| EnemyDirector | 脅威予算、スポーン要求 |
| VehicleState | 車体、外装、電力、共有資源 |
| VehicleGrid | 配置可否とレイアウト |
| ModuleSystem | モジュール稼働、故障、修理 |
| RewardSystem | 戦果、レリック候補、再抽選 |
| RouteGenerator | シード付きDAG生成 |
| VoteController | ルート/レリック投票 |
| PlayerAvatar | 入力結果、移動、戦闘、ダウン |
| NetStateReplicator | スナップショットとイベント同期 |

## 6. 状態の所有権

### ホストだけが変更できる状態

- Wave開始・終了と残り時間
- 敵の生成、AI上の確定位置、HP、死亡
- プレイヤーと車両へのダメージ
- 車体、外装、モジュールHP
- 共有資源
- レリック候補と取得結果
- ルートマップと投票結果
- 乱数シードと中断データ

### クライアントが要求できる操作

- 移動入力、照準、射撃、回避
- インタラクト開始・終了
- 修理、蘇生、設備操作
- モジュール配置案
- レリック、ルート投票
- 準備完了

クライアントは結果値を送らず「意図」を送る。ホストが距離、クールダウン、コスト、権限を検証する。

## 7. RPC方針

- 入力: `any_peer`, unreliable ordered、専用channel 1。
- 状態スナップショット: authority, unreliable ordered、channel 2。
- 射撃/命中など短命イベント: authority, unreliable ordered、channel 3。
- 画面遷移、投票確定、車両改装、報酬: authority/reliable、channel 0。
- 接続時の初期状態: authority/reliable、channel 0。
- RPC関数をResourceへ定義せず、Nodeに置く。
- RPCペイロードへNodeやResourceそのものを渡さず、IDとプリミティブ値を渡す。

## 8. 更新頻度の初期値

| 対象 | 頻度 |
|---|---:|
| 物理シミュレーション | 60Hz |
| ローカルプレイヤー入力送信 | 30Hz |
| プレイヤー状態スナップショット | 20Hz |
| 主要敵スナップショット | 12Hz |
| 車両HP・資源 | 値変更時 + 2Hz保険 |
| Wave時計 | 開始時刻同期 + 1Hz補正 |

- 補間表示は100msを初期バッファとする。
- 150ms RTT、パケット損失2%でも射撃と移動が継続できることを通信スパイクの合格条件にする。

## 9. 乱数

- ラン開始時に64bitのrun seedをホストが発行する。
- `route`, `wave`, `reward`, `event`の独立ストリームへ派生させる。
- 見た目専用乱数はゲームルールの乱数と分離する。
- クライアントは候補や結果を独自抽選せず、ホストから受け取る。
- セーブ時は各ストリームの現在状態を保存する。

## 10. Resource定義の共通項目

すべてのゲーム定義Resourceが持つ基本情報:

```text
id: StringName
display_name_key: StringName
description_key: StringName
icon: Texture2D
tags: Array[StringName]
content_version: int
```

- 表示文は将来のローカライズを妨げないようキーで保持する。
- ラン中の可変HPやスタック数をResourceへ書き戻さない。
- 実行時状態は通常クラスまたはNodeへコピーして持つ。
- ID重複、空ID、無効参照をエディタまたはテストで全件検査する。

## 11. セーブ仕様

### ファイル

```text
user://settings.json
user://profile.json
user://suspended_run.json
```

### 共通ヘッダー

```json
{
  "schema_version": 1,
  "game_version": "0.1.0",
  "saved_at_utc": "ISO-8601",
  "payload": {}
}
```

- 書き込みは一時ファイルへ出してから置き換える。
- 読み込み失敗時は壊れたファイルを別名退避し、新規データを作る。
- `schema_version`ごとの移行関数を用意する。
- 中断ランは1件のみ。勝敗確定または明示破棄で削除する。
- マルチ中断データはホストが保持する。

## 12. 描画とパフォーマンス予算

- 最低目標: 1920×1080、60fps、一般的な内蔵GPU相当で30fps以上。
- 通常敵40体、最大60体。
- 同時プレイヤー弾80、車載弾80、敵弾60を初期上限。
- 弾、敵、ヒット演出、薬莢はオブジェクトプールを使用する。
- 背景は3〜5枚のParallax2D系レイヤー。
- 動的2Dライトは車内を中心に最大8。遠景は描き込みまたはシェーダー表現。
- CPUパーティクルを大量使用せず、GPUパーティクルまたは簡易Sprite演出にする。
- ネットワーク対象ノードと見た目専用ノードを分離する。

## 13. 衝突レイヤー番号

| 番号 | 名前 | 主用途 |
|---:|---|---|
| 1 | Player | プレイヤー本体 |
| 2 | PlayerProjectile | プレイヤー・味方の弾 |
| 3 | Enemy | 敵本体 |
| 4 | EnemyProjectile | 敵の弾・酸 |
| 5 | VehicleInterior | 床、壁、はしご判定 |
| 6 | VehicleExterior | 外装、屋根、側面足場 |
| 7 | Module | モジュールの被弾・操作判定 |
| 8 | Interactable | 修理、設備操作、蘇生候補 |
| 9 | Pickup | 回収物、弾薬 |
| 10 | Hazard | 道路障害、酸性雨、攻撃予告 |

- レイヤー11〜16は予約し、初期実装で別用途へ流用しない。
- Area2Dの検出マスクは必要な相手だけを明示し、全ビットONを使わない。

## 14. InputMapアクション名

```text
move_left
move_right
jump
drop_down
aim
fire_primary
fire_secondary
dodge
interact
ability
ping
pause
ready_toggle
```

- キーボードとゲームパッドは同じアクションを使う。
- UI操作はGodot標準`ui_*`アクションを維持する。
- ゲーム内アクションへ物理キーを直接問い合わせない。

## 15. 画面とUI

- Stretch modeは`canvas_items`、基準1920×1080。
- UIはControl + Themeで統一し、個別ノードに色・フォント値を散在させない。
- セーフエリアを上下左右5%確保する。
- フォントは日本語を含むライセンス確認済みフォントを1系統採用する。
- UIテキストの最小実表示サイズは16px相当。
- 色覚差に備え、状態を色だけで区別しない。

## 16. テスト方針

### 自動テスト対象

- 脅威予算が負にならず、登場Wave前の敵を選ばない。
- 車両配置が通路・はしご・外周制約を破らない。
- Resource IDが一意で参照切れがない。
- レリック抽選がWave帯、保証、スタック上限を守る。
- ルートが10列、最低2候補、ボス収束を満たす。
- セーブ→ロードでラン状態が一致する。
- 同一シードから同じルートと報酬候補を得る。

### 手動スモーク

- ソロで起動から2Wave仮勝利まで通る。
- 2クライアントで接続、移動、射撃、修理、投票、次Waveへ進める。
- クライアント切断・90秒以内再接続で状態復元できる。
- ゲームパッドだけでロビーからリザルトまで操作できる。
- 1280×720でHUDが車内を覆わず、文字が切れない。

## 17. 最初の技術スパイク

本実装より先に破棄可能な小規模検証を行う。

### Spike A: 車内移動

- 8×4の断面車両
- 2階層、片方向床、はしご、屋根ハッチ
- 2キャラクターが同じ画面で移動
- モジュールを置いても通路検証が働く

### Spike B: ネットワーク

- ホスト+クライアント1台
- 150ms RTT、2%損失を模した条件
- 移動予測、補正、射撃、命中、敵10体
- reliableとunreliableを別channelで使用
- 10分間、切断や状態不一致なく動作

### Spike C: 表示負荷

- 背景5レイヤー
- 敵60体、弾220、GPUパーティクル
- 1920×1080でフレーム時間を記録
- 目標機で60fps、最低環境想定で30fps以上

### 合格後

スパイクのコードをそのまま製品コードに昇格させず、得られた数値と設計判断を反映して最小スライスを実装する。

## 18. 開発開始時の順序

1. 空のGodot 4.7プロジェクトとフォルダ、入力、衝突レイヤーを作る。
2. Resource基底とCatalog検証を作る。
3. Spike A〜Cを順に実施する。
4. Run状態機械を作る。
5. 最小スライスを縦に完成させる。
6. 2人マルチで毎変更を確認する。
7. フルラン用コンテンツをデータ追加する。

## 19. 未導入を固定する技術

- ECSフレームワーク
- 外部DIコンテナ
- 独自物理エンジン
- 独自ネットワークプロトコル
- Kubernetesや常設専用サーバー
- ゲームルール用の外部データベース
- 早期のSteam SDK依存
- C#とGDScriptの混在

必要になった時点で、具体的な問題と計測結果を添えて再検討する。
