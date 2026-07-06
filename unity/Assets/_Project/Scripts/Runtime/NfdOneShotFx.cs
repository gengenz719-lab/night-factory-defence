using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace NightFactoryDefence
{
    // 一瞬光って消える使い捨てエフェクト(マズルフラッシュ・着弾スパークなど)。
    // スプライトの拡大+フェード、あれば Light2D の減光も行い、寿命が来たら自分を消す。
    // ゲームロジックには一切影響しない見た目専用。
    public sealed class NfdOneShotFx : MonoBehaviour
    {
        [SerializeField] float life = 0.09f;
        [SerializeField] float startScale = 0.5f;
        [SerializeField] float endScale = 1.15f;

        SpriteRenderer[] sprites;
        Color[] spriteBaseColors;
        Light2D light2d;
        float lightBaseIntensity;
        float timer;
        float scaleMul = 1f;

        void Awake()
        {
            sprites = GetComponentsInChildren<SpriteRenderer>();
            spriteBaseColors = new Color[sprites.Length];
            for (var i = 0; i < sprites.Length; i++) spriteBaseColors[i] = sprites[i].color;

            light2d = GetComponentInChildren<Light2D>();
            if (light2d != null) lightBaseIntensity = light2d.intensity;
        }

        // 生成側から色と大きさを差し替えたいとき用(死亡エフェクトの色分けなど)
        public void Init(Color tint, float scaleMultiplier)
        {
            scaleMul = scaleMultiplier;
            if (sprites == null) return;
            for (var i = 0; i < sprites.Length; i++)
            {
                var c = tint; c.a = spriteBaseColors[i].a;
                sprites[i].color = c;
                spriteBaseColors[i] = c;
            }
        }

        void Update()
        {
            timer += Time.deltaTime;
            var k = Mathf.Clamp01(timer / life);

            var s = Mathf.Lerp(startScale, endScale, k) * scaleMul;
            transform.localScale = new Vector3(s, s, 1f);

            var fade = 1f - k;
            for (var i = 0; i < sprites.Length; i++)
            {
                var c = spriteBaseColors[i]; c.a = spriteBaseColors[i].a * fade;
                sprites[i].color = c;
            }
            if (light2d != null) light2d.intensity = lightBaseIntensity * fade;

            if (timer >= life) Destroy(gameObject);
        }
    }
}
