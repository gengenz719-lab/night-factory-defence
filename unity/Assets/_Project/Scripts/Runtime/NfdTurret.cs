using UnityEngine;

namespace NightFactoryDefence
{
    // タレットの挙動。範囲内の最寄り敵を自動射撃し、共有倉庫の弾薬を1発1消費する。
    // 弾薬が無いと撃てない(=工場を建てる動機)。
    // ステータスは同じGameObjectの NfdBuilding.Data(BuildingData)から読む。
    [RequireComponent(typeof(NfdBuilding))]
    public sealed class NfdTurret : MonoBehaviour
    {
        [SerializeField] NfdBullet bulletPrefab;
        [SerializeField] Transform barrel; // 敵の方を向く砲身(任意)

        NfdBuilding building;
        float cooldown;

        void Awake()
        {
            building = GetComponent<NfdBuilding>();
        }

        void Update()
        {
            var manager = NfdGameManager.Instance;
            if (manager == null || manager.IsRunEnded || building.Data == null) return;

            var data = building.Data;
            var range = data.range * manager.TurretRangeMult; // レリック「砲術」
            var target = manager.FindClosestEnemy(transform.position, range);
            if (target == null) return;

            // 砲身を敵の方へ向ける(スプライトは上向きが正面)
            if (barrel != null)
            {
                var dir = target.transform.position - transform.position;
                var angle = Mathf.Atan2(dir.y, dir.x) * Mathf.Rad2Deg - 90f;
                barrel.rotation = Quaternion.Euler(0f, 0f, angle);
            }

            cooldown -= Time.deltaTime;
            if (cooldown > 0f) return;

            // 弾薬を1消費できたら発射
            if (!manager.TrySpendAmmo(1)) return;

            var fireRate = data.fireRate * manager.TurretRateMult; // レリック「連射砲」
            cooldown = 1f / Mathf.Max(0.01f, fireRate);
            if (bulletPrefab != null)
            {
                var dir = (target.transform.position - transform.position).normalized;
                var bullet = Instantiate(bulletPrefab, transform.position, Quaternion.identity);
                bullet.Fire(dir, data.dmg, data.bulletSpeed, manager.PierceBonus);
            }
        }
    }
}
