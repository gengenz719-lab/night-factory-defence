# 技術選定の理由とエンジン移行計画

## 現在の構成: HTML5 (素のJavaScript + Canvas 2D)

開発メモではUnity + Unity Version Controlを想定していたが、
プロトタイプ段階は**あえてHTML5**を選んだ。理由:

1. **今日から遊べる** — エンジンのインストール・ライセンス・エディタ学習が一切不要
2. **パートナーの参加コストがゼロ** — フォルダを渡せば(またはURLで)ブラウザで即遊べる。開発参加もVS Code + AIだけでよい
3. **AIバイブコーディングと相性が最高** — 全ファイルがテキスト。シーンファイルやPrefabのバイナリ衝突が存在せず、AIが全体を読んで書ける
4. **Gitだけで完結** — Unity Version Control・Git LFS・.gitignore地獄を回避できる
5. **前例がある** — Vampire Survivors は最初HTML5製で、売れてからエンジン移植された

## プロトタイプ段階の制約(承知の上)

```text
Steamへそのまま出しにくい(Electron同梱は可能だが品質面で不利)
ゲームパッド・Steamworks連携が弱い
オンラインマルチの実装コストが高い
```

→ だからこそ「面白さの検証」に集中し、検証が済んだらエンジンへ移植する。

## 製品版エンジン: Unity と Godot 4 の二択(ほぼ互角)

当初このドキュメントは「AIがUnityエディタを操作できない」前提で Godot を第一候補としていた。
**この前提は Unity MCP の登場で覆った**ため、下記のとおり再評価する。

### Unity MCP により状況が変わった(重要)

Unity MCP(例: [CoplayDev/unity-mcp](https://github.com/CoplayDev/unity-mcp)、
[AnkleBreaker-Studio/unity-mcp-server](https://github.com/AnkleBreaker-Studio/unity-mcp-server)、Unity公式AI Assistant同梱MCP)を使うと、
Claude Code から Unity エディタを直接操作できる:

```text
- GameObject / シーン / Prefab の作成・配置
- C#スクリプトの生成・アタッチ・編集
- コンソールのエラーを読んで自動修正
- Play mode 実行・ビルド・プロファイリング
```

→ **「Unityはエディタ操作前提でAIバイブコーディングに向かない」という以前の欠点は、ほぼ解消された。**
C#はAIの学習データが豊富で、コード生成の質はむしろ高い。

### 比較(Unity MCP 前提で更新)

| 観点 | Unity | Godot 4 |
|---|---|---|
| AI協働 | Unity MCPでエディタ操作もAI可能(◎に更新) | プロジェクト全体がテキストで読める(◎) |
| 情報量・チュートリアル | 圧倒的に多い(初心者に有利) | 増加中だがUnityに劣る |
| マルチプレイ | Netcode成熟・情報多い | 高レベルAPI内蔵 |
| Steam対応 | 実績最多 | GodotSteam等で実績多数 |
| アセットストア | 巨大 | 小さめ |
| 費用 | Personalは無料(収益条件あり) | 完全無料 |
| シーン/Prefab競合 | バイナリ寄りで衝突しやすい(要Smart Locks等の運用) | テキスト(.tscn)で比較的マージしやすい |
| セットアップの重さ | Unity本体 + MCP用にPython 3.10+が必要 | 比較的軽量 |
| 2D軽量ゲーム | 可能(やや過剰) | 得意分野 |

### 現時点の結論

- **Unityを避ける技術的理由(AI相性)はもう無い。** Steam協力プレイ・情報量・初心者の学習素材を重視するなら **Unity は十分に推奨できる**。
- **決め手はチームの経験者の有無。** Unity経験者がいるならUnity一択。全員未経験なら、軽さと無料・テキストシーンを取るなら Godot、エコシステムと将来性を取るなら Unity。
- どちらを選ぶ場合も、**シーン/Prefabの同時編集ルール**(担当分け・テストScene分離・Version Control)は最初に決める。

### 残る注意点(Unityを選ぶ場合)

```text
- Scene/Prefabの複数人同時編集は依然リスク → Unity Version Control の Smart Locks で運用
- Unity MCP のセットアップに Python 3.10+ が必要(この環境は現状 Python 未インストール)
- Unity公式MCPはサブスク前提。無料で始めるならコミュニティ製MCPを使う
```

## 移植の設計方針(今から守ること)

プロトタイプの段階から、移植を楽にするための分離を守る:

```text
- バランス数値は config.js に集約 → Unityの ScriptableObject / Godotのリソース どちらにも変換しやすい
- ゲーム状態(state.js)と描画(ui.js)を分離 → ロジックだけ移植すればよい
- 敵・建物・レリックは「データ定義+汎用処理」の形にする → データ追加で増やせる
```

移植時はロジックを1対1で書き直すのではなく、
**プロトタイプを「仕様書兼リファレンス実装」として扱い、選んだエンジン(Unity or Godot)で作り直す**。
