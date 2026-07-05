using UnityEngine;

namespace NightFactoryDefence
{
    public enum NfdBuildingKind { Wall, Turret, Miner, Smelter }

    // 建物1種の定義。config.js の BUILDINGS の1エントリに相当。
    // 種類ごとに使うフィールドが違う(config.jsと同じくフラットに持つ)。
    [CreateAssetMenu(fileName = "BuildingData", menuName = "Night Factory Defence/Building Data")]
    public sealed class NfdBuildingData : ScriptableObject
    {
        public NfdBuildingKind kind = NfdBuildingKind.Wall;
        public string displayName = "壁";
        public string hotkey = "1";
        public int cost = 5;
        public float hp = 120f;
        public Color color = new Color(0.54f, 0.56f, 0.6f, 1f);
        [TextArea] public string description = "";

        [Header("タレット用")]
        public float range = 4.25f;      // unit
        public float fireRate = 2f;      // 発/秒
        public float dmg = 12f;
        public float bulletSpeed = 12f;  // unit/s

        [Header("採掘機/加工炉用")]
        public float interval = 2f;      // 生産間隔(秒)
        public float output = 1f;        // 採掘機: 1回の鉄産出
        public bool needsOre = false;    // 採掘機: 鉱床の上のみ設置可
        public float ironIn = 1f;        // 加工炉: 消費する鉄
        public float ammoOut = 2f;       // 加工炉: 産出する弾薬
    }
}
