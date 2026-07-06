using System.Collections.Generic;
using UnityEngine;

namespace NightFactoryDefence
{
    // 弾。まっすぐ飛んで敵に当たると消える。
    // ダメージ・速度・貫通数は発射元(プレイヤー/タレット)が Fire で渡す。
    public sealed class NfdBullet : MonoBehaviour
    {
        [SerializeField] float lifeSeconds = 1.4f;
        [SerializeField] float hitRadius = 0.34f;

        Vector3 velocity;
        float damage = 15f;
        int pierce;                       // あと何体貫通できるか(レリック「跳弾」)
        readonly HashSet<NfdEnemy> hit = new(); // 同じ敵を二度打ちしない

        // dir=方向, dmg=ダメージ, speed=弾速, pierceCount=貫通数
        public void Fire(Vector3 direction, float dmg, float speed, int pierceCount = 0)
        {
            velocity = direction.normalized * speed;
            damage = dmg;
            pierce = pierceCount;
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
            if (enemy == null || hit.Contains(enemy)) return;

            enemy.TakeDamage(damage);
            hit.Add(enemy);
            NfdFxManager.Instance?.Hit(transform.position); // 着弾スパーク

            if (pierce > 0)
            {
                pierce--; // まだ貫通できる。消えずに飛び続ける
                return;
            }
            Destroy(gameObject);
        }
    }
}
