// ui.js - 画面描画(Canvas)とメニュー(DOM)の操作
// ゲームの状態は読むだけ。状態の変更は各ロジックファイルが行う。

// ===== DOM: ツールバー =====

// 起動時に一度だけ建設ボタンを作る
function buildToolbar() {
  const bar = document.getElementById('toolbar');
  bar.innerHTML = '';
  for (const [type, def] of Object.entries(CONFIG.BUILDINGS)) {
    const btn = document.createElement('button');
    btn.className = 'tool-btn';
    btn.id = 'tool-' + type;
    btn.innerHTML = `[${def.hotkey}] ${def.name}<span class="t-cost">鉄${def.cost} - ${def.desc}</span>`;
    btn.addEventListener('click', () => selectBuild(type));
    bar.appendChild(btn);
  }
}

// 選択状態・資源不足の見た目を更新する(資源が動いたときに呼ばれる)
function updateToolbar() {
  if (!S) return;
  for (const [type, def] of Object.entries(CONFIG.BUILDINGS)) {
    const btn = document.getElementById('tool-' + type);
    if (!btn) continue;
    btn.classList.toggle('selected', Input.buildSel === type);
    btn.classList.toggle('disabled', S.iron < def.cost);
  }
}

// ===== DOM: オーバーレイ =====

function showRelicScreen() {
  document.getElementById('relicTitle').textContent =
    `Wave ${S.wave} クリア! レリックを1つ選べ`;
  const cards = document.getElementById('relicCards');
  cards.innerHTML = '';
  for (const relic of S.relicChoices) {
    const card = document.createElement('div');
    card.className = 'relic-card';
    card.innerHTML = `<div class="r-name">${relic.name}</div><div class="r-desc">${relic.desc}</div>`;
    card.addEventListener('click', () => chooseRelic(relic));
    cards.appendChild(card);
  }
  document.getElementById('relicScreen').classList.remove('hidden');
}

function hideRelicScreen() {
  document.getElementById('relicScreen').classList.add('hidden');
}

function showEndScreen(win) {
  document.getElementById('endTitle').textContent = win ? '勝利!' : '拠点コア破壊…';
  document.getElementById('endDetail').textContent =
    `到達: Wave ${S.wave} / 撃破数: ${S.result.kills} / 取得レリック: ${S.relicsOwned.length}`;
  document.getElementById('endScreen').classList.remove('hidden');
}

// ===== Canvas 描画 =====

function render(ctx) {
  const T = CONFIG.TILE;
  const W = CONFIG.GRID_W * T;
  const H = CONFIG.GRID_H * T;

  // 背景(夜は暗く)
  ctx.fillStyle = (S && S.phase === 'night') ? '#10131c' : '#1a2030';
  ctx.fillRect(0, 0, W, H);
  if (!S) return;

  // 鉱床タイル
  for (let y = 0; y < CONFIG.GRID_H; y++) {
    for (let x = 0; x < CONFIG.GRID_W; x++) {
      if (S.grid[y][x].ore) {
        ctx.fillStyle = '#22354a';
        ctx.fillRect(x * T, y * T, T, T);
        ctx.fillStyle = '#5fb0d0';
        ctx.beginPath();
        ctx.arc(x * T + T / 2, y * T + T / 2, 4, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }

  // 薄いグリッド線(建設モード中だけ濃くする)
  ctx.strokeStyle = Input.buildSel ? 'rgba(255,255,255,0.12)' : 'rgba(255,255,255,0.03)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  for (let x = 0; x <= CONFIG.GRID_W; x++) { ctx.moveTo(x * T, 0); ctx.lineTo(x * T, H); }
  for (let y = 0; y <= CONFIG.GRID_H; y++) { ctx.moveTo(0, y * T); ctx.lineTo(W, y * T); }
  ctx.stroke();

  // 建物
  for (const b of S.buildings) drawBuilding(ctx, b);

  // 敵
  for (const e of S.enemies) {
    const def = CONFIG.ENEMIES[e.type];
    ctx.fillStyle = def.color;
    ctx.beginPath();
    ctx.arc(e.x, e.y, def.radius, 0, Math.PI * 2);
    ctx.fill();
    // 目(進行方向っぽさは出さず簡易に)
    ctx.fillStyle = '#20241c';
    ctx.beginPath();
    ctx.arc(e.x - 3, e.y - 2, 1.8, 0, Math.PI * 2);
    ctx.arc(e.x + 3, e.y - 2, 1.8, 0, Math.PI * 2);
    ctx.fill();
    if (e.hp < e.maxHp) drawHpBar(ctx, e.x, e.y - def.radius - 7, 24, e.hp / e.maxHp, '#7fbf5f');
  }

  // 弾
  for (const bl of S.bullets) {
    ctx.fillStyle = bl.color;
    ctx.beginPath();
    ctx.arc(bl.x, bl.y, 3.5, 0, Math.PI * 2);
    ctx.fill();
  }

  // プレイヤー
  const p = S.player;
  if (!p.downed) {
    // 照準線(うっすら)
    ctx.strokeStyle = 'rgba(255,233,160,0.15)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(p.x, p.y);
    ctx.lineTo(Input.mouseX, Input.mouseY);
    ctx.stroke();

    ctx.fillStyle = '#7fd0ff';
    ctx.beginPath();
    ctx.arc(p.x, p.y, CONFIG.PLAYER.radius, 0, Math.PI * 2);
    ctx.fill();
    // 銃口
    const d = dist(p.x, p.y, Input.mouseX, Input.mouseY) || 1;
    ctx.strokeStyle = '#e6e8ee';
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(p.x, p.y);
    ctx.lineTo(p.x + ((Input.mouseX - p.x) / d) * 16, p.y + ((Input.mouseY - p.y) / d) * 16);
    ctx.stroke();

    drawHpBar(ctx, p.x, p.y - CONFIG.PLAYER.radius - 8, 30, p.hp / p.maxHp, '#7fd0ff');
  } else {
    // 倒れている表示
    ctx.fillStyle = '#e6e8ee';
    ctx.font = '14px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(`復活まで ${Math.ceil(p.respawnTimer)} 秒…`, W / 2, H / 2 - 40);
  }

  // エフェクト
  for (const ef of S.effects) {
    ctx.globalAlpha = ef.life / ef.maxLife;
    ctx.fillStyle = ef.color;
    ctx.beginPath();
    ctx.arc(ef.x, ef.y, 8 * (1 - ef.life / ef.maxLife) + 3, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1;
  }

  // 建設ゴースト(置けるか色で表示)
  if (Input.buildSel && S.screen === 'playing') {
    const { gx, gy } = toGrid(Input.mouseX, Input.mouseY);
    if (inGrid(gx, gy)) {
      const ok = canPlace(Input.buildSel, gx, gy);
      ctx.fillStyle = ok ? 'rgba(120,255,120,0.3)' : 'rgba(255,80,80,0.3)';
      ctx.fillRect(gx * T, gy * T, T, T);
      // タレットは射程円も見せる
      if (Input.buildSel === 'turret') {
        ctx.strokeStyle = 'rgba(224,179,65,0.35)';
        ctx.beginPath();
        ctx.arc(gx * T + T / 2, gy * T + T / 2,
          CONFIG.BUILDINGS.turret.range * S.mods.turretRange, 0, Math.PI * 2);
        ctx.stroke();
      }
    }
  }

  drawHud(ctx);

  // ポーズ表示
  if (S.paused) {
    ctx.fillStyle = 'rgba(0,0,0,0.5)';
    ctx.fillRect(0, 0, W, H);
    ctx.fillStyle = '#ffd75e';
    ctx.font = 'bold 36px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('PAUSE (Pで再開)', W / 2, H / 2);
  }
}

// 建物1つの描画
function drawBuilding(ctx, b) {
  const T = CONFIG.TILE;
  const x = b.gx * T, y = b.gy * T, w = b.w * T, h = b.h * T;

  if (b.type === 'core') {
    ctx.fillStyle = '#2c2412';
    ctx.fillRect(x + 2, y + 2, w - 4, h - 4);
    ctx.fillStyle = '#ffd75e';
    ctx.beginPath();
    ctx.moveTo(x + w / 2, y + 10);
    ctx.lineTo(x + w - 10, y + h / 2);
    ctx.lineTo(x + w / 2, y + h - 10);
    ctx.lineTo(x + 10, y + h / 2);
    ctx.closePath();
    ctx.fill();
  } else {
    const def = CONFIG.BUILDINGS[b.type];
    ctx.fillStyle = '#242b3a';
    ctx.fillRect(x + 2, y + 2, w - 4, h - 4);
    ctx.fillStyle = def.color;
    if (b.type === 'wall') {
      ctx.fillRect(x + 4, y + 4, w - 8, h - 8);
    } else if (b.type === 'turret') {
      ctx.beginPath();
      ctx.arc(x + T / 2, y + T / 2, 11, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillRect(x + T / 2 - 2, y + 4, 4, 12); // 砲身
    } else if (b.type === 'miner') {
      ctx.fillRect(x + 6, y + 6, w - 12, h - 12);
      ctx.fillStyle = '#163040';
      ctx.beginPath();
      ctx.moveTo(x + T / 2, y + h - 8);
      ctx.lineTo(x + T / 2 - 7, y + 12);
      ctx.lineTo(x + T / 2 + 7, y + 12);
      ctx.closePath();
      ctx.fill();
    } else if (b.type === 'smelter') {
      ctx.fillRect(x + 6, y + 6, w - 12, h - 12);
      ctx.fillStyle = '#ffb35e';
      ctx.beginPath();
      ctx.moveTo(x + T / 2, y + 10);
      ctx.lineTo(x + T / 2 + 7, y + h - 12);
      ctx.lineTo(x + T / 2 - 7, y + h - 12);
      ctx.closePath();
      ctx.fill();
    }
  }

  // 減っているときだけHPバー
  if (b.hp < b.maxHp) {
    drawHpBar(ctx, x + w / 2, y - 5, w - 8,
      b.hp / b.maxHp, b.type === 'core' ? '#ffd75e' : '#c3c9d6');
  }
}

// HPバー(cx中心, 上端y)
function drawHpBar(ctx, cx, y, width, ratio, color) {
  ratio = clamp(ratio, 0, 1);
  ctx.fillStyle = 'rgba(0,0,0,0.6)';
  ctx.fillRect(cx - width / 2, y, width, 4);
  ctx.fillStyle = color;
  ctx.fillRect(cx - width / 2, y, width * ratio, 4);
}

// 画面上部のHUD(工業HUDテーマ)
function drawHud(ctx) {
  const W = CONFIG.GRID_W * CONFIG.TILE;

  // 背景バー + 下端のオレンジ・アクセント線
  ctx.fillStyle = 'rgba(6,8,12,0.86)';
  ctx.fillRect(0, 0, W, 34);
  ctx.fillStyle = '#ff6a1a';
  ctx.fillRect(0, 33, W, 2);

  ctx.font = 'bold 15px "Segoe UI", sans-serif';
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';

  // Wave / フェーズ(昼=明るいオレンジ / 夜=濃いオレンジ)
  ctx.fillStyle = (S.phase === 'day') ? '#ff8c3a' : '#ff6a1a';
  let phaseText;
  if (S.phase === 'day') {
    phaseText = `☀ 昼(建設) 残り ${Math.ceil(S.phaseTimer)} 秒 - Spaceで夜を開始`;
  } else {
    const remain = S.spawnQueue.length + S.enemies.length;
    phaseText = `☾ 夜(防衛) 残り敵 ${remain}`;
  }
  ctx.fillText(`WAVE ${S.wave}/${CONFIG.WAVE_BUDGETS.length}   ${phaseText}`, 12, 17);

  // 資源(シアン)
  ctx.fillStyle = '#3fd2ff';
  ctx.textAlign = 'right';
  ctx.fillText(`鉄 ${S.iron}    弾薬 ${S.ammo}`, W - 188, 17);

  // コアHP
  ctx.fillStyle = '#e8ecf2';
  ctx.fillText('コア', W - 150, 17);
  const coreRatio = S.core.hp / S.core.maxHp;
  drawHpBar(ctx, W - 75, 13, 130, coreRatio, coreRatio < 0.3 ? '#ff3b30' : '#ff6a1a');
  ctx.textBaseline = 'alphabetic';
}
