using UnityEngine;

namespace NightFactoryDefence
{
    // プレイヤーのバランス数値。config.js の PLAYER に相当(速度は px/s ÷40)。
    [CreateAssetMenu(fileName = "PlayerData", menuName = "Night Factory Defence/Player Data")]
    public sealed class NfdPlayerData : ScriptableObject
    {
        public float maxHp = 100f;
        public float speed = 4.5f;        // unit/s
        public float dmg = 15f;           // 弾1発のダメージ
        public float fireRate = 4f;       // 発/秒
        public float bulletSpeed = 13f;   // unit/s
        public float radius = 0.3f;
        public float respawnTime = 4f;    // 倒れてから復活までの秒数
        public float hurtCooldown = 0.8f; // 接触ダメージを受ける間隔(秒)
    }
}
