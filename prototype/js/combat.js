// combat.js - 弾丸・タレット・当たり判定・エフェクト

// プレイヤーの弾を発射
function firePlayerBullet(fromX, fromY, aimX, aimY) {
  fireBullet(fromX, fromY, aimX, aimY, {
    dmg: CONFIG.PLAYER.dmg,
    speed: CONFIG.PLAYER.bulletSpeed,
    pierce: S.mods.pierce,
    color: '#ffe9a0',
  });
}

// 汎用の弾発射
function fireBullet(fromX, fromY, aimX, aimY, opt) {
  const d = dist(fromX, fromY, aimX, aimY);
  if (d < 1) return;
  S.bullets.push({
    x: fromX, y: fromY,
    vx: ((aimX - fromX) / d) * opt.speed,
    vy: ((aimY - fromY) / d) * opt.speed,
    dmg: opt.dmg,
    pierce: opt.pierce || 0,  // あと何体貫通できるか
    color: opt.color,
    life: 1.2,                // 秒。飛びすぎ防止
    hit: [],                  // すでに当てた敵(貫通用)
  });
}

// タレットの自動射撃
function updateTurrets(dt) {
  const def = CONFIG.BUILDINGS.turret;
  const range = def.range * S.mods.turretRange;

  for (const b of S.buildings) {
    if (b.type !== 'turret') continue;
    b.cd -= dt;
    if (b.cd > 0 || S.ammo <= 0) continue;

    // 射程内で一番近い敵を探す
    const cx = (b.gx + 0.5) * CONFIG.TILE;
    const cy = (b.gy + 0.5) * CONFIG.TILE;
    let best = null, bestD = range;
    for (const e of S.enemies) {
      const d = dist(cx, cy, e.x, e.y);
      if (d < bestD) { best = e; bestD = d; }
    }
    if (!best) continue;

    b.cd = 1 / (def.fireRate * S.mods.turretRate);
    S.ammo -= 1;
    updateToolbar();
    fireBullet(cx, cy, best.x, best.y, {
      dmg: def.dmg,
      speed: def.bulletSpeed,
      color: '#9fd7ff',
    });
  }
}

// 弾の移動と当たり判定
function updateBullets(dt) {
  const W = CONFIG.GRID_W * CONFIG.TILE;
  const H = CONFIG.GRID_H * CONFIG.TILE;

  for (let i = S.bullets.length - 1; i >= 0; i--) {
    const bl = S.bullets[i];
    bl.x += bl.vx * dt;
    bl.y += bl.vy * dt;
    bl.life -= dt;

    // 寿命切れ・画面外
    if (bl.life <= 0 || bl.x < 0 || bl.x > W || bl.y < 0 || bl.y > H) {
      S.bullets.splice(i, 1);
      continue;
    }

    // 敵に命中?
    for (const e of S.enemies) {
      if (bl.hit.includes(e)) continue; // 貫通で一度当てた敵はスキップ
      if (dist(bl.x, bl.y, e.x, e.y) < CONFIG.ENEMIES[e.type].radius + 4) {
        damageEnemy(e, bl.dmg);
        if (bl.pierce > 0) {
          bl.pierce--;
          bl.hit.push(e);
        } else {
          S.bullets.splice(i, 1);
        }
        break;
      }
    }
  }
}

// ヒット表示などの一時エフェクトを追加
function addEffect(x, y, color) {
  S.effects.push({ x, y, color, life: 0.25, maxLife: 0.25 });
}

function updateEffects(dt) {
  for (let i = S.effects.length - 1; i >= 0; i--) {
    S.effects[i].life -= dt;
    if (S.effects[i].life <= 0) S.effects.splice(i, 1);
  }
}
