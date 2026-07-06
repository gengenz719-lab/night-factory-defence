using UnityEngine;

namespace NightFactoryDefence
{
    // 使い捨てエフェクトの生成窓口。各所(プレイヤー/タレット/弾/敵)はここを呼ぶだけ。
    // プレハブ参照はbuilderが1箇所で配線する。
    public sealed class NfdFxManager : MonoBehaviour
    {
        [SerializeField] NfdOneShotFx muzzleFlashPrefab;
        [SerializeField] NfdOneShotFx hitSparkPrefab;
        [SerializeField] NfdOneShotFx deathPrefab;

        public static NfdFxManager Instance { get; private set; }

        void Awake() { Instance = this; }
        void OnDestroy() { if (Instance == this) Instance = null; }

        // 発砲炎: 銃口に一瞬の光
        public void Muzzle(Vector3 position, Vector3 dir)
        {
            if (muzzleFlashPrefab == null) return;
            var angle = Mathf.Atan2(dir.y, dir.x) * Mathf.Rad2Deg;
            Instantiate(muzzleFlashPrefab, position, Quaternion.Euler(0f, 0f, angle));
        }

        // 着弾スパーク
        public void Hit(Vector3 position)
        {
            if (hitSparkPrefab == null) return;
            Instantiate(hitSparkPrefab, position, Quaternion.identity);
        }

        // 敵の撃破エフェクト(色と大きさを敵に合わせる)
        public void Death(Vector3 position, Color color, float scale)
        {
            if (deathPrefab == null) return;
            var fx = Instantiate(deathPrefab, position, Quaternion.identity);
            fx.Init(color, scale);
        }
    }
}
