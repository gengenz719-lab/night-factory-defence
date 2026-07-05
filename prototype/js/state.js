// state.js - ゲーム状態の定義と初期化
// 描画は ui.js、変更ロジックは各ファイルが担当。ここは「状態の形」を決める場所。

// グローバルなゲーム状態(S = State)
let S = null;

// 新しいランの状態を作る
function newGameState() {
  const state = {
    screen: 'title',   // title | playing | relic | end
    phase: 'day',      // day | night
    paused: false,
    wave: 1,           // 現在のWave(1〜10)
    phaseTimer: CONFIG.DAY_TIME,

    // 資源(プロトタイプでは倉庫は共有・無制限)
    iron: CONFIG.START_IRON,
    ammo: CONFIG.START_AMMO,

    // プレイヤー
    player: {
      x: 0, y: 0,                  // 後で拠点コアの近くに配置
      hp: CONFIG.PLAYER.maxHp,
      maxHp: CONFIG.PLAYER.maxHp,
      fireCd: 0,                   // 次に撃てるまでの残り秒数
      hurtCd: 0,                   // 接触ダメージの無敵時間
      downed: false,               // 倒れているか
      respawnTimer: 0,
    },

    // マップ(grid[y][x] = { ore: 鉱床か, b: 建物への参照 or null })
    grid: [],
    buildings: [],  // 全建物のリスト(コア含む)
    core: null,     // 拠点コアへの参照

    enemies: [],
    bullets: [],
    effects: [],    // ヒット表示などの一時エフェクト

    // 夜のスポーン管理
    spawnQueue: [],  // これから出す敵タイプ名の配列
    spawnTimer: 0,

    // レリック
    relicChoices: [],  // いま提示中の3択
    relicsOwned: [],   // 取得済みレリックid

    // レリックによる補正値(mods = modifiers)
    mods: {
      fireRate: 1,      // プレイヤー攻撃速度倍率
      moveSpeed: 1,     // プレイヤー移動速度倍率
      pierce: 0,        // 弾の貫通数
      turretRange: 1,   // タレット射程倍率
      turretRate: 1,    // タレット発射速度倍率
      wallHp: 1,        // 壁HP倍率
      smelterBonus: 0,  // 加工炉の追加弾薬
      minerRate: 1,     // 採掘速度倍率
    },

    // リザルト用
    result: { win: false, kills: 0 },
  };

  buildMap(state);
  return state;
}

// マップ(グリッド・コア・鉱床)を作る
function buildMap(state) {
  // 空のグリッド
  for (let y = 0; y < CONFIG.GRID_H; y++) {
    const row = [];
    for (let x = 0; x < CONFIG.GRID_W; x++) {
      row.push({ ore: false, b: null });
    }
    state.grid.push(row);
  }

  // 拠点コア(2x2)を中央に置く
  const c = CONFIG.CORE;
  const core = {
    type: 'core', gx: c.gx, gy: c.gy, w: c.size, h: c.size,
    hp: c.hp, maxHp: c.hp,
  };
  for (let dy = 0; dy < c.size; dy++) {
    for (let dx = 0; dx < c.size; dx++) {
      state.grid[c.gy + dy][c.gx + dx].b = core;
    }
  }
  state.buildings.push(core);
  state.core = core;

  // プレイヤーをコアのすぐ下に配置
  state.player.x = (c.gx + 1) * CONFIG.TILE;
  state.player.y = (c.gy + c.size + 1.5) * CONFIG.TILE;

  // 鉱床のかたまりをばらまく(コアから離れた場所に)
  const coreCx = (c.gx + 1) * CONFIG.TILE;
  const coreCy = (c.gy + 1) * CONFIG.TILE;
  let placed = 0;
  let guard = 0; // 無限ループ防止
  while (placed < CONFIG.ORE_PATCHES && guard < 500) {
    guard++;
    const px = randInt(2, CONFIG.GRID_W - 3);
    const py = randInt(2, CONFIG.GRID_H - 3);
    const cx = (px + 0.5) * CONFIG.TILE;
    const cy = (py + 0.5) * CONFIG.TILE;
    // コアの近すぎ・遠すぎを避ける
    const d = dist(cx, cy, coreCx, coreCy);
    if (d < 160 || d > 520) continue;
    if (state.grid[py][px].ore || state.grid[py][px].b) continue;

    // 4〜7タイルのかたまりを作る
    const size = randInt(4, 7);
    let ox = px, oy = py;
    for (let i = 0; i < size; i++) {
      if (oy >= 0 && oy < CONFIG.GRID_H && ox >= 0 && ox < CONFIG.GRID_W && !state.grid[oy][ox].b) {
        state.grid[oy][ox].ore = true;
      }
      // 隣のタイルへランダムに広がる
      if (Math.random() < 0.5) ox += pick([-1, 1]);
      else oy += pick([-1, 1]);
      ox = clamp(ox, 1, CONFIG.GRID_W - 2);
      oy = clamp(oy, 1, CONFIG.GRID_H - 2);
    }
    placed++;
  }
}
