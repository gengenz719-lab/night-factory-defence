// buildings.js - グリッド・建設・撤去・工場の生産処理

// ピクセル座標 → タイル座標
function toGrid(px, py) {
  return { gx: Math.floor(px / CONFIG.TILE), gy: Math.floor(py / CONFIG.TILE) };
}

// タイルが範囲内か
function inGrid(gx, gy) {
  return gx >= 0 && gx < CONFIG.GRID_W && gy >= 0 && gy < CONFIG.GRID_H;
}

// そのタイルに type の建物を置けるか
function canPlace(type, gx, gy) {
  if (!inGrid(gx, gy)) return false;
  const tile = S.grid[gy][gx];
  if (tile.b) return false;                       // すでに建物がある
  const def = CONFIG.BUILDINGS[type];
  if (def.needsOre && !tile.ore) return false;    // 採掘機は鉱床の上だけ
  if (!def.needsOre && tile.ore) return false;    // 鉱床は採掘機専用にしておく
  if (S.iron < def.cost) return false;            // 鉄が足りない

  // プレイヤーと重なる場所には置けない(埋まってしまうので)
  const rx = gx * CONFIG.TILE, ry = gy * CONFIG.TILE;
  const p = S.player;
  if (!p.downed && circleRectHit(p.x, p.y, CONFIG.PLAYER.radius + 2, rx, ry, CONFIG.TILE, CONFIG.TILE)) {
    return false;
  }
  return true;
}

// 建設を試みる(クリック時に呼ばれる)
function tryPlaceBuilding(type, px, py) {
  const { gx, gy } = toGrid(px, py);
  if (!canPlace(type, gx, gy)) return false;

  const def = CONFIG.BUILDINGS[type];
  let hp = def.hp;
  if (type === 'wall') hp = Math.round(def.hp * S.mods.wallHp); // 強化壁レリック対応

  const b = {
    type, gx, gy, w: 1, h: 1,
    hp, maxHp: hp,
    cd: 0,       // タレットの発射クールダウン / 工場の生産タイマー
  };
  S.grid[gy][gx].b = b;
  S.buildings.push(b);
  S.iron -= def.cost;
  updateToolbar();
  return true;
}

// 撤去を試みる(右クリック時)。コストの50%を返金
function tryRemoveBuilding(px, py) {
  const { gx, gy } = toGrid(px, py);
  if (!inGrid(gx, gy)) return;
  const b = S.grid[gy][gx].b;
  if (!b || b.type === 'core') return;  // コアは撤去できない
  removeBuilding(b);
  S.iron += Math.floor(CONFIG.BUILDINGS[b.type].cost * 0.5);
  updateToolbar();
}

// 建物をゲームから取り除く(破壊・撤去の共通処理)
function removeBuilding(b) {
  for (let dy = 0; dy < b.h; dy++) {
    for (let dx = 0; dx < b.w; dx++) {
      S.grid[b.gy + dy][b.gx + dx].b = null;
    }
  }
  const i = S.buildings.indexOf(b);
  if (i >= 0) S.buildings.splice(i, 1);
}

// 建物にダメージを与える。コアが壊れたらゲームオーバー
function damageBuilding(b, dmg) {
  b.hp -= dmg;
  if (b.hp <= 0) {
    if (b.type === 'core') {
      endRun(false);
    } else {
      removeBuilding(b);
    }
  }
}

// 工場(採掘機・加工炉)の毎フレーム処理
function factoryTick(dt) {
  for (const b of S.buildings) {
    if (b.type === 'miner') {
      // 採掘: interval 秒ごとに鉄 +output
      b.cd += dt * S.mods.minerRate;
      const def = CONFIG.BUILDINGS.miner;
      if (b.cd >= def.interval) {
        b.cd -= def.interval;
        S.iron += def.output;
        updateToolbar();
      }
    }
    if (b.type === 'smelter') {
      // 加工: interval 秒ごとに 鉄ironIn → 弾薬(ammoOut + レリック補正)
      const def = CONFIG.BUILDINGS.smelter;
      b.cd += dt;
      if (b.cd >= def.interval) {
        if (S.iron >= def.ironIn) {
          b.cd -= def.interval;
          S.iron -= def.ironIn;
          S.ammo += def.ammoOut + S.mods.smelterBonus;
          updateToolbar();
        } else {
          b.cd = def.interval; // 鉄が来たらすぐ動けるよう待機
        }
      }
    }
  }
}

// 円(キャラクター)と重なっている建物を返す(なければnull)
// 移動の当たり判定と、敵が「進路上の建物を攻撃する」判定に使う
function buildingAt(cx, cy, r) {
  const { gx, gy } = toGrid(cx, cy);
  for (let dy = -1; dy <= 1; dy++) {
    for (let dx = -1; dx <= 1; dx++) {
      const tx = gx + dx, ty = gy + dy;
      if (!inGrid(tx, ty)) continue;
      const b = S.grid[ty][tx].b;
      if (!b) continue;
      if (circleRectHit(cx, cy, r, tx * CONFIG.TILE, ty * CONFIG.TILE, CONFIG.TILE, CONFIG.TILE)) {
        return b;
      }
    }
  }
  return null;
}
