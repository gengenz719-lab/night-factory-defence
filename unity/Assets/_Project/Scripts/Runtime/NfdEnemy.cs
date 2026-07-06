using UnityEngine;

namespace NightFactoryDefence
{
    // 敵1体。ステータスは NfdEnemyData から受け取る(1種のプレハブを作り分ける)。
    public sealed class NfdEnemy : MonoBehaviour
    {
        const float WalkerRadius = 0.28f; // 基準サイズ(スプライトのデフォルト半径)

        NfdCore core;
        NfdEnemyVisual visual;
        float hp;
        float speed;
        float contactDps;   // コア(建物)への毎秒ダメージ
        float contactRange;
        float playerDmg;    // プレイヤーへの接触ダメージ(1回分)
        float aggroRange;   // この距離内のプレイヤーを狙う
        Color deathColor;   // 撃破エフェクトの色
        float deathScale;   // 撃破エフェクトの大きさ

        public bool IsAlive => hp > 0f;

        void Awake()
        {
            visual = GetComponentInChildren<NfdEnemyVisual>();
        }

        // GameManager がスポーン直後に呼ぶ。敵データで見た目とステータスを設定する。
        public void Init(NfdCore targetCore, NfdEnemyData data)
        {
            core = targetCore;
            hp = data.hp;
            speed = data.speed;
            contactDps = data.buildingDps;
            contactRange = 1.0f + data.radius; // コア(約1unit)の縁に触れる距離
            playerDmg = data.playerDmg;
            aggroRange = NfdGameManager.Instance != null ? NfdGameManager.Instance.Config.wave.aggroRange : 2.75f;
            deathColor = data.color;
            deathScale = data.radius / WalkerRadius;

            // 見た目: 本体を敵色に染め、体格を半径に合わせて拡縮
            var body = transform.Find("visual/body");
            if (body != null)
            {
                var sr = body.GetComponent<SpriteRenderer>();
                if (sr != null) sr.color = data.color;
            }
            visual?.SetBaseScale(data.radius / WalkerRadius);
            visual?.RefreshBaseColors();
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

            // 近くにプレイヤーがいれば、コアより優先して襲う(アグロ)
            var player = NfdPlayerController.Instance;
            if (player != null && player.IsAlive)
            {
                var toPlayer = player.transform.position - transform.position;
                var distP = toPlayer.magnitude;
                if (distP <= aggroRange)
                {
                    if (distP <= contactRange) player.TakeContact(playerDmg);
                    else transform.position += toPlayer.normalized * speed * Time.deltaTime;
                    return;
                }
            }

            var toCore = core.transform.position - transform.position;
            var distance = toCore.magnitude;
            if (distance <= contactRange)
            {
                core.TakeDamage(contactDps * Time.deltaTime);
                return;
            }

            var dir = toCore.normalized;

            // 進路の少し先に建物があれば、そこで立ち止まって攻撃する
            var lookAhead = transform.position + dir * contactRange;
            if (NfdBuildGrid.Instance != null && NfdBuildGrid.WorldToTile(lookAhead, out var tx, out var ty))
            {
                var building = NfdBuildGrid.Instance.GetBuilding(tx, ty);
                if (building != null && building.IsAlive)
                {
                    building.TakeDamage(contactDps * Time.deltaTime);
                    return;
                }
            }

            transform.position += dir * speed * Time.deltaTime;
        }

        public void TakeDamage(float damage)
        {
            if (damage <= 0f || !IsAlive) return;

            hp -= damage;
            visual?.OnHit();
            if (hp <= 0f)
            {
                NfdGameManager.Instance?.AddKill();
                NfdFxManager.Instance?.Death(transform.position, deathColor, deathScale); // 撃破エフェクト
                Destroy(gameObject);
            }
        }
    }
}
