using UnityEngine;

namespace NightFactoryDefence
{
    // 敵1種のバランス数値。config.js の ENEMIES の1エントリに相当。
    // 速度はプロトタイプの px/s を ÷40 して unit/s にしてある。
    [CreateAssetMenu(fileName = "EnemyData", menuName = "Night Factory Defence/Enemy Data")]
    public sealed class NfdEnemyData : ScriptableObject
    {
        public string displayName = "ウォーカー";
        public int cost = 1;          // Wave予算に対するコスト
        public int minWave = 1;       // 登場開始Wave
        public float hp = 30f;
        public float speed = 1.05f;   // unit/s
        public float radius = 0.28f;
        public Color color = new Color(0.5f, 0.75f, 0.37f, 1f);
        public float buildingDps = 6f; // 建物への毎秒ダメージ
        public float playerDmg = 8f;    // プレイヤーへの接触ダメージ(1回分)
    }
}
