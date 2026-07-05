using UnityEngine;

namespace NightFactoryDefence
{
    // 設置された建物1つ。HPと占有タイルを持つ。
    // 種類ごとの動き(タレットの射撃、採掘機の生産など)は別コンポーネントが担当する。
    public sealed class NfdBuilding : MonoBehaviour
    {
        public NfdBuildingData Data { get; private set; }
        public int GridX { get; private set; }
        public int GridY { get; private set; }

        float hp;
        float maxHp;

        public bool IsAlive => hp > 0f;
        public float HpFraction => maxHp > 0f ? hp / maxHp : 0f;

        // 設置時に呼ぶ。データからHPを設定し、占有タイルを覚える。
        public void Setup(NfdBuildingData data, int gx, int gy)
        {
            Data = data;
            GridX = gx;
            GridY = gy;
            maxHp = data.hp;
            hp = data.hp;
        }

        // 敵に攻撃されたときに呼ばれる。HP0で撤去。
        public void TakeDamage(float damage)
        {
            if (damage <= 0f || hp <= 0f) return;

            hp -= damage;
            if (hp <= 0f)
            {
                NfdBuildGrid.Instance?.Clear(GridX, GridY);
                Destroy(gameObject);
            }
        }
    }
}
