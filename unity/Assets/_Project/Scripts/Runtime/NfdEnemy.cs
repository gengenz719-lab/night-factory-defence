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
        float hp;

        public bool IsAlive => hp > 0f;

        public void Init(NfdCore targetCore, float hpMultiplier, float speedMultiplier)
        {
            core = targetCore;
            hp = maxHp * hpMultiplier;
            speed *= speedMultiplier;
        }

        void OnEnable()
        {
            NfdPlayableSliceController.Instance?.RegisterEnemy(this);
        }

        void OnDisable()
        {
            NfdPlayableSliceController.Instance?.UnregisterEnemy(this);
        }

        void Update()
        {
            if (core == null || !IsAlive || NfdPlayableSliceController.Instance.IsRunEnded) return;

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
            if (hp <= 0f)
            {
                NfdPlayableSliceController.Instance?.AddKill();
                Destroy(gameObject);
            }
        }
    }
}
