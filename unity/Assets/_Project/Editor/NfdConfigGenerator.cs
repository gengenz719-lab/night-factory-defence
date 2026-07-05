#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace NightFactoryDefence.Editor
{
    // config.js の数値を焼き込んだ ScriptableObject 一式を自動生成する。
    // 数値を変えたくなったら生成後のアセットをインスペクタで直接いじる(再生成すると上書きされる点に注意)。
    public static class NfdConfigGenerator
    {
        const string Dir = "Assets/_Project/Config";

        [MenuItem("Night Factory Defence/Generate Config Assets")]
        public static void Generate()
        {
            EnsureFolder();

            // --- 敵3種(速度は px/s ÷40) ---
            var walker = Enemy("Enemy_Walker", "ウォーカー", 1, 1, 30f, 42f / 40f, 0.28f, "#7fbf5f", 6f, 8f);
            var runner = Enemy("Enemy_Runner", "ランナー", 2, 2, 20f, 95f / 40f, 0.22f, "#c6e04a", 5f, 6f);
            var tank = Enemy("Enemy_Tank", "タンク", 5, 4, 160f, 26f / 40f, 0.40f, "#3f7a3a", 16f, 20f);

            // --- 建物4種 ---
            var wall = Building("Building_Wall", NfdBuildingKind.Wall, "壁", "1", 5, 120f, "#8a8f98", "ゾンビの進路をふさぐ");

            var turret = Building("Building_Turret", NfdBuildingKind.Turret, "タレット", "2", 25, 80f, "#e0b341", "弾薬を消費して自動攻撃");
            turret.range = 170f / 40f;
            turret.fireRate = 2f;
            turret.dmg = 12f;
            turret.bulletSpeed = 480f / 40f;

            var miner = Building("Building_Miner", NfdBuildingKind.Miner, "採掘機", "3", 20, 60f, "#5fb0d0", "鉱床の上に設置。鉄を自動採取");
            miner.interval = 2f;
            miner.output = 1f;
            miner.needsOre = true;

            var smelter = Building("Building_Smelter", NfdBuildingKind.Smelter, "加工炉", "4", 20, 60f, "#d0705f", "鉄1 → 弾薬2 に加工する");
            smelter.interval = 2f;
            smelter.ironIn = 1f;
            smelter.ammoOut = 2f;

            // --- Wave/経済 ---
            var wave = Asset<NfdWaveData>("WaveData");
            wave.dayTime = 45f;
            wave.waveBudgets = new[] { 10, 15, 22, 30, 42, 38, 52, 68, 85, 120 };
            wave.bossWaveTanks = 4;
            wave.spawnInterval = 0.9f;
            wave.groupMin = 1;
            wave.groupMax = 3;
            wave.startIron = 80;
            wave.startAmmo = 80;
            wave.clearRewardBase = 20;
            wave.clearRewardPerWave = 5;
            wave.aggroRange = 110f / 40f;
            EditorUtility.SetDirty(wave);

            // --- プレイヤー(速度/弾速は px/s ÷40) ---
            var player = Asset<NfdPlayerData>("PlayerData");
            player.maxHp = 100f;
            player.speed = 180f / 40f;
            player.dmg = 15f;
            player.fireRate = 4f;
            player.bulletSpeed = 520f / 40f;
            player.radius = 12f / 40f;
            player.respawnTime = 4f;
            player.hurtCooldown = 0.8f;
            EditorUtility.SetDirty(player);

            // --- レリック10種 ---
            var relics = new[]
            {
                Relic("Relic_Pierce", "pierce", "跳弾", "弾が敵を1体貫通する", NfdRelicEffectType.Pierce, 1f),
                Relic("Relic_Rapid", "rapid", "速射", "攻撃速度 +30%", NfdRelicEffectType.FireRate, 1.3f),
                Relic("Relic_Swift", "swift", "俊足", "移動速度 +20%", NfdRelicEffectType.MoveSpeed, 1.2f),
                Relic("Relic_Tough", "tough", "硬い体", "最大HP +30、全回復", NfdRelicEffectType.MaxHp, 30f),
                Relic("Relic_Gunnery", "gunnery", "砲術", "タレット射程 +25%", NfdRelicEffectType.TurretRange, 1.25f),
                Relic("Relic_Autofire", "autofire", "連射砲", "タレット発射速度 +30%", NfdRelicEffectType.TurretRate, 1.3f),
                Relic("Relic_Hardwall", "hardwall", "強化壁", "壁の最大HP +50%(全回復)", NfdRelicEffectType.WallHp, 1.5f),
                Relic("Relic_Furnace", "furnace", "効率炉", "加工炉の弾薬生産 +1", NfdRelicEffectType.SmelterBonus, 1f),
                Relic("Relic_Bloodmine", "bloodmine", "血の採掘", "採掘速度 +50%", NfdRelicEffectType.MinerRate, 1.5f),
                Relic("Relic_Ammobox", "ammobox", "弾薬箱", "いますぐ弾薬 +80", NfdRelicEffectType.AmmoNow, 80f),
            };

            // --- 全部まとめる GameConfig ---
            var config = Asset<NfdGameConfig>("GameConfig");
            config.wave = wave;
            config.player = player;
            config.enemies = new[] { walker, runner, tank };
            config.buildings = new[] { wall, turret, miner, smelter };
            config.relics = relics;
            EditorUtility.SetDirty(config);

            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log("Generated config assets under " + Dir);
        }

        static NfdEnemyData Enemy(string file, string name, int cost, int minWave, float hp, float speed, float radius, string hex, float dps, float pdmg)
        {
            var e = Asset<NfdEnemyData>(file);
            e.displayName = name;
            e.cost = cost;
            e.minWave = minWave;
            e.hp = hp;
            e.speed = speed;
            e.radius = radius;
            e.color = Hex(hex);
            e.buildingDps = dps;
            e.playerDmg = pdmg;
            EditorUtility.SetDirty(e);
            return e;
        }

        static NfdBuildingData Building(string file, NfdBuildingKind kind, string name, string hotkey, int cost, float hp, string hex, string desc)
        {
            var b = Asset<NfdBuildingData>(file);
            b.kind = kind;
            b.displayName = name;
            b.hotkey = hotkey;
            b.cost = cost;
            b.hp = hp;
            b.color = Hex(hex);
            b.description = desc;
            EditorUtility.SetDirty(b);
            return b;
        }

        static NfdRelicData Relic(string file, string id, string name, string desc, NfdRelicEffectType type, float value)
        {
            var r = Asset<NfdRelicData>(file);
            r.id = id;
            r.displayName = name;
            r.description = desc;
            r.effectType = type;
            r.value = value;
            EditorUtility.SetDirty(r);
            return r;
        }

        // 既存アセットがあれば読み込んで使い回し(GUIDと参照を保つ)、無ければ作る
        static T Asset<T>(string file) where T : ScriptableObject
        {
            var path = Dir + "/" + file + ".asset";
            var existing = AssetDatabase.LoadAssetAtPath<T>(path);
            if (existing != null) return existing;
            var created = ScriptableObject.CreateInstance<T>();
            AssetDatabase.CreateAsset(created, path);
            return created;
        }

        static Color Hex(string hex)
        {
            return ColorUtility.TryParseHtmlString(hex, out var c) ? c : Color.magenta;
        }

        static void EnsureFolder()
        {
            if (!AssetDatabase.IsValidFolder("Assets/_Project")) AssetDatabase.CreateFolder("Assets", "_Project");
            if (!AssetDatabase.IsValidFolder(Dir)) AssetDatabase.CreateFolder("Assets/_Project", "Config");
        }
    }
}
#endif
