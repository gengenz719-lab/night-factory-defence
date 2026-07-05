using UnityEngine;

namespace NightFactoryDefence
{
    // レリックの効果の種類。relics.js の applyEffect が解釈していた type に相当。
    public enum NfdRelicEffectType
    {
        Pierce,        // 弾が敵を貫通する数
        FireRate,      // プレイヤー攻撃速度の倍率
        MoveSpeed,     // 移動速度の倍率
        MaxHp,         // 最大HPの加算(全回復)
        TurretRange,   // タレット射程の倍率
        TurretRate,    // タレット発射速度の倍率
        WallHp,        // 壁の最大HPの倍率(全回復)
        SmelterBonus,  // 加工炉の弾薬生産への加算
        MinerRate,     // 採掘速度の倍率
        AmmoNow,       // 即時に弾薬を加算
    }

    // レリック1種。config.js の RELICS の1エントリに相当。
    [CreateAssetMenu(fileName = "RelicData", menuName = "Night Factory Defence/Relic Data")]
    public sealed class NfdRelicData : ScriptableObject
    {
        public string id = "";
        public string displayName = "";
        [TextArea] public string description = "";
        public NfdRelicEffectType effectType;
        public float value = 1f;
    }
}
