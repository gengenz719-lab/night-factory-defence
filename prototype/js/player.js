// player.js - プレイヤーの移動・射撃・被弾・リスポーン

function updatePlayer(dt) {
  const p = S.player;

  // ---- 倒れているとき: リスポーン待ち ----
  if (p.downed) {
    p.respawnTimer -= dt;
    if (p.respawnTimer <= 0) {
      p.downed = false;
      p.hp = Math.round(p.maxHp * 0.6); // 6割回復で復活
      // コアの下に戻る
      p.x = (CONFIG.CORE.gx + 1) * CONFIG.TILE;
      p.y = (CONFIG.CORE.gy + CONFIG.CORE.size + 1.5) * CONFIG.TILE;
    }
    return;
  }

  // ---- 移動 ----
  const axis = moveAxis();
  const speed = CONFIG.PLAYER.speed * S.mods.moveSpeed;
  moveWithCollision(p, axis.dx * speed * dt, axis.dy * speed * dt, CONFIG.PLAYER.radius);

  // マップ外に出ない
  p.x = clamp(p.x, CONFIG.PLAYER.radius, CONFIG.GRID_W * CONFIG.TILE - CONFIG.PLAYER.radius);
  p.y = clamp(p.y, CONFIG.PLAYER.radius, CONFIG.GRID_H * CONFIG.TILE - CONFIG.PLAYER.radius);

  // ---- 射撃 ----
  p.fireCd -= dt;
  p.hurtCd -= dt;
  if (Input.shooting && !Input.buildSel && p.fireCd <= 0 && S.ammo > 0) {
    const rate = CONFIG.PLAYER.fireRate * S.mods.fireRate;
    p.fireCd = 1 / rate;
    S.ammo -= 1;
    firePlayerBullet(p.x, p.y, Input.mouseX, Input.mouseY);
    updateToolbar();
  }
}

// 建物にめり込まないように移動する(X軸とY軸を別々に試す)
function moveWithCollision(obj, dx, dy, radius) {
  obj.x += dx;
  if (buildingAt(obj.x, obj.y, radius)) obj.x -= dx;
  obj.y += dy;
  if (buildingAt(obj.x, obj.y, radius)) obj.y -= dy;
}

// プレイヤーが敵からダメージを受ける(接触ダメージには無敵時間あり)
function hurtPlayer(dmg) {
  const p = S.player;
  if (p.downed || p.hurtCd > 0) return;
  p.hurtCd = CONFIG.PLAYER.hurtCooldown;
  p.hp -= dmg;
  addEffect(p.x, p.y, '#ff5555');
  if (p.hp <= 0) {
    p.hp = 0;
    p.downed = true;
    p.respawnTimer = CONFIG.PLAYER.respawnTime;
  }
}
