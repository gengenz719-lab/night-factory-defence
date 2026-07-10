# GitHub 参加ガイド(パートナー向け)

このプロジェクトはGitHubで共有されている。パートナーが開発・テストに参加するための手順。

## オーナー(あなた)がやること: パートナーを招待する

1. GitHubでリポジトリのページを開く
2. `Settings` → `Collaborators` → `Add people`
3. パートナーのGitHubユーザー名を入力して招待
4. パートナーが招待メールのリンクから承認すれば参加完了

## パートナーがやること: 最初の1回

### 1. 必要なものを入れる(どちらも無料)

- [Git](https://git-scm.com/) … インストールするだけ
- [VS Code](https://code.visualstudio.com/) … コードを見る・書く(遊ぶだけなら不要)

### 2. リポジトリを自分のPCに持ってくる(クローン)

VS Code でも、ターミナルでもできる。ターミナルの場合:

```bash
git clone https://github.com/<オーナーのユーザー名>/night-factory-defence.git
cd night-factory-defence
```

(初回はGitHubのログインを求められる。ブラウザが開くので承認するだけ)

### 3. 遊ぶ

いちばん簡単なのはブラウザ版(インストール不要):
https://gengenz719-lab.github.io/night-factory-defence/godot-play/

クローンしたリポジトリから遊ぶなら `godot/PLAY_TEST.bat` をダブルクリック
(初回はGodot 4.7を `.tools/godot-4.7/` に配置する。手順はAIに聞けば教えてくれる)。

## 毎回の作業の流れ(超重要・これだけ守る)

```text
1. 作業を始める前に、必ず最新版を取得する
   git pull

2. コードを変更する(AIと一緒に)

3. 変更を保存して送る
   git add -A
   git commit -m "何を変えたか一言"
   git push

4. Discordの #できた報告 に何を変えたか書く
```

## 困ったときの合言葉(AIに聞く)

そのままAIに貼れば手順を教えてくれる:

```text
・「git pull したら conflict と出た。初心者向けに直し方を教えて」
・「間違えて変なコミットをした。1つ前の状態に戻したい」
・「git push したら rejected と言われた。どうすればいい?」
```

## 壊すのが怖い人へ

GitHubに履歴が全部残っているので、**何をどう壊しても必ず元に戻せる**。
分からなくなったら止まって、Discordで聞くかAIに相談すればいい。焦って上書きしないことだけ注意。

## ブランチについて(慣れてきたら)

最初は全員 `master`(または `main`)に直接pushでよい(人数が少ないうちはこれが速い)。
同じファイルを触って衝突が増えてきたら、そのとき初めてブランチとPull Requestを導入する。
それまでは **「作業前に宣言」「作業前にpull」** の2つで十分に回る。
