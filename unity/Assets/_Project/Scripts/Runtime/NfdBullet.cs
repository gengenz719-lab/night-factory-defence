using UnityEngine;

namespace NightFactoryDefence
{
    public sealed class NfdBullet : MonoBehaviour
    {
        [SerializeField] float speed = 11f;
        [SerializeField] float damage = 20f;
        [SerializeField] float lifeSeconds = 1.4f;
        [SerializeField] float hitRadius = 0.34f;

        Vector3 velocity;

        public void Fire(Vector3 direction)
        {
            velocity = direction.normalized * speed;
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

            var controller = NfdPlayableSliceController.Instance;
            if (controller == null) return;

            var enemy = controller.FindClosestEnemy(transform.position, hitRadius);
            if (enemy == null) return;

            enemy.TakeDamage(damage);
            Destroy(gameObject);
        }
    }
}
