using UnityEngine;

namespace NightFactoryDefence
{
    // 拠点コア。物理的な標的(敵が狙う位置)と、最大HPの設定値を持つ。
    // 現在HPは NfdGameState が持ち、被弾処理は NfdGameManager が行う
    // (状態は一箇所=GameStateに集約し、将来のマルチで同期しやすくするため)。
    public sealed class NfdCore : MonoBehaviour
    {
        [SerializeField] float maxHp = 600f;

        public float MaxHp => maxHp;

        // 敵が接触したときに呼ばれる。実際のHP計算と敗北判定はGameManagerが行う。
        public void TakeDamage(float damage)
        {
            NfdGameManager.Instance?.DamageCore(damage);
        }
    }
}
