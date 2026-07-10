# アーカイブ(旧・工場防衛版ドキュメント)

このフォルダには、**2026-07-10のピボット以前**のゲーム「トップダウン工場防衛ローグライト」のドキュメントを保管する。

- 現行のゲームは Godot版**「移動車両型・協力Waveサバイバル」**。正となる仕様は [../13_godot-redevelopment-spec.md](../13_godot-redevelopment-spec.md) 以降。
- ここにあるドキュメントは**歴史的資料・参照用**であり、更新しない。
- 旧実装(`prototype/`・`unity/`)も凍結済みの参考実装として残している。

## 旧→新の対応表

| 旧(このフォルダ) | 役割 | 現行の対応ドキュメント |
|---|---|---|
| [00_game-constitution.md](00_game-constitution.md) | ゲームの憲法 | [13_godot-redevelopment-spec.md §0](../13_godot-redevelopment-spec.md) |
| [01_prototype-spec.md](01_prototype-spec.md) | プロトタイプ仕様 | [13_godot-redevelopment-spec.md](../13_godot-redevelopment-spec.md) 全体 |
| [02_not-todo.md](02_not-todo.md) | やらないことリスト | [13_godot-redevelopment-spec.md §0「今回作らないもの」](../13_godot-redevelopment-spec.md)・[14 §19](../14_godot-technical-spec.md) |
| [03_roadmap.md](03_roadmap.md) | ロードマップ・週次クエスト | [20_godot-roadmap.md](../20_godot-roadmap.md) |
| [04_engine-decision.md](04_engine-decision.md) | エンジン選定の経緯 | 決定済み: Godot 4.7(D-09、[15_preproduction-review.md](../15_preproduction-review.md)) |
| [10_unity-migration.md](10_unity-migration.md) | Unity移植計画 | 完了・凍結(unity/は参考実装) |
| [11_unity-milestones.md](11_unity-milestones.md) | Unity版マイルストーン | 完了・凍結 |
| [12_relic-catalog.md](12_relic-catalog.md) | レリック設計集 | [17_progression-catalog.md](../17_progression-catalog.md) |
| relic-cheatsheet.html / .png | レリック早見表 | 旧版のみ |
| job-character-concept.png | ジョブ案コンセプト画 | 新4キャラクターの源流([17 §5〜](../17_progression-catalog.md)) |

## ピボットの経緯(要約)

1. 旧・工場防衛はJSプロトタイプ→Unity v0.3まで実装し、テストプレイを実施した。
2. テストプレイの気づき(ジョブ/役割分担・レリック段階制など。[07_ideas.md](../07_ideas.md))を発展させ、「走行車両+車内改装+ルート分岐」の新コンセプトへ刷新することを決定した。
3. 同時にエンジンをGodot 4.7へ変更し、docs 13〜19 の事前仕様を策定して開発を再スタートした。
4. 旧コンセプトの継承要素: Wave予算制・車両(旧: コア)破壊のみ敗北・3択レリック・1〜4人協力([15 §2](../15_preproduction-review.md))。
