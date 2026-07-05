// waves.js - 昼夜フェーズとWave進行の管理

// 昼フェーズの毎フレーム処理
function updateDay(dt) {
  S.phaseTimer -= dt;
  if (S.phaseTimer <= 0) startNight();
}

// 夜を開始する(昼スキップ時も呼ばれる)
function startNight() {
  if (S.phase === 'night') return;
  S.phase = 'night';
  S.spawnQueue = buildWaveQueue(S.wave);
  S.spawnTimer = 1.0; // 最初の1体まで少しだけ間を置く
  selectBuild(null);  // 建設モード解除
  updateToolbar();
}

// 夜フェーズの毎フレーム処理
function updateNight(dt) {
  spawnTick(dt);

  // 全部出し切って全滅させたらWaveクリア
  if (S.spawnQueue.length === 0 && S.enemies.length === 0) {
    onWaveCleared();
  }
}

// Waveクリア時の処理
function onWaveCleared() {
  if (S.wave >= CONFIG.WAVE_BUDGETS.length) {
    endRun(true); // 10Wave生存 → 勝利
    return;
  }
  // クリア報酬の鉄
  S.iron += CONFIG.CLEAR_REWARD.base + S.wave * CONFIG.CLEAR_REWARD.perWave;
  offerRelics(); // レリック3択へ(選んだら startNextDay が呼ばれる)
}

// レリック選択後、次のWaveの昼を始める
function startNextDay() {
  S.wave++;
  S.phase = 'day';
  S.phaseTimer = CONFIG.DAY_TIME;
  S.screen = 'playing';

  // 昼のはじめにプレイヤー全回復
  S.player.hp = S.player.maxHp;
  S.player.downed = false;

  S.bullets = [];
  updateToolbar();
}

// ランの終了(win=trueで勝利)
function endRun(win) {
  S.result.win = win;
  S.screen = 'end';
  showEndScreen(win);
}
