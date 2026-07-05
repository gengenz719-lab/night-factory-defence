using UnityEngine;

namespace NightFactoryDefence
{
    // 敵の「見た目」だけを担当するスクリプト。
    // ゲームロジック(NfdEnemy)とは分離しておく(プロトタイプのstate/ui分離と同じ方針)。
    // やること: 進行方向を向く / よろよろ歩き(千鳥足) / 被弾時の白フラッシュ
    public sealed class NfdEnemyVisual : MonoBehaviour
    {
        [SerializeField] Transform visualRoot;      // 回転させる見た目のルート(子の "visual")
        [SerializeField] float wobbleAngle = 7f;    // 千鳥足の揺れ幅(度)
        [SerializeField] float wobbleSpeed = 7.5f;  // 千鳥足の速さ
        [SerializeField] float turnSpeed = 10f;     // 向き変更の滑らかさ
        [SerializeField] float flashTime = 0.09f;   // 被弾フラッシュの長さ(秒)

        SpriteRenderer[] renderers;
        Color[] baseColors;
        Vector3 lastPos;
        float phase;        // 個体ごとに揺れをずらすための位相
        float facing;       // 現在向いている角度(度)
        float flashTimer;
        float baseScale = 1f; // 体格(敵の種類で変える)

        void Awake()
        {
            if (visualRoot == null) visualRoot = transform.Find("visual");
            renderers = GetComponentsInChildren<SpriteRenderer>();
            baseColors = new Color[renderers.Length];
            for (var i = 0; i < renderers.Length; i++) baseColors[i] = renderers[i].color;

            phase = Random.Range(0f, Mathf.PI * 2f);
            lastPos = transform.position;
            facing = Random.Range(0f, 360f);
        }

        void Update()
        {
            if (visualRoot == null) return;

            // 移動量から進行方向を計算して、その向きにゆっくり回す(スプライトは上向きが正面)
            var delta = transform.position - lastPos;
            lastPos = transform.position;
            if (delta.sqrMagnitude > 0.0000001f)
            {
                var target = Mathf.Atan2(delta.y, delta.x) * Mathf.Rad2Deg - 90f;
                facing = Mathf.LerpAngle(facing, target, turnSpeed * Time.deltaTime);
            }

            // 千鳥足: 左右にゆらゆら + わずかな伸び縮みで「歩いてる感」を出す
            var wobble = Mathf.Sin(Time.time * wobbleSpeed + phase) * wobbleAngle;
            visualRoot.localRotation = Quaternion.Euler(0f, 0f, facing + wobble);
            var step = 1f + Mathf.Abs(Mathf.Sin(Time.time * wobbleSpeed * 0.5f + phase)) * 0.05f;
            visualRoot.localScale = new Vector3((2f - step) * baseScale, step * baseScale, 1f);

            // 被弾フラッシュ: 一瞬白く光らせてから元の色に戻す
            if (flashTimer > 0f)
            {
                flashTimer -= Time.deltaTime;
                var f = Mathf.Clamp01(flashTimer / flashTime);
                for (var i = 0; i < renderers.Length; i++)
                {
                    var white = new Color(3f, 3f, 3f, baseColors[i].a);
                    renderers[i].color = Color.Lerp(baseColors[i], white, f);
                }
            }
        }

        // NfdEnemy.TakeDamage から呼ばれる
        public void OnHit()
        {
            flashTimer = flashTime;
        }

        // NfdEnemy.Init から呼ばれる。体格を設定する。
        public void SetBaseScale(float scale)
        {
            baseScale = scale;
        }

        // 本体の色を染めた後に呼ぶ。フラッシュ復帰用の基準色を取り直す。
        public void RefreshBaseColors()
        {
            if (renderers == null) return;
            for (var i = 0; i < renderers.Length; i++) baseColors[i] = renderers[i].color;
        }
    }
}
