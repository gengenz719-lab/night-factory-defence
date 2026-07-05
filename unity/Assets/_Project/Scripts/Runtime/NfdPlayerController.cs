using UnityEngine;
using UnityEngine.InputSystem;

namespace NightFactoryDefence
{
    public sealed class NfdPlayerController : MonoBehaviour
    {
        [SerializeField] NfdGameConfig config;
        [SerializeField] NfdBullet bulletPrefab;
        [SerializeField] Transform muzzle;
        [SerializeField] Camera worldCamera;

        public static NfdPlayerController Instance { get; private set; }

        float fireCooldown;
        float hp;
        float maxHp;
        float hurtTimer;      // 接触ダメージの間隔
        float respawnTimer;   // 復活までの残り
        float appliedMaxHpBonus = -1f; // レリックでmaxHpが増えたら全回復するための記録
        Vector3 spawnPoint;
        SpriteRenderer[] renderers;

        public bool IsDown => respawnTimer > 0f;
        public bool IsAlive => !IsDown;

        NfdPlayerData Data => config != null ? config.player : null;

        void Awake()
        {
            Instance = this;
            spawnPoint = transform.position;
            renderers = GetComponentsInChildren<SpriteRenderer>();
            var data = Data;
            maxHp = data != null ? data.maxHp : 100f;
            hp = maxHp;
        }

        void OnDestroy()
        {
            if (Instance == this) Instance = null;
        }

        void Update()
        {
            var game = NfdGameManager.Instance;
            RefreshMaxHp(game);

            if (hurtTimer > 0f) hurtTimer -= Time.deltaTime;

            // 倒れている間はリスポーン待ち
            if (IsDown)
            {
                respawnTimer -= Time.deltaTime;
                if (respawnTimer <= 0f) Respawn();
                game?.ReportPlayer(hp, maxHp, IsDown, Mathf.Max(0f, respawnTimer));
                return;
            }

            if (game != null && game.IsRunEnded)
            {
                game.ReportPlayer(hp, maxHp, IsDown, 0f);
                return;
            }

            var data = Data;
            var moveSpeed = (data != null ? data.speed : 4.5f) * MoveSpeedMult(game); // レリック「俊足」

            var move = ReadMove();
            transform.position += new Vector3(move.x, move.y, 0f) * moveSpeed * Time.deltaTime;
            transform.position = ClampToArena(transform.position);

            var aimDirection = ReadAimDirection();
            if (aimDirection.sqrMagnitude > 0.0001f)
            {
                transform.up = aimDirection;
            }

            fireCooldown -= Time.deltaTime;
            if (Mouse.current != null && Mouse.current.leftButton.isPressed && fireCooldown <= 0f)
            {
                Shoot(aimDirection);
            }

            game?.ReportPlayer(hp, maxHp, IsDown, 0f);
        }

        // レリック「硬い体」で最大HPが増えたら全回復する
        void RefreshMaxHp(NfdGameManager game)
        {
            var data = Data;
            var baseMax = data != null ? data.maxHp : 100f;
            var bonus = game != null ? game.PlayerMaxHpBonus : 0f;
            if (!Mathf.Approximately(bonus, appliedMaxHpBonus))
            {
                appliedMaxHpBonus = bonus;
                maxHp = baseMax + bonus;
                hp = maxHp; // 全回復
            }
        }

        // 敵の接触ダメージを受ける(NfdEnemyから呼ばれる)。hurtCooldownで頻度を制限。
        public void TakeContact(float dmg)
        {
            if (IsDown || hurtTimer > 0f) return;

            var data = Data;
            hurtTimer = data != null ? data.hurtCooldown : 0.8f;
            hp -= dmg;
            if (hp <= 0f) Down();
        }

        void Down()
        {
            hp = 0f;
            var data = Data;
            respawnTimer = data != null ? data.respawnTime : 4f;
            SetVisible(false);
        }

        void Respawn()
        {
            respawnTimer = 0f;
            hp = maxHp;
            transform.position = spawnPoint;
            SetVisible(true);
        }

        void SetVisible(bool visible)
        {
            if (renderers == null) return;
            foreach (var r in renderers) if (r != null) r.enabled = visible;
        }

        Vector2 ReadMove()
        {
            var keyboard = Keyboard.current;
            if (keyboard == null) return Vector2.zero;

            var move = Vector2.zero;
            if (keyboard.wKey.isPressed || keyboard.upArrowKey.isPressed) move.y += 1f;
            if (keyboard.sKey.isPressed || keyboard.downArrowKey.isPressed) move.y -= 1f;
            if (keyboard.aKey.isPressed || keyboard.leftArrowKey.isPressed) move.x -= 1f;
            if (keyboard.dKey.isPressed || keyboard.rightArrowKey.isPressed) move.x += 1f;
            return move.sqrMagnitude > 1f ? move.normalized : move;
        }

        Vector3 ReadAimDirection()
        {
            if (worldCamera == null || Mouse.current == null) return transform.up;

            var mousePos = Mouse.current.position.ReadValue();
            var world = worldCamera.ScreenToWorldPoint(new Vector3(mousePos.x, mousePos.y, -worldCamera.transform.position.z));
            var direction = world - transform.position;
            direction.z = 0f;
            return direction.sqrMagnitude > 0.0001f ? direction.normalized : transform.up;
        }

        void Shoot(Vector3 direction)
        {
            if (bulletPrefab == null || muzzle == null) return;

            var data = Data;
            var manager = NfdGameManager.Instance;
            var rateMult = manager != null ? manager.PlayerFireRateMult : 1f; // レリック「速射」
            var fireRate = (data != null ? data.fireRate : 4f) * rateMult;
            fireCooldown = 1f / fireRate;

            // 弾薬を1消費できたときだけ撃つ(弾薬0では撃てない=工場の動機)
            if (manager != null && !manager.TrySpendAmmo(1)) return;

            var dmg = data != null ? data.dmg : 15f;
            var speed = data != null ? data.bulletSpeed : 13f;
            var pierce = manager != null ? manager.PierceBonus : 0; // レリック「跳弾」
            var bullet = Instantiate(bulletPrefab, muzzle.position, Quaternion.identity);
            bullet.Fire(direction.sqrMagnitude > 0.0001f ? direction : transform.up, dmg, speed, pierce);
        }

        static float MoveSpeedMult(NfdGameManager manager)
        {
            return manager != null ? manager.PlayerMoveSpeedMult : 1f;
        }

        static Vector3 ClampToArena(Vector3 position)
        {
            position.x = Mathf.Clamp(position.x, -14.1f, 14.1f);
            position.y = Mathf.Clamp(position.y, -7.6f, 7.6f);
            return position;
        }
    }
}
