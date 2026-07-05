using UnityEngine;
using UnityEngine.InputSystem;

namespace NightFactoryDefence
{
    public sealed class NfdPlayerController : MonoBehaviour
    {
        [SerializeField] float moveSpeed = 5.2f;
        [SerializeField] float fireRate = 5.5f;
        [SerializeField] NfdBullet bulletPrefab;
        [SerializeField] Transform muzzle;
        [SerializeField] Camera worldCamera;

        float fireCooldown;

        void Update()
        {
            var game = NfdGameManager.Instance;
            if (game != null && game.IsRunEnded) return;

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

            fireCooldown = 1f / fireRate;
            var bullet = Instantiate(bulletPrefab, muzzle.position, Quaternion.identity);
            bullet.Fire(direction.sqrMagnitude > 0.0001f ? direction : transform.up);
        }

        static Vector3 ClampToArena(Vector3 position)
        {
            position.x = Mathf.Clamp(position.x, -14.1f, 14.1f);
            position.y = Mathf.Clamp(position.y, -7.6f, 7.6f);
            return position;
        }
    }
}
