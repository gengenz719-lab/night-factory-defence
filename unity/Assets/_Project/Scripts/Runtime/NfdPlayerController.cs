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

        float fireCooldown;

        NfdPlayerData Data => config != null ? config.player : null;

        void Update()
        {
            var game = NfdGameManager.Instance;
            if (game != null && game.IsRunEnded) return;

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
