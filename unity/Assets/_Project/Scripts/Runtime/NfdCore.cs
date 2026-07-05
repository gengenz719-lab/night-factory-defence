using UnityEngine;

namespace NightFactoryDefence
{
    public sealed class NfdCore : MonoBehaviour
    {
        [SerializeField] float maxHp = 600f;

        public float Hp { get; private set; }
        public float MaxHp => maxHp;

        void Awake()
        {
            Hp = maxHp;
        }

        public void TakeDamage(float damage)
        {
            if (damage <= 0f || Hp <= 0f) return;

            Hp = Mathf.Max(0f, Hp - damage);
            if (Hp <= 0f)
            {
                NfdPlayableSliceController.Instance?.Lose();
            }
        }
    }
}
