# Godot再開発 仕様完成監査

> 監査対象: 「1〜8の仕様を確定し、開発作業開始前まで詰める」
> 監査日: 2026-07-10
> 判定: 開発前仕様 v0.1 完成

## 1. ユーザー提示イメージの充足

| 要求 | 根拠 | 判定 |
|---|---|---|
| Waveクリア式 | [13](13_godot-redevelopment-spec.md) §1 | 完了 |
| ゾンビ世界で一定時間耐久 | [13](13_godot-redevelopment-spec.md) §1、[16](16_combat-vehicle-balance.md) §5 | 完了 |
| マルチを維持 | [13](13_godot-redevelopment-spec.md) §8 | 1〜4人で完了 |
| 小型車両の横視点スクロール | [13](13_godot-redevelopment-spec.md) §0・2 | 完了 |
| 右から左へ走る視覚体験 | [13](13_godot-redevelopment-spec.md) §0・1 | 車両左向き、背景左→右で完了 |
| 車内を自由に改装 | [13](13_godot-redevelopment-spec.md) §4、[16](16_combat-vehicle-balance.md) §7・9 | 完了 |
| 戦闘車両とおしゃれの両立 | [13](13_godot-redevelopment-spec.md) §4.7 | 機能/装飾レイヤー分離で完了 |
| Terraria風に車内移動・外へ射撃 | [13](13_godot-redevelopment-spec.md) §2 | 完了 |
| 車両とキャラクターの成長 | [13](13_godot-redevelopment-spec.md) §3・4・6、[17](17_progression-catalog.md) | 完了 |
| Slay the Spire型マップ | [13](13_godot-redevelopment-spec.md) §7、[18](18_route-ui-acceptance.md) §1 | 完了 |
| Wave後レリック3択 | [13](13_godot-redevelopment-spec.md) §6、[17](17_progression-catalog.md) §2〜4 | Wave 1〜9で完了 |
| 戦闘・車両・特殊の成長選択 | [13](13_godot-redevelopment-spec.md) §6、[17](17_progression-catalog.md) §2 | 各8種で完了 |

## 2. 1〜8の完成根拠

| 番号 | 仕様 | 成果物 | 判定 |
|---:|---|---|---|
| 1 | 1Waveの基本ループ | [13](13_godot-redevelopment-spec.md) §1、[16](16_combat-vehicle-balance.md) §5 | 時間・勝敗・報酬まで完了 |
| 2 | 車内の広さ・階層・移動 | [13](13_godot-redevelopment-spec.md) §2、[16](16_combat-vehicle-balance.md) §9 | グリッド・階層・車外まで完了 |
| 3 | プレイヤー役割と操作 | [13](13_godot-redevelopment-spec.md) §3、[17](17_progression-catalog.md) §5〜10 | 4役割・入力・復帰まで完了 |
| 4 | 車両改装ルール | [13](13_godot-redevelopment-spec.md) §4、[16](16_combat-vehicle-balance.md) §7〜9 | 配置・資源・修理まで完了 |
| 5 | 敵の侵入・攻撃・回避 | [13](13_godot-redevelopment-spec.md) §5、[16](16_combat-vehicle-balance.md) §4・6 | 敵10種・ボス2種まで完了 |
| 6 | レリック・スキル・ステータス | [13](13_godot-redevelopment-spec.md) §6、[17](17_progression-catalog.md) | レリック24・スキル48まで完了 |
| 7 | ステージマップ | [13](13_godot-redevelopment-spec.md) §7、[18](18_route-ui-acceptance.md) §1〜3 | 生成制約・報酬・イベントまで完了 |
| 8 | マルチ人数と同期 | [13](13_godot-redevelopment-spec.md) §8、[14](14_godot-technical-spec.md) §6〜8 | 権威・RPC・切断まで完了 |

## 3. 開発前成果物

| 成果物 | 根拠 | 判定 |
|---|---|---|
| ゲーム憲法・スコープ | [13](13_godot-redevelopment-spec.md) §0・12 | 完了 |
| Godotバージョン・言語 | [14](14_godot-technical-spec.md) §1 | Godot 4.7 / 型付きGDScript |
| シーン・フォルダ・責務 | [14](14_godot-technical-spec.md) §2〜5 | 完了 |
| ネットワーク契約 | [14](14_godot-technical-spec.md) §6〜9 | 完了 |
| データResource構造 | [14](14_godot-technical-spec.md) §10 | 完了 |
| セーブ仕様 | [14](14_godot-technical-spec.md) §11 | 完了 |
| 衝突レイヤー・InputMap | [14](14_godot-technical-spec.md) §13〜14 | 番号・名前まで完了 |
| 技術スパイク | [14](14_godot-technical-spec.md) §17 | 移動・通信・負荷を定義 |
| 武器・敵・Wave・車両数値 | [16](16_combat-vehicle-balance.md) | 完了 |
| 成長カタログ | [17](17_progression-catalog.md) | 完了 |
| HUD・チュートリアル | [18](18_route-ui-acceptance.md) §4〜8 | 完了 |
| 最小スライス受け入れ条件 | [18](18_route-ui-acceptance.md) §10 | 完了 |
| フルラン・アルファ受け入れ | [18](18_route-ui-acceptance.md) §11 | 完了 |
| 基準コンセプト画 | [godot-gameplay-concept-v1.png](godot-gameplay-concept-v1.png) | ユーザーから概ねイメージどおりとの確認あり |

## 4. 機械監査

| 検査 | 期待 | 実測 | 判定 |
|---|---:|---:|---|
| 通常敵 | 10 | 10 | 合格 |
| ボス | 2 | 2 | 合格 |
| 初期モジュール | 12 | 12 | 合格 |
| Wave表 | 10 | 10 | 合格 |
| 共有レリック | 24 | 24 | 合格 |
| 個人スキル | 48 | 48 | 合格 |
| Markdownコードフェンス | 全ファイル偶数 | 偶数 | 合格 |
| 仕様書内相対リンク | リンク切れ0 | 0 | 合格 |
| 旧方向表現「背景右→左」 | 0 | 0 | 合格 |
| 旧報酬表現「レリック10回」 | 0 | 0 | 合格 |
| 保留を示す作業マーカー | 0 | 0 | 合格 |

## 5. 残るもの

仕様作業として必須の未完了項目はない。次の作業は仕様策定ではなく、以下の開発開始工程である。

1. Godot 4.7環境の導入確認
2. 空プロジェクト作成
3. 車内移動Spike A
4. 2人通信Spike B
5. 表示負荷Spike C
6. 最小プレイアブル・スライス実装

数値はプレイテストで調整する。D-01〜D-10のルールを変える場合は、[15_preproduction-review.md](15_preproduction-review.md)へ変更理由と影響範囲を記録する。
