// utils.js - 汎用関数(数学・乱数まわり)

// 2点間の距離
function dist(x1, y1, x2, y2) {
  const dx = x2 - x1, dy = y2 - y1;
  return Math.sqrt(dx * dx + dy * dy);
}

// min〜max の乱数(小数)
function rand(min, max) {
  return min + Math.random() * (max - min);
}

// min〜max の乱数(整数、両端含む)
function randInt(min, max) {
  return Math.floor(rand(min, max + 1));
}

// 配列からランダムに1つ選ぶ
function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

// 配列をシャッフルした新しい配列を返す
function shuffled(arr) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

// 値を min〜max の範囲に収める
function clamp(v, min, max) {
  return Math.max(min, Math.min(max, v));
}

// 円(cx,cy,r) と 矩形(rx,ry,rw,rh) が重なっているか
function circleRectHit(cx, cy, r, rx, ry, rw, rh) {
  const nx = clamp(cx, rx, rx + rw);
  const ny = clamp(cy, ry, ry + rh);
  return dist(cx, cy, nx, ny) < r;
}
