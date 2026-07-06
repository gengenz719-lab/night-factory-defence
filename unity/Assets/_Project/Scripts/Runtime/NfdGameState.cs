using System.Collections.Generic;

namespace NightFactoryDefence
{
    // ランの結末。
    public enum NfdRunResult
    {
        Playing, // 進行中
        Won,     // 勝利(全Wave生存)
        Lost,    // 敗北(コア破壊)
    }

    // 昼夜フェーズ。
    public enum NfdPhase
    {
        Day,   // 建設フェーズ
        Night, // 防衛(Wave)フェーズ
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
        public NfdPhase Phase = NfdPhase.Day;
        public int WaveNumber = 1;
        public int TotalWaves = 10;
        public int Kills;

        // フェーズ
        public float PhaseTimer;   // 昼の残り秒数(夜は未使用)

        // 夜(Wave)の進行
        public int EnemiesAlive;   // いま盤面にいる敵の数
        public int EnemiesToSpawn; // これから湧く残りの数
        public int EnemiesRemaining => EnemiesAlive + EnemiesToSpawn;

        // 拠点コア
        public float CoreHp;
        public float CoreMaxHp;
        public float CoreHitFlash; // 被弾直後に上がり、時間で減衰(赤ビネット用)

        // プレイヤー(HUD表示用のミラー。書き込むのはGameManager経由)
        public float PlayerHp;
        public float PlayerMaxHp;
        public bool PlayerDown;      // 倒れてリスポーン待ちか
        public float PlayerRespawn;  // 復活までの残り秒

        // 資源(表示はPhase Cから。ロジックは先に持っておく)
        public int Iron;
        public int Ammo;

        // レリック(Waveクリア後の3択)
        public bool ChoosingRelic;                       // 3択の選択待ちか
        public List<NfdRelicData> RelicChoices = new();  // 提示中の3枚
        public List<string> OwnedRelicIds = new();       // 取得済み(重複防止)

        public bool IsNight => Phase == NfdPhase.Night;
        public bool IsRunEnded => Result != NfdRunResult.Playing;
    }
}
