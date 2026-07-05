// relics.js - レリックの3択提示と効果の適用

// まだ持っていないレリックから3つ選んで提示する
function offerRelics() {
  const notOwned = CONFIG.RELICS.filter((r) => !S.relicsOwned.includes(r.id));
  // 候補が足りないときは「弾薬箱」(何度取ってもよい即時効果)で埋める
  const repeatable = CONFIG.RELICS.filter(
    (r) => r.id === 'ammobox' && !notOwned.includes(r)
  );
  const pool = notOwned.length >= 3 ? notOwned : notOwned.concat(repeatable);

  S.relicChoices = shuffled(pool).slice(0, 3);
  S.screen = 'relic';
  showRelicScreen();
}

// プレイヤーがレリックを選んだとき
function chooseRelic(relic) {
  if (!S.relicsOwned.includes(relic.id)) S.relicsOwned.push(relic.id);
  for (const ef of relic.effects) applyEffect(ef);
  hideRelicScreen();
  startNextDay();
}

// 効果を1つ適用する。新しい効果タイプはここに追加する
function applyEffect(ef) {
  const m = S.mods;
  switch (ef.type) {
    case 'pierce':       m.pierce += ef.value; break;
    case 'fireRate':     m.fireRate *= ef.value; break;
    case 'moveSpeed':    m.moveSpeed *= ef.value; break;
    case 'turretRange':  m.turretRange *= ef.value; break;
    case 'turretRate':   m.turretRate *= ef.value; break;
    case 'smelterBonus': m.smelterBonus += ef.value; break;
    case 'minerRate':    m.minerRate *= ef.value; break;

    case 'maxHp': // 最大HP増加+全回復
      S.player.maxHp += ef.value;
      S.player.hp = S.player.maxHp;
      break;

    case 'ammoNow': // 即時弾薬
      S.ammo += ef.value;
      break;

    case 'wallHp': // 既存の壁も強化して全回復
      m.wallHp *= ef.value;
      for (const b of S.buildings) {
        if (b.type === 'wall') {
          b.maxHp = Math.round(CONFIG.BUILDINGS.wall.hp * m.wallHp);
          b.hp = b.maxHp;
        }
      }
      break;

    default:
      console.warn('未知のレリック効果:', ef.type);
  }
}
