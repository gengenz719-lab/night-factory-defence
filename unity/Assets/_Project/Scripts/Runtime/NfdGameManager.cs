using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.SceneManagement;

namespace NightFactoryDefence
{
    // ゲーム進行の「頭脳」。状態(NfdGameState)を所有し、状態を変える唯一の場所。
    //
    // 担当すること:
    // - 昼夜フェーズの進行(昼→夜→クリアで次の昼→…→勝敗)
    // - Wave予算からの敵編成と、敵のスポーン
    // - 敵の名簿(登録/解除)と最寄り敵の検索(弾の当たり判定用)
    // - 撃破カウント・コアダメージ・勝敗判定
    //
    // 担当しないこと: 描画(HUDは NfdSliceHud が State を読むだけ)
    //
    // プロトタイプの main.js + waves.js + enemies.js(編成部分)に相当する。
    public sealed class NfdGameManager : MonoBehaviour
    {
        [SerializeField] NfdGameConfig config;
        [SerializeField] NfdCore core;
        [SerializeField] NfdEnemy enemyPrefab; // 1種のプレハブを敵データで作り分ける

        public static NfdGameManager Instance { get; private set; }

        public NfdGameState State { get; } = new NfdGameState();
        public NfdGameConfig Config => config;

        // レリックによる補正。各システム(弾/プレイヤー/タレット/工場)がここを読む。
        public int SmelterBonus { get; private set; }
        public int PierceBonus { get; private set; }
        public float PlayerFireRateMult { get; private set; } = 1f;
        public float PlayerMoveSpeedMult { get; private set; } = 1f;
        public float PlayerMaxHpBonus { get; private set; }
        public float TurretRangeMult { get; private set; } = 1f;
        public float TurretRateMult { get; private set; } = 1f;
        public float WallHpMult { get; private set; } = 1f;
        public float MinerRateMult { get; private set; } = 1f;

        readonly List<NfdEnemy> enemies = new();
        readonly List<NfdEnemyData> spawnQueue = new();
        float spawnTimer;

        NfdWaveData Wave => config.wave;

        public bool IsRunEnded => State.IsRunEnded;

        void Awake()
        {
            Instance = this;

            State.CoreMaxHp = core != null ? core.MaxHp : 0f;
            State.CoreHp = State.CoreMaxHp;
            State.Iron = Wave.startIron;
            State.Ammo = Wave.startAmmo;
            State.WaveNumber = 1;
            State.TotalWaves = Wave.TotalWaves;
            State.Phase = NfdPhase.Day;
            State.PhaseTimer = Wave.dayTime;
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

            if (State.IsRunEnded) return;

            // レリック選択中はゲーム進行を止める(プレイヤーがカードを選ぶまで)
            if (State.ChoosingRelic) return;

            if (State.Phase == NfdPhase.Day) UpdateDay(keyboard);
            else UpdateNight();
        }

        // --- 昼(建設) ---

        void UpdateDay(Keyboard keyboard)
        {
            State.PhaseTimer -= Time.deltaTime;

            var skip = keyboard != null && keyboard.spaceKey.wasPressedThisFrame;
            if (skip || State.PhaseTimer <= 0f)
            {
                BeginNight();
            }
        }

        void BeginNight()
        {
            State.Phase = NfdPhase.Night;
            BuildSpawnQueue(State.WaveNumber);
            State.EnemiesToSpawn = spawnQueue.Count;
            State.EnemiesAlive = 0;
            spawnTimer = 0.25f;
        }

        // --- 夜(防衛) ---

        void UpdateNight()
        {
            spawnTimer -= Time.deltaTime;
            if (spawnQueue.Count > 0 && spawnTimer <= 0f)
            {
                var group = Random.Range(Wave.groupMin, Wave.groupMax + 1);
                for (var i = 0; i < group && spawnQueue.Count > 0; i++) SpawnNext();
                spawnTimer = Wave.spawnInterval;
            }

            State.EnemiesToSpawn = spawnQueue.Count;
            State.EnemiesAlive = enemies.Count;

            // 湧き切って全滅したらWaveクリア
            if (spawnQueue.Count == 0 && enemies.Count == 0)
            {
                WaveCleared();
            }
        }

        void WaveCleared()
        {
            // Waveクリア報酬(鉄)
            State.Iron += Wave.clearRewardBase + State.WaveNumber * Wave.clearRewardPerWave;

            if (State.WaveNumber >= State.TotalWaves)
            {
                State.Result = NfdRunResult.Won;
                return;
            }

            OfferRelics();
        }

        // Waveクリア後に未取得のレリックから3枚を提示する
        void OfferRelics()
        {
            var pool = config.relics != null
                ? config.relics.Where(r => r != null && !State.OwnedRelicIds.Contains(r.id)).ToList()
                : new System.Collections.Generic.List<NfdRelicData>();

            // シャッフルして先頭3枚
            for (var i = pool.Count - 1; i > 0; i--)
            {
                var j = Random.Range(0, i + 1);
                (pool[i], pool[j]) = (pool[j], pool[i]);
            }

            State.RelicChoices.Clear();
            for (var i = 0; i < pool.Count && i < 3; i++) State.RelicChoices.Add(pool[i]);

            if (State.RelicChoices.Count == 0)
            {
                // 全部取得済みなら選択を飛ばして次の昼へ
                AdvanceToNextDay();
                return;
            }

            State.ChoosingRelic = true;
        }

        // 3択のカードを選んだときに呼ばれる(HUDのボタンから)
        public void ChooseRelic(int index)
        {
            if (!State.ChoosingRelic) return;

            if (index >= 0 && index < State.RelicChoices.Count)
            {
                var relic = State.RelicChoices[index];
                ApplyRelic(relic);
                State.OwnedRelicIds.Add(relic.id);
            }

            State.ChoosingRelic = false;
            State.RelicChoices.Clear();
            AdvanceToNextDay();
        }

        void AdvanceToNextDay()
        {
            State.WaveNumber++;
            State.Phase = NfdPhase.Day;
            State.PhaseTimer = Wave.dayTime;
        }

        // レリックの効果を適用する(relics.js の applyEffect に相当)
        void ApplyRelic(NfdRelicData relic)
        {
            switch (relic.effectType)
            {
                case NfdRelicEffectType.Pierce:
                    PierceBonus += Mathf.RoundToInt(relic.value);
                    break;
                case NfdRelicEffectType.FireRate:
                    PlayerFireRateMult *= relic.value;
                    break;
                case NfdRelicEffectType.MoveSpeed:
                    PlayerMoveSpeedMult *= relic.value;
                    break;
                case NfdRelicEffectType.MaxHp:
                    PlayerMaxHpBonus += relic.value; // 反映はPhase E(プレイヤーHP)
                    break;
                case NfdRelicEffectType.TurretRange:
                    TurretRangeMult *= relic.value;
                    break;
                case NfdRelicEffectType.TurretRate:
                    TurretRateMult *= relic.value;
                    break;
                case NfdRelicEffectType.WallHp:
                    WallHpMult *= relic.value;
                    break;
                case NfdRelicEffectType.SmelterBonus:
                    SmelterBonus += Mathf.RoundToInt(relic.value);
                    break;
                case NfdRelicEffectType.MinerRate:
                    MinerRateMult *= relic.value;
                    break;
                case NfdRelicEffectType.AmmoNow:
                    AddAmmo(Mathf.RoundToInt(relic.value));
                    break;
            }
        }

        // Wave予算から敵の編成を組む(enemies.js の予算制を移植)
        void BuildSpawnQueue(int wave)
        {
            spawnQueue.Clear();
            var index = Mathf.Clamp(wave - 1, 0, Wave.waveBudgets.Length - 1);
            var budget = Wave.waveBudgets[index];

            // このWaveで出せる敵(minWave考慮)
            var pool = config.enemies.Where(e => e != null && e.minWave <= wave).ToList();
            if (pool.Count == 0) return;

            // 最終Wave: まずタンク(最高コストの敵)を確定で数体
            if (wave >= State.TotalWaves)
            {
                var tank = pool.OrderByDescending(e => e.cost).First();
                for (var i = 0; i < Wave.bossWaveTanks; i++)
                {
                    spawnQueue.Add(tank);
                    budget -= tank.cost;
                }
            }

            // 残り予算をランダムな敵で埋める
            var fill = new List<NfdEnemyData>();
            var guard = 0;
            while (budget > 0 && guard++ < 2000)
            {
                var affordable = pool.Where(e => e.cost <= budget).ToList();
                if (affordable.Count == 0) break;
                var pick = affordable[Random.Range(0, affordable.Count)];
                fill.Add(pick);
                budget -= pick.cost;
            }

            // 埋めた分だけシャッフル(確定タンクは先頭のまま残す)
            for (var i = fill.Count - 1; i > 0; i--)
            {
                var j = Random.Range(0, i + 1);
                (fill[i], fill[j]) = (fill[j], fill[i]);
            }
            spawnQueue.AddRange(fill);
        }

        void SpawnNext()
        {
            if (enemyPrefab == null || core == null || spawnQueue.Count == 0) return;

            var data = spawnQueue[0];
            spawnQueue.RemoveAt(0);

            var side = Random.Range(0, 4);
            Vector3 pos = side switch
            {
                0 => new Vector3(Random.Range(-13.5f, 13.5f), 7.4f, 0f),
                1 => new Vector3(Random.Range(-13.5f, 13.5f), -7.4f, 0f),
                2 => new Vector3(-13.8f, Random.Range(-6.8f, 6.8f), 0f),
                _ => new Vector3(13.8f, Random.Range(-6.8f, 6.8f), 0f),
            };

            var enemy = Instantiate(enemyPrefab, pos, Quaternion.identity);
            enemy.Init(core, data);
        }

        // --- 状態を変更するメソッド(唯一の入口) ---

        // 昼をスキップして夜を始める(UIボタン等からも呼べるように公開)
        public void StartWave()
        {
            if (State.Phase == NfdPhase.Day && !State.IsRunEnded) BeginNight();
        }

        public void AddKill()
        {
            State.Kills++;
        }

        // プレイヤーが自分の状態をHUD表示用にミラーする
        public void ReportPlayer(float hp, float maxHp, bool down, float respawn)
        {
            State.PlayerHp = hp;
            State.PlayerMaxHp = maxHp;
            State.PlayerDown = down;
            State.PlayerRespawn = respawn;
        }

        // --- 資源(鉄・弾薬) ---

        public bool TrySpendIron(int amount)
        {
            if (amount < 0 || State.Iron < amount) return false;
            State.Iron -= amount;
            return true;
        }

        public void AddIron(int amount)
        {
            if (amount > 0) State.Iron += amount;
        }

        public bool TrySpendAmmo(int amount)
        {
            if (amount < 0 || State.Ammo < amount) return false;
            State.Ammo -= amount;
            return true;
        }

        public void AddAmmo(int amount)
        {
            if (amount > 0) State.Ammo += amount;
        }

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
    }
}
