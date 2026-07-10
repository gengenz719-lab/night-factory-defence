# Godot再開発 開発前レビュー表

> 目的: マスター仕様を実装可能な単位で承認し、後から認識がずれないようにする。
> 詳細は [13_godot-redevelopment-spec.md](13_godot-redevelopment-spec.md)、技術面は [14_godot-technical-spec.md](14_godot-technical-spec.md) を参照。

## 1. 主要決定

| ID | 決定 | 固定案 | 状態 |
|---|---|---|---|
| D-01 | ランの長さ | 全10Wave、25〜35分 | v0.1固定 |
| D-02 | Waveクリア | 通常は時間耐久+10秒離脱。残敵全滅は不要 | v0.1固定 |
| D-03 | 敗北条件 | 車両耐久0のみ。プレイヤーはダウン・復帰 | v0.1固定 |
| D-04 | 車内サイズ | 初期8×4/2階層、Wave 5後に最大10×5 | v0.1固定 |
| D-05 | 役割 | ガンナー、エンジニア、スカウト、オペレーター。重複可 | v0.1固定 |
| D-06 | 成長 | Wave 1〜9後に共有レリック投票、Wave 2/5/8後に個人スキル | v0.1固定 |
| D-07 | マップ | 10列。全ノードで戦闘、敵・危険・事後サービスが変化 | v0.1固定 |
| D-08 | マルチ | 1〜4人、ホスト権威。初期版はホスト移行なし | v0.1固定 |
| D-09 | エンジン | Godot 4.7 stable、型付きGDScript | v0.1固定 |
| D-10 | 初期配信対象 | Windows 10/11、後からSteam統合 | v0.1固定 |

## 2. 仕様間の整合確認

| 観点 | 確認結果 |
|---|---|
| プレイ時間 | 戦闘合計17分30秒。Wave間を平均50〜70秒として25〜35分に収まる |
| 報酬回数 | 共有レリック9回、個人スキル3回、中ボス後フレーム拡張1回。最終ボス後はリザルト |
| マルチ競合 | 共有要素は投票、個人要素は各自選択、車両改装は権限制御 |
| ソロ成立 | 敵予算1.0倍、設備簡易自動化、修理支援あり |
| 車両成長 | 機能グリッドと装飾レイヤーを分け、見た目が最適化に負けない |
| 旧版継承 | Wave予算制、車両破壊のみ敗北、3択レリック、1〜4人設計を継承 |
| 新版変更 | 固定工場を廃止し、走行車両、侵入、ルート分岐、役割行動へ置換 |
| Godot適合 | 2D Sprite、Resource、CanvasLayer、Parallax、ENetで構成可能 |

## 3. 開発開始前データ表の状態

| 成果物 | 状態 | 根拠 |
|---|---|---|
| Wave 1〜10の敵予算・解禁敵・危険イベント | 完了 | [16_combat-vehicle-balance.md](16_combat-vehicle-balance.md) §5 |
| 初期敵10種とボス2種の数値 | 完了 | [16_combat-vehicle-balance.md](16_combat-vehicle-balance.md) §4 |
| 初期モジュール12種のコスト・電力・HP | 完了 | [16_combat-vehicle-balance.md](16_combat-vehicle-balance.md) §7 |
| 共有レリック24種 | 完了 | [17_progression-catalog.md](17_progression-catalog.md) §2 |
| 4キャラクター×個人スキル12種 | 完了 | [17_progression-catalog.md](17_progression-catalog.md) §6〜9 |
| 武器ラインアップと基準DPS | 完了 | [16_combat-vehicle-balance.md](16_combat-vehicle-balance.md) §3 |
| 車両グリッド初期配置図 | 完了 | [16_combat-vehicle-balance.md](16_combat-vehicle-balance.md) §9 |
| ルート生成例とノード報酬 | 完了 | [18_route-ui-acceptance.md](18_route-ui-acceptance.md) §1〜2 |
| HUDワイヤーフレーム | 完了 | [18_route-ui-acceptance.md](18_route-ui-acceptance.md) §5〜7 |
| 最小スライス受け入れテスト | 完了 | [18_route-ui-acceptance.md](18_route-ui-acceptance.md) §10 |

## 4. 変更ルール

- D-01〜D-10を変える場合は、理由と影響する仕様セクションを記録する。
- 数値調整はゲームルールを変えない限り、プレイテスト結果を根拠に更新できる。
- 新要素は「今回作らないもの」と初期スコープを確認してから追加する。
- 実装の都合だけでユーザー体験を縮小しない。難しい場合は先にスパイクで検証する。
