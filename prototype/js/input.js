// input.js - キーボード・マウス入力
// 「何が押されているか」を記録するだけ。実際の処理は各ファイルが参照する。

const Input = {
  keys: new Set(),      // 押下中のキー(小文字)
  mouseX: 600,          // キャンバス座標でのマウス位置
  mouseY: 340,
  shooting: false,      // 左ボタン押しっぱなしか
  buildSel: null,       // 選択中の建物タイプ('wall'など) or null
};

// キャンバス上のマウス座標に変換(CSSで拡縮されていても正しくなるように)
function toCanvasPos(e) {
  const canvas = document.getElementById('game');
  const rect = canvas.getBoundingClientRect();
  const scaleX = canvas.width / rect.width;
  const scaleY = canvas.height / rect.height;
  return {
    x: (e.clientX - rect.left) * scaleX,
    y: (e.clientY - rect.top) * scaleY,
  };
}

function setupInput() {
  const canvas = document.getElementById('game');

  // ---- キーボード ----
  window.addEventListener('keydown', (e) => {
    const key = e.key.toLowerCase();
    Input.keys.add(key);

    // 矢印キーやSpaceでページがスクロールしないようにする
    if (['arrowup', 'arrowdown', 'arrowleft', 'arrowright', ' '].includes(key)) {
      e.preventDefault();
    }

    if (!S || S.screen !== 'playing') return;

    // 建物選択(1〜4)
    for (const [type, def] of Object.entries(CONFIG.BUILDINGS)) {
      if (key === def.hotkey) selectBuild(type);
    }
    if (key === 'escape') selectBuild(null);

    // 昼フェーズスキップ
    if (key === ' ' && S.phase === 'day' && !S.paused) {
      e.preventDefault();
      startNight();
    }

    // ポーズ
    if (key === 'p') S.paused = !S.paused;
  });

  window.addEventListener('keyup', (e) => {
    Input.keys.delete(e.key.toLowerCase());
  });

  // ---- マウス ----
  canvas.addEventListener('mousemove', (e) => {
    const p = toCanvasPos(e);
    Input.mouseX = p.x;
    Input.mouseY = p.y;
  });

  canvas.addEventListener('mousedown', (e) => {
    if (!S || S.screen !== 'playing' || S.paused) return;
    const p = toCanvasPos(e);
    Input.mouseX = p.x;
    Input.mouseY = p.y;

    if (e.button === 0) {
      if (Input.buildSel) {
        // 建設モード中は左クリック=設置
        tryPlaceBuilding(Input.buildSel, p.x, p.y);
      } else {
        Input.shooting = true;
      }
    }
    if (e.button === 2) {
      // 右クリック=撤去(50%返金)
      tryRemoveBuilding(p.x, p.y);
    }
  });

  window.addEventListener('mouseup', (e) => {
    if (e.button === 0) Input.shooting = false;
  });

  // 右クリックメニューを出さない
  canvas.addEventListener('contextmenu', (e) => e.preventDefault());
}

// 建設対象を選択する(nullで解除)。ツールバーの見た目も更新
function selectBuild(type) {
  Input.buildSel = (Input.buildSel === type) ? null : type;
  updateToolbar();
}

// WASD / 矢印キーから移動方向(-1〜1)を得る
function moveAxis() {
  let dx = 0, dy = 0;
  if (Input.keys.has('w') || Input.keys.has('arrowup')) dy -= 1;
  if (Input.keys.has('s') || Input.keys.has('arrowdown')) dy += 1;
  if (Input.keys.has('a') || Input.keys.has('arrowleft')) dx -= 1;
  if (Input.keys.has('d') || Input.keys.has('arrowright')) dx += 1;
  // 斜め移動が速くなりすぎないように正規化
  if (dx !== 0 && dy !== 0) {
    const inv = 1 / Math.sqrt(2);
    dx *= inv; dy *= inv;
  }
  return { dx, dy };
}
