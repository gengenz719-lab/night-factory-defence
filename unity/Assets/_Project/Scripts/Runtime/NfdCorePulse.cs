using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace NightFactoryDefence
{
    // コアの鼓動。中心スプライトを脈打たせ、コアの光を明滅させる。
    // HPが低いほど速く強く脈打ち、「危機」を体で伝える。
    public sealed class NfdCorePulse : MonoBehaviour
    {
        [SerializeField] Transform pulseTarget; // 脈打たせる中心スプライト(cyan heart)
        [SerializeField] string coreLightName = "Core reactor light";

        Vector3 baseScale = Vector3.one;
        Light2D coreLight;
        float baseLightIntensity = 1.1f;

        void Awake()
        {
            if (pulseTarget != null) baseScale = pulseTarget.localScale;

            var go = GameObject.Find(coreLightName);
            if (go != null)
            {
                coreLight = go.GetComponent<Light2D>();
                if (coreLight != null) baseLightIntensity = coreLight.intensity;
            }
        }

        void Update()
        {
            var mgr = NfdGameManager.Instance;
            var lowHp = 0f;
            if (mgr != null && mgr.State.CoreMaxHp > 0f)
            {
                lowHp = 1f - Mathf.Clamp01(mgr.State.CoreHp / mgr.State.CoreMaxHp);
            }

            var speed = Mathf.Lerp(2.2f, 7f, lowHp);   // 低HPほど速い鼓動
            var amp = Mathf.Lerp(0.08f, 0.2f, lowHp);  // 低HPほど大きい鼓動
            var pulse = 0.5f + 0.5f * Mathf.Sin(Time.time * speed);

            if (pulseTarget != null)
            {
                pulseTarget.localScale = baseScale * (1f + pulse * amp);
            }
            if (coreLight != null)
            {
                coreLight.intensity = baseLightIntensity * Mathf.Lerp(0.85f, 1.35f, pulse);
            }
        }
    }
}
