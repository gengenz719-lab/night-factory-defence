using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.SceneManagement;

namespace NightFactoryDefence
{
    public sealed class NfdPlayableSliceController : MonoBehaviour
    {
        [SerializeField] NfdCore core;
        [SerializeField] NfdEnemy enemyPrefab;
        [SerializeField] int enemyCount = 18;
        [SerializeField] float spawnInterval = 0.85f;

        readonly List<NfdEnemy> enemies = new();
        float spawnTimer;
        int remainingToSpawn;
        int kills;
        bool waveRunning;
        bool won;
        bool lost;

        public static NfdPlayableSliceController Instance { get; private set; }
        public bool IsRunEnded => won || lost;

        void Awake()
        {
            Instance = this;
            remainingToSpawn = enemyCount;
        }

        void OnDestroy()
        {
            if (Instance == this) Instance = null;
        }

        void Update()
        {
            var keyboard = Keyboard.current;
            if (keyboard != null && keyboard.rKey.wasPressedThisFrame)
            {
                SceneManager.LoadScene(SceneManager.GetActiveScene().name);
                return;
            }

            if (!waveRunning)
            {
                if (keyboard != null && keyboard.spaceKey.wasPressedThisFrame)
                {
                    StartWave();
                }
                return;
            }

            if (IsRunEnded) return;

            spawnTimer -= Time.deltaTime;
            if (remainingToSpawn > 0 && spawnTimer <= 0f)
            {
                SpawnEnemy();
                remainingToSpawn--;
                spawnTimer = spawnInterval;
            }

            if (remainingToSpawn <= 0 && enemies.Count == 0)
            {
                won = true;
            }
        }

        public void RegisterEnemy(NfdEnemy enemy)
        {
            if (enemy != null && !enemies.Contains(enemy)) enemies.Add(enemy);
        }

        public void UnregisterEnemy(NfdEnemy enemy)
        {
            enemies.Remove(enemy);
        }

        public NfdEnemy FindClosestEnemy(Vector3 position, float radius)
        {
            NfdEnemy best = null;
            var bestDistance = radius;
            for (var i = enemies.Count - 1; i >= 0; i--)
            {
                var enemy = enemies[i];
                if (enemy == null || !enemy.IsAlive)
                {
                    enemies.RemoveAt(i);
                    continue;
                }

                var distance = Vector3.Distance(position, enemy.transform.position);
                if (distance <= bestDistance)
                {
                    best = enemy;
                    bestDistance = distance;
                }
            }
            return best;
        }

        public void AddKill()
        {
            kills++;
        }

        public void Lose()
        {
            lost = true;
        }

        public void StartWave()
        {
            if (waveRunning || IsRunEnded) return;

            waveRunning = true;
            spawnTimer = 0.25f;
        }

        void SpawnEnemy()
        {
            if (enemyPrefab == null || core == null) return;

            var side = Random.Range(0, 4);
            Vector3 pos = side switch
            {
                0 => new Vector3(Random.Range(-13.5f, 13.5f), 7.4f, 0f),
                1 => new Vector3(Random.Range(-13.5f, 13.5f), -7.4f, 0f),
                2 => new Vector3(-13.8f, Random.Range(-6.8f, 6.8f), 0f),
                _ => new Vector3(13.8f, Random.Range(-6.8f, 6.8f), 0f),
            };

            var enemy = Instantiate(enemyPrefab, pos, Quaternion.identity);
            enemy.Init(core, Random.Range(0.9f, 1.35f), Random.Range(0.85f, 1.2f));
        }

        void OnGUI()
        {
            var style = new GUIStyle(GUI.skin.label)
            {
                fontSize = 22,
                normal = { textColor = Color.white }
            };
            var small = new GUIStyle(style) { fontSize = 16 };

            GUI.Box(new Rect(14, 14, 430, 126), GUIContent.none);
            GUI.Label(new Rect(28, 24, 390, 28), "Night Factory Defence - Unity Playable Slice", style);
            GUI.Label(new Rect(28, 58, 390, 24), $"Core HP: {Mathf.CeilToInt(core.Hp)} / {Mathf.CeilToInt(core.MaxHp)}", small);
            GUI.Label(new Rect(28, 82, 390, 24), $"Enemies: {enemies.Count + remainingToSpawn}   Kills: {kills}", small);
            GUI.Label(new Rect(28, 106, 390, 24), "Move: WASD / Aim: Mouse / Shoot: Left Click / Restart: R", small);

            if (!waveRunning && !IsRunEnded)
            {
                CenterMessage("Press SPACE to start the test wave");
            }
            else if (won)
            {
                CenterMessage("WAVE CLEAR - Press R to restart");
            }
            else if (lost)
            {
                CenterMessage("CORE DESTROYED - Press R to restart");
            }
        }

        static void CenterMessage(string message)
        {
            var style = new GUIStyle(GUI.skin.label)
            {
                alignment = TextAnchor.MiddleCenter,
                fontSize = 32,
                normal = { textColor = new Color(1f, 0.84f, 0.28f) }
            };
            GUI.Label(new Rect(0, Screen.height * 0.46f, Screen.width, 70), message, style);
        }
    }
}
