using UnityEngine;

namespace NightFactoryDefence
{
    public sealed class NfdEnemy : MonoBehaviour
    {
        [SerializeField] float maxHp = 35f;
        [SerializeField] float speed = 1.55f;
        [SerializeField] float contactDamagePerSecond = 12f;
        [SerializeField] float contactRange = 0.75f;

        NfdCore core;
        NfdEnemyVisual visual;
        float hp;

        public bool IsAlive => hp > 0f;

        void Awake()
        {
            visual = GetComponentInChildren<NfdEnemyVisual>();
        }

        public void Init(NfdCore targetCore, float hpMultiplier, float speedMultiplier)
        {
            core = targetCore;
            hp = maxHp * hpMultiplier;
            speed *= speedMultiplier;
        }

        void OnEnable()
        {
            NfdGameManager.Instance?.RegisterEnemy(this);
        }

        void OnDisable()
        {
            NfdGameManager.Instance?.UnregisterEnemy(this);
        }

        void Update()
        {
            if (core == null || !IsAlive || NfdGameManager.Instance.IsRunEnded) return;

            var toCore = core.transform.position - transform.position;
            var distance = toCore.magnitude;
            if (distance <= contactRange)
            {
                core.TakeDamage(contactDamagePerSecond * Time.deltaTime);
                return;
            }

            transform.position += toCore.normalized * speed * Time.deltaTime;
        }

        public void TakeDamage(float damage)
        {
            if (damage <= 0f || !IsAlive) return;

            hp -= damage;
            visual?.OnHit();
            if (hp <= 0f)
            {
                NfdGameManager.Instance?.AddKill();
                Destroy(gameObject);
            }
        }
    }
}
