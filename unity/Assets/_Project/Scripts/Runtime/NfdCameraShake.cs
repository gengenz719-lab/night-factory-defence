using UnityEngine;

namespace NightFactoryDefence
{
    // カメラの揺れ。trauma(0..1)を溜めて、その2乗に比例して揺らし、時間で回復する。
    // コア被弾などで AddTrauma を呼ぶ。連続被弾中は自然に揺れ続け、止むと収まる。
    public sealed class NfdCameraShake : MonoBehaviour
    {
        [SerializeField] float maxOffset = 0.35f; // 最大移動(unit)
        [SerializeField] float maxAngle = 2.2f;   // 最大回転(度)
        [SerializeField] float recovery = 1.4f;   // 1秒あたりのtrauma回復量

        public static NfdCameraShake Instance { get; private set; }

        float trauma;
        Vector3 basePos;

        void Awake()
        {
            Instance = this;
            basePos = transform.localPosition;
        }

        void OnDestroy()
        {
            if (Instance == this) Instance = null;
        }

        public void AddTrauma(float amount)
        {
            trauma = Mathf.Clamp01(trauma + amount);
        }

        void LateUpdate()
        {
            if (trauma <= 0f)
            {
                transform.localPosition = basePos;
                transform.localRotation = Quaternion.identity;
                return;
            }

            var shake = trauma * trauma; // 小さい揺れは控えめ、大きい揺れは派手に
            var ox = maxOffset * shake * (Random.value * 2f - 1f);
            var oy = maxOffset * shake * (Random.value * 2f - 1f);
            transform.localPosition = basePos + new Vector3(ox, oy, 0f);
            transform.localRotation = Quaternion.Euler(0f, 0f, maxAngle * shake * (Random.value * 2f - 1f));

            trauma = Mathf.Max(0f, trauma - recovery * Time.deltaTime);
        }
    }
}
