using UnityEngine;

namespace NightFactoryDefence
{
    // すべてのバランスデータへの入口。config.js の CONFIG 全体に相当。
    // GameManager はこの1アセットだけを参照すればゲームの数値が全部読める。
    [CreateAssetMenu(fileName = "GameConfig", menuName = "Night Factory Defence/Game Config")]
    public sealed class NfdGameConfig : ScriptableObject
    {
        public NfdWaveData wave;
        public NfdPlayerData player;
        public NfdEnemyData[] enemies;    // walker / runner / tank
        public NfdBuildingData[] buildings; // wall / turret / miner / smelter
        public NfdRelicData[] relics;      // 10種

        // 種類から建物データを引く
        public NfdBuildingData GetBuilding(NfdBuildingKind kind)
        {
            if (buildings == null) return null;
            foreach (var b in buildings)
            {
                if (b != null && b.kind == kind) return b;
            }
            return null;
        }
    }
}
