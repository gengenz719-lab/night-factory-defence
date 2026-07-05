namespace NightFactoryDefence
{
    // ランの結末。
    public enum NfdRunResult
    {
        Playing, // 進行中
        Won,     // 勝利(Wave生存)
        Lost,    // 敗北(コア破壊)
    }

    // ゲームの「状態」だけを持つ純粋なデータ。MonoBehaviourではない(シーンに置かない)。
    //
    // 大事なルール:
    // - この状態を変更してよいのは NfdGameManager だけ(将来のマルチでホストが真実を持つ形の下地)
    // - HUDなどの描画側はこの状態を「読むだけ」。決して書き換えない
    //
    // プロトタイプの state.js に相当する。
    public sealed class NfdGameState
    {
        // ラン全体
        public NfdRunResult Result = NfdRunResult.Playing;
        public int WaveNumber = 1;
        public int Kills;

        // 夜(Wave)の進行
        public bool WaveRunning;
        public int EnemiesAlive;   // いま盤面にいる敵の数
        public int EnemiesToSpawn; // これから湧く残りの数
        public int EnemiesRemaining => EnemiesAlive + EnemiesToSpawn;

        // 拠点コア
        public float CoreHp;
        public float CoreMaxHp;

        public bool IsRunEnded => Result != NfdRunResult.Playing;
    }
}
