using UnityEngine;

namespace NightFactoryDefence
{
    // 弾。まっすぐ飛んで最寄りの敵に当たると消える。
    // ダメージと速度は発射元(プレイヤー/タレット)が Fire で渡す。
    public sealed class NfdBullet : MonoBehaviour
    {
        [SerializeField] float lifeSeconds = 1.4f;
        [SerializeField] float hitRadius = 0.34f;

        Vector3 velocity;
        float damage = 15f;

        // dir=方向, dmg=ダメージ, speed=弾速(unit/s)
        public void Fire(Vector3 direction, float dmg, float speed)
        {
            velocity = direction.normalized * speed;
            damage = dmg;
        }

        void Update()
        {
            transform.position += velocity * Time.deltaTime;
            lifeSeconds -= Time.deltaTime;
            if (lifeSeconds <= 0f)
            {
                Destroy(gameObject);
                return;
            }

            var manager = NfdGameManager.Instance;
            if (manager == null) return;

            var enemy = manager.FindClosestEnemy(transform.position, hitRadius);
            if (enemy == null) return;

            enemy.TakeDamage(damage);
            Destroy(gameObject);
        }
    }
}
