// config.js - 全バランス数値・敵/建物/レリックの定義
// ★ ゲームの数値調整はこのファイルだけ触ればOK ★

const CONFIG = {
  // マップ
  TILE: 40,        // 1タイルのピクセルサイズ
  GRID_W: 30,      // 横タイル数
  GRID_H: 17,      // 縦タイル数
  ORE_PATCHES: 6,  // 鉱床のかたまりの数

  // フェーズ
  DAY_TIME: 45,    // 昼(建設)フェーズの秒数

  // 初期資源
  START_IRON: 80,
  START_AMMO: 80,

  // Waveクリア報酬(鉄): base + wave * perWave
  CLEAR_REWARD: { base: 20, perWave: 5 },

  // プレイヤー
  PLAYER: {
    maxHp: 100,
    speed: 180,          // 移動速度 px/秒
    dmg: 15,             // 弾1発のダメージ
    fireRate: 4,         // 1秒あたりの発射数
    bulletSpeed: 520,
    radius: 12,
    respawnTime: 4,      // 倒れてから復活までの秒数
    hurtCooldown: 0.8,   // 敵の接触ダメージを受ける間隔(秒)
  },

  // 拠点コア(2x2タイル)
  CORE: { hp: 600, gx: 14, gy: 8, size: 2 },

  // 建物の定義
  BUILDINGS: {
    wall: {
      name: '壁', hotkey: '1', cost: 5, hp: 120,
      color: '#8a8f98',
      desc: 'ゾンビの進路をふさぐ',
    },
    turret: {
      name: 'タレット', hotkey: '2', cost: 25, hp: 80,
      color: '#e0b341',
      range: 170, fireRate: 2, dmg: 12, bulletSpeed: 480,
      desc: '弾薬を消費して自動攻撃',
    },
    miner: {
      name: '採掘機', hotkey: '3', cost: 20, hp: 60,
      color: '#5fb0d0',
      interval: 2, output: 1, needsOre: true,
      desc: '鉱床の上に設置。鉄を自動採取',
    },
    smelter: {
      name: '加工炉', hotkey: '4', cost: 20, hp: 60,
      color: '#d0705f',
      interval: 2, ironIn: 1, ammoOut: 2,
      desc: '鉄1 → 弾薬2 に加工する',
    },
  },

  // 敵の定義(cost = Wave予算に対するコスト, minWave = 登場開始Wave)
  ENEMIES: {
    walker: {
      name: 'ウォーカー', cost: 1, minWave: 1,
      hp: 30, speed: 42, radius: 11, color: '#7fbf5f',
      buildingDps: 6,   // 建物への毎秒ダメージ
      playerDmg: 8,     // プレイヤーへの接触ダメージ(1回分)
    },
    runner: {
      name: 'ランナー', cost: 2, minWave: 2,
      hp: 20, speed: 95, radius: 9, color: '#c6e04a',
      buildingDps: 5,
      playerDmg: 6,
    },
    tank: {
      name: 'タンク', cost: 5, minWave: 4,
      hp: 160, speed: 26, radius: 16, color: '#3f7a3a',
      buildingDps: 16,
      playerDmg: 20,
    },
  },

  // Waveごとの敵予算(開発メモの難易度カーブ)
  // Wave6は意図的な休憩Wave、Wave10がボス級
  WAVE_BUDGETS: [10, 15, 22, 30, 42, 38, 52, 68, 85, 120],

  // Wave10で最初に必ず出すタンクの数(山場ギミック)
  BOSS_WAVE_TANKS: 4,

  // スポーン設定
  SPAWN: {
    interval: 0.9,   // 出現の間隔(秒)
    groupMin: 1,     // 1回に出る最小数
    groupMax: 3,     // 1回に出る最大数
  },

  // 敵がプレイヤーを狙い始める距離
  AGGRO_RANGE: 110,

  // レリック定義
  // effects の type は relics.js の applyEffect が解釈する
  RELICS: [
    { id: 'pierce',   name: '跳弾',     desc: '弾が敵を1体貫通する',
      effects: [{ type: 'pierce', value: 1 }] },
    { id: 'rapid',    name: '速射',     desc: '攻撃速度 +30%',
      effects: [{ type: 'fireRate', value: 1.3 }] },
    { id: 'swift',    name: '俊足',     desc: '移動速度 +20%',
      effects: [{ type: 'moveSpeed', value: 1.2 }] },
    { id: 'tough',    name: '硬い体',   desc: '最大HP +30、全回復',
      effects: [{ type: 'maxHp', value: 30 }] },
    { id: 'gunnery',  name: '砲術',     desc: 'タレット射程 +25%',
      effects: [{ type: 'turretRange', value: 1.25 }] },
    { id: 'autofire', name: '連射砲',   desc: 'タレット発射速度 +30%',
      effects: [{ type: 'turretRate', value: 1.3 }] },
    { id: 'hardwall', name: '強化壁',   desc: '壁の最大HP +50%(全回復)',
      effects: [{ type: 'wallHp', value: 1.5 }] },
    { id: 'furnace',  name: '効率炉',   desc: '加工炉の弾薬生産 +1',
      effects: [{ type: 'smelterBonus', value: 1 }] },
    { id: 'bloodmine', name: '血の採掘', desc: '採掘速度 +50%',
      effects: [{ type: 'minerRate', value: 1.5 }] },
    { id: 'ammobox',  name: '弾薬箱',   desc: 'いますぐ弾薬 +80',
      effects: [{ type: 'ammoNow', value: 80 }] },
  ],
};
