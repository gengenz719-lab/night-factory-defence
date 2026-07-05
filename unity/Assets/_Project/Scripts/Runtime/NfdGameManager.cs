using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.SceneManagement;

namespace NightFactoryDefence
{
    // ゲーム進行の「頭脳」。状態(NfdGameState)を所有し、状態を変える唯一の場所。
    //
    // 担当すること:
    // - 敵のスポーン
    // - 敵の名簿(登録/解除)と最寄り敵の検索(弾の当たり判定用)
    // - 撃破カウント・コアダメージ・勝敗判定
    //
    // 担当しないこと:
    // - 描画(HUDは NfdSliceHud が State を読むだけ)
    //
    // プロトタイプの main.js + waves.js の一部に相当する。
    public sealed class NfdGameManager : MonoBehaviour
    {
        [SerializeField] NfdCore core;
        [SerializeField] NfdEnemy enemyPrefab;
        [SerializeField] int enemyCount = 24;
        [SerializeField] float spawnInterval = 0.8f;

        public static NfdGameManager Instance { get; private set; }

        // 状態は外から「読むだけ」。変更はこのクラスのメソッド経由でのみ行う。
        public NfdGameState State { get; } = new NfdGameState();

        readonly List<NfdEnemy> enemies = new();
        float spawnTimer;

        public bool IsRunEnded => State.IsRunEnded;

        void Awake()
        {
            Instance = this;

            // コアの設定値から初期HPを状態にセットする
            State.CoreMaxHp = core != null ? core.MaxHp : 0f;
            State.CoreHp = State.CoreMaxHp;
            State.EnemiesToSpawn = enemyCount;
            State.EnemiesAlive = 0;
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

            if (!State.WaveRunning)
            {
                if (keyboard != null && keyboard.spaceKey.wasPressedThisFrame) StartWave();
                return;
            }

            if (State.IsRunEnded) return;

            spawnTimer -= Time.deltaTime;
            if (State.EnemiesToSpawn > 0 && spawnTimer <= 0f)
            {
                SpawnEnemy();
                State.EnemiesToSpawn--;
                spawnTimer = spawnInterval;
            }

            // 盤面の敵数を状態に反映(HUDはこれを読む)
            State.EnemiesAlive = enemies.Count;

            // 湧き切って全滅したら勝利
            if (State.EnemiesToSpawn <= 0 && enemies.Count == 0)
            {
                State.Result = NfdRunResult.Won;
            }
        }

        // --- 状態を変更するメソッド(唯一の入口) ---

        public void StartWave()
        {
            if (State.WaveRunning || State.IsRunEnded) return;
            State.WaveRunning = true;
            spawnTimer = 0.25f;
        }

        public void AddKill()
        {
            State.Kills++;
        }

        // コアにダメージ。HPが0になったら敗北。
        public void DamageCore(float amount)
        {
            if (amount <= 0f || State.CoreHp <= 0f) return;

            State.CoreHp = Mathf.Max(0f, State.CoreHp - amount);
            if (State.CoreHp <= 0f) State.Result = NfdRunResult.Lost;
        }

        // --- 敵の名簿 ---

        public void RegisterEnemy(NfdEnemy enemy)
        {
            if (enemy != null && !enemies.Contains(enemy)) enemies.Add(enemy);
        }

        public void UnregisterEnemy(NfdEnemy enemy)
        {
            enemies.Remove(enemy);
        }

        // 弾から呼ばれる。半径内で一番近い生存中の敵を返す(いなければnull)。
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
    }
}
