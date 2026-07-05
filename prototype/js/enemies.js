// enemies.js - 敵AI・Wave予算からの敵編成生成・スポーン

// Wave番号から敵の編成(スポーン待ち行列)を作る
// 開発メモの「敵コスト制 + Waveごとの予算表」方式
function buildWaveQueue(wave) {
  let budget = CONFIG.WAVE_BUDGETS[wave - 1];
  const queue = [];

  // Wave10(ボスWave)は最初にタンクを確定で出す
  if (wave === 10) {
    for (let i = 0; i < CONFIG.BOSS_WAVE_TANKS; i++) {
      queue.push('tank');
      budget -= CONFIG.ENEMIES.tank.cost;
    }
  }

  // このWaveで出せる敵タイプ
  const available = Object.keys(CONFIG.ENEMIES)
    .filter((t) => CONFIG.ENEMIES[t].minWave <= wave);

  // 予算がなくなるまでランダムに選ぶ
  let guard = 0;
  while (budget > 0 && guard < 1000) {
    guard++;
    const affordable = available.filter((t) => CONFIG.ENEMIES[t].cost <= budget);
    if (affordable.length === 0) break;
    const type = pick(affordable);
    queue.push(type);
    budget -= CONFIG.ENEMIES[type].cost;
  }

  return shuffled(queue);
}

// 夜のあいだ、待ち行列から敵を少しずつ出す
function spawnTick(dt) {
  if (S.spawnQueue.length === 0) return;
  S.spawnTimer -= dt;
  if (S.spawnTimer > 0) return;

  S.spawnTimer = CONFIG.SPAWN.interval;
  const count = randInt(CONFIG.SPAWN.groupMin, CONFIG.SPAWN.groupMax);
  for (let i = 0; i < count && S.spawnQueue.length > 0; i++) {
    spawnEnemy(S.spawnQueue.pop());
  }
}

// マップの外周ランダムな位置に敵を1体出す
function spawnEnemy(type) {
  const def = CONFIG.ENEMIES[type];
  const W = CONFIG.GRID_W * CONFIG.TILE;
  const H = CONFIG.GRID_H * CONFIG.TILE;
  const side = randInt(0, 3); // 0=上 1=下 2=左 3=右
  let x, y;
  if (side === 0) { x = rand(0, W); y = 4; }
  else if (side === 1) { x = rand(0, W); y = H - 4; }
  else if (side === 2) { x = 4; y = rand(0, H); }
  else { x = W - 4; y = rand(0, H); }

  S.enemies.push({
    type, x, y,
    hp: def.hp, maxHp: def.hp,
  });
}

// 敵の毎フレーム処理(移動・攻撃)
function updateEnemies(dt) {
  const coreCx = (S.core.gx + S.core.w / 2) * CONFIG.TILE;
  const coreCy = (S.core.gy + S.core.h / 2) * CONFIG.TILE;
  const p = S.player;

  for (const e of S.enemies) {
    const def = CONFIG.ENEMIES[e.type];

    // 目標: 基本はコア。プレイヤーが近くにいればプレイヤーを狙う
    let tx = coreCx, ty = coreCy;
    const playerNear = !p.downed && dist(e.x, e.y, p.x, p.y) < CONFIG.AGGRO_RANGE;
    if (playerNear) { tx = p.x; ty = p.y; }

    // プレイヤーに接触したら攻撃
    if (!p.downed && dist(e.x, e.y, p.x, p.y) < def.radius + CONFIG.PLAYER.radius + 2) {
      hurtPlayer(def.playerDmg);
    }

    // 目標へ向かって移動
    const d = dist(e.x, e.y, tx, ty);
    if (d > 1) {
      const nx = e.x + ((tx - e.x) / d) * def.speed * dt;
      const ny = e.y + ((ty - e.y) / d) * def.speed * dt;

      // 進路上に建物があれば、移動せずそれを攻撃する
      const blocking = buildingAt(nx, ny, def.radius);
      if (blocking) {
        damageBuilding(blocking, def.buildingDps * dt);
      } else {
        e.x = nx;
        e.y = ny;
      }
    }
  }
}

// 敵にダメージ。倒したら true を返す
function damageEnemy(e, dmg) {
  e.hp -= dmg;
  addEffect(e.x, e.y, '#ffdd88');
  if (e.hp <= 0) {
    const i = S.enemies.indexOf(e);
    if (i >= 0) S.enemies.splice(i, 1);
    S.result.kills++;
    addEffect(e.x, e.y, CONFIG.ENEMIES[e.type].color);
    return true;
  }
  return false;
}
