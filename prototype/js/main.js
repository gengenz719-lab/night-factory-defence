// main.js - 初期化とゲームループ

let ctx = null;
let lastTime = 0;

function init() {
  const canvas = document.getElementById('game');
  ctx = canvas.getContext('2d');

  setupInput();
  buildToolbar();

  document.getElementById('startBtn').addEventListener('click', startGame);
  document.getElementById('retryBtn').addEventListener('click', () => {
    document.getElementById('endScreen').classList.add('hidden');
    startGame();
  });

  requestAnimationFrame(loop);
}

// 新しいランを開始する
function startGame() {
  S = newGameState();
  S.screen = 'playing';
  Input.buildSel = null;
  document.getElementById('titleScreen').classList.add('hidden');
  document.getElementById('toolbar').classList.remove('hidden');
  updateToolbar();
}

// メインループ
function loop(now) {
  // dt = 前フレームからの経過秒。タブ切替などで大きく飛んだら丸める
  const dt = Math.min((now - lastTime) / 1000, 0.05);
  lastTime = now;

  if (S && S.screen === 'playing' && !S.paused) {
    update(dt);
  }
  if (S) render(ctx);

  requestAnimationFrame(loop);
}

// 1フレーム分のゲーム進行
function update(dt) {
  updatePlayer(dt);
  factoryTick(dt);

  if (S.phase === 'day') {
    updateDay(dt);
  } else {
    updateNight(dt);
    updateEnemies(dt);
  }

  updateTurrets(dt);
  updateBullets(dt);
  updateEffects(dt);
}

window.addEventListener('load', init);
