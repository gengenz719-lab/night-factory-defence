using UnityEngine;

namespace NightFactoryDefence
{
    // Wave進行・経済まわりの数値。config.js のマップ/フェーズ/スポーン/報酬をまとめたもの。
    [CreateAssetMenu(fileName = "WaveData", menuName = "Night Factory Defence/Wave Data")]
    public sealed class NfdWaveData : ScriptableObject
    {
        public float dayTime = 45f;   // 昼(建設)フェーズの秒数

        // Waveごとの敵予算(難易度カーブそのもの)。Wave6は休憩、Wave10が山場
        public int[] waveBudgets = { 10, 15, 22, 30, 42, 38, 52, 68, 85, 120 };
        public int bossWaveTanks = 4; // 最終Waveで最初に必ず出すタンク数

        [Header("スポーン")]
        public float spawnInterval = 0.9f;
        public int groupMin = 1;
        public int groupMax = 3;

        [Header("経済")]
        public int startIron = 80;
        public int startAmmo = 80;
        public int clearRewardBase = 20;    // Waveクリア報酬(鉄): base + wave*perWave
        public int clearRewardPerWave = 5;

        public float aggroRange = 2.75f;    // 敵がプレイヤーを狙い始める距離(unit)

        public int TotalWaves => waveBudgets != null ? waveBudgets.Length : 0;
    }
}
