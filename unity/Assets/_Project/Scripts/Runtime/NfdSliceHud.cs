using UnityEngine;

namespace NightFactoryDefence
{
    // 縦スライス用の最小HUD。状態(NfdGameState)を「読むだけ」で、状態は変えない。
    // モックの配置(左上=フェーズ/コア、上中央=Wave)に寄せた暫定表示。
    // Phase F で UI Toolkit 製の本UIに差し替える。
    public sealed class NfdSliceHud : MonoBehaviour
    {
        void OnGUI()
        {
            var manager = NfdGameManager.Instance;
            if (manager == null) return;
            var state = manager.State;

            DrawDangerVignette(state); // 最背面(HUDの下)
            DrawTopLeft(state);
            DrawTopCenter(state);
            DrawBottomLeft(state);
            DrawBuildBar();
            DrawCenterMessage(state);
            DrawRelicChoice(state); // 最前面
        }

        // Waveクリア後のレリック3択(カードをクリックで選ぶ)
        static void DrawRelicChoice(NfdGameState state)
        {
            if (!state.ChoosingRelic || state.RelicChoices.Count == 0) return;

            // 暗幕
            var prev = GUI.color;
            GUI.color = new Color(0f, 0f, 0f, 0.72f);
            GUI.DrawTexture(new Rect(0, 0, Screen.width, Screen.height), Texture2D.whiteTexture);
            GUI.color = prev;

            var title = new GUIStyle(GUI.skin.label) { fontSize = 26, fontStyle = FontStyle.Bold, alignment = TextAnchor.MiddleCenter, normal = { textColor = new Color(1f, 0.84f, 0.28f) } };
            GUI.Label(new Rect(0, Screen.height * 0.2f, Screen.width, 40), "レリックを選べ", title);

            var count = state.RelicChoices.Count;
            const float cardW = 220f, cardH = 150f, gap = 24f;
            var totalW = count * cardW + (count - 1) * gap;
            var x0 = (Screen.width - totalW) * 0.5f;
            var y = Screen.height * 0.32f;

            var nameStyle = new GUIStyle(GUI.skin.label) { fontSize = 18, fontStyle = FontStyle.Bold, alignment = TextAnchor.UpperCenter, normal = { textColor = Color.white }, wordWrap = true };
            var descStyle = new GUIStyle(GUI.skin.label) { fontSize = 14, alignment = TextAnchor.UpperCenter, normal = { textColor = new Color(0.8f, 0.85f, 0.9f) }, wordWrap = true };

            for (var i = 0; i < count; i++)
            {
                var relic = state.RelicChoices[i];
                var rect = new Rect(x0 + i * (cardW + gap), y, cardW, cardH);
                if (GUI.Button(rect, GUIContent.none))
                {
                    NfdGameManager.Instance.ChooseRelic(i);
                }
                GUI.Label(new Rect(rect.x + 10, rect.y + 18, rect.width - 20, 50), relic.displayName, nameStyle);
                GUI.Label(new Rect(rect.x + 12, rect.y + 66, rect.width - 24, 74), relic.description, descStyle);
            }
        }

        // 下中央: 建設ホットバー([1]〜[4]・コスト・選択中ハイライト・鉄不足はグレー)
        static void DrawBuildBar()
        {
            var manager = NfdGameManager.Instance;
            var controller = manager != null ? Object.FindAnyObjectByType<NfdBuildController>() : null;
            if (controller == null || controller.Selected == null) return;
            var config = manager.Config;
            if (config == null || config.buildings == null) return;

            var count = config.buildings.Length;
            const float slotW = 116f, slotH = 58f, gap = 8f;
            var totalW = count * slotW + (count - 1) * gap;
            var x0 = (Screen.width - totalW) * 0.5f;
            var y = Screen.height - slotH - 12f;

            var name = new GUIStyle(GUI.skin.label) { fontSize = 14, fontStyle = FontStyle.Bold, normal = { textColor = Color.white } };
            var cost = new GUIStyle(GUI.skin.label) { fontSize = 13, alignment = TextAnchor.LowerRight };

            for (var i = 0; i < count; i++)
            {
                var b = config.buildings[i];
                var rect = new Rect(x0 + i * (slotW + gap), y, slotW, slotH);
                var selected = i == controller.SelectedIndex;
                var affordable = manager.State.Iron >= b.cost;

                // 背景
                var prev = GUI.color;
                GUI.color = selected ? new Color(0.25f, 0.7f, 0.9f, 0.85f) : new Color(0f, 0f, 0f, 0.6f);
                GUI.DrawTexture(rect, Texture2D.whiteTexture);
                GUI.color = prev;

                name.normal.textColor = affordable ? Color.white : new Color(0.5f, 0.5f, 0.5f);
                GUI.Label(new Rect(rect.x + 8, rect.y + 6, rect.width - 12, 20), $"[{i + 1}] {b.displayName}", name);
                cost.normal.textColor = affordable ? new Color(0.9f, 0.85f, 0.5f) : new Color(0.6f, 0.4f, 0.4f);
                GUI.Label(new Rect(rect.x + 6, rect.y + rect.height - 22, rect.width - 12, 18), $"鉄 {b.cost}", cost);
            }

            // 操作ヒント
            var hint = new GUIStyle(GUI.skin.label) { fontSize = 12, alignment = TextAnchor.MiddleCenter, normal = { textColor = new Color(0.7f, 0.75f, 0.8f) } };
            GUI.Label(new Rect(x0, y - 20, totalW, 18), "左クリック=設置 / 右クリック=撤去(50%返金)", hint);
        }

        // 左上: フェーズ・残り時間・コアHPバー
        static void DrawTopLeft(NfdGameState state)
        {
            GUI.Box(new Rect(14, 14, 250, 96), GUIContent.none);

            var title = new GUIStyle(GUI.skin.label) { fontSize = 20, fontStyle = FontStyle.Bold, normal = { textColor = Color.white } };
            var small = new GUIStyle(GUI.skin.label) { fontSize = 14, normal = { textColor = new Color(0.8f, 0.85f, 0.9f) } };

            var phaseText = state.Phase == NfdPhase.Day ? $"昼(建設)  残り {Mathf.CeilToInt(state.PhaseTimer)}s" : "夜(防衛)";
            GUI.Label(new Rect(26, 22, 230, 26), phaseText, title);

            GUI.Label(new Rect(26, 52, 230, 20), $"コア {Mathf.CeilToInt(state.CoreHp)} / {Mathf.CeilToInt(state.CoreMaxHp)}", small);

            // コアHPバー
            var frac = state.CoreMaxHp > 0f ? Mathf.Clamp01(state.CoreHp / state.CoreMaxHp) : 0f;
            var barBg = new Rect(26, 74, 224, 14);
            DrawBar(barBg, frac, new Color(0.25f, 0.85f, 0.55f));
        }

        // 上中央: Wave n/10・残敵数
        static void DrawTopCenter(NfdGameState state)
        {
            var w = 260f;
            var x = (Screen.width - w) * 0.5f;
            GUI.Box(new Rect(x, 14, w, 60), GUIContent.none);

            var big = new GUIStyle(GUI.skin.label) { fontSize = 20, fontStyle = FontStyle.Bold, alignment = TextAnchor.MiddleCenter, normal = { textColor = Color.white } };
            var small = new GUIStyle(GUI.skin.label) { fontSize = 14, alignment = TextAnchor.MiddleCenter, normal = { textColor = new Color(1f, 0.7f, 0.4f) } };

            GUI.Label(new Rect(x, 20, w, 26), $"WAVE {state.WaveNumber} / {state.TotalWaves}", big);
            var sub = state.IsNight ? $"残り敵 {state.EnemiesRemaining}   撃破 {state.Kills}" : "建設フェーズ  (Space で夜を開始)";
            GUI.Label(new Rect(x, 46, w, 22), sub, small);
        }

        // 左下: 資源 + プレイヤーHP
        static void DrawBottomLeft(NfdGameState state)
        {
            var y = Screen.height - 104f;
            GUI.Box(new Rect(14, y, 210, 90), GUIContent.none);
            var s = new GUIStyle(GUI.skin.label) { fontSize = 16, normal = { textColor = Color.white } };
            GUI.Label(new Rect(26, y + 6, 190, 22), $"鉄   {state.Iron}", s);
            GUI.Label(new Rect(26, y + 28, 190, 22), $"弾薬  {state.Ammo}", s);

            // プレイヤーHPバー
            var small = new GUIStyle(GUI.skin.label) { fontSize = 13, normal = { textColor = new Color(0.85f, 0.9f, 0.95f) } };
            var label = state.PlayerDown ? $"復活まで {Mathf.CeilToInt(state.PlayerRespawn)}s" : $"体力 {Mathf.CeilToInt(state.PlayerHp)}/{Mathf.CeilToInt(state.PlayerMaxHp)}";
            GUI.Label(new Rect(26, y + 52, 190, 18), label, small);
            var frac = state.PlayerMaxHp > 0f ? Mathf.Clamp01(state.PlayerHp / state.PlayerMaxHp) : 0f;
            var barColor = state.PlayerDown ? new Color(0.6f, 0.3f, 0.3f) : new Color(0.9f, 0.5f, 0.35f);
            DrawBar(new Rect(26, y + 72, 184, 10), frac, barColor);
        }

        // リザルト画面(勝敗 + 統計 + リスタート)
        static void DrawCenterMessage(NfdGameState state)
        {
            if (!state.IsRunEnded) return;

            // 暗幕
            var prev = GUI.color;
            GUI.color = new Color(0f, 0f, 0f, 0.75f);
            GUI.DrawTexture(new Rect(0, 0, Screen.width, Screen.height), Texture2D.whiteTexture);
            GUI.color = prev;

            var win = state.Result == NfdRunResult.Won;
            var title = win ? "VICTORY" : "CORE DESTROYED";
            var titleColor = win ? new Color(1f, 0.84f, 0.28f) : new Color(1f, 0.4f, 0.35f);

            var titleStyle = new GUIStyle(GUI.skin.label) { alignment = TextAnchor.MiddleCenter, fontSize = 44, fontStyle = FontStyle.Bold, normal = { textColor = titleColor } };
            var statStyle = new GUIStyle(GUI.skin.label) { alignment = TextAnchor.MiddleCenter, fontSize = 20, normal = { textColor = Color.white } };
            var hintStyle = new GUIStyle(GUI.skin.label) { alignment = TextAnchor.MiddleCenter, fontSize = 18, normal = { textColor = new Color(0.75f, 0.8f, 0.85f) } };

            GUI.Label(new Rect(0, Screen.height * 0.30f, Screen.width, 60), title, titleStyle);

            var reached = win ? state.TotalWaves : state.WaveNumber;
            GUI.Label(new Rect(0, Screen.height * 0.44f, Screen.width, 30), $"到達 WAVE {reached} / {state.TotalWaves}", statStyle);
            GUI.Label(new Rect(0, Screen.height * 0.50f, Screen.width, 30), $"撃破 {state.Kills}   レリック {state.OwnedRelicIds.Count} 個", statStyle);
            GUI.Label(new Rect(0, Screen.height * 0.62f, Screen.width, 30), "R でリスタート", hintStyle);
        }

        // 危機の赤ビネット: 被弾直後 + コア低HPで画面端が赤く脈打つ
        static void DrawDangerVignette(NfdGameState state)
        {
            var lowHp = state.CoreMaxHp > 0f ? 1f - Mathf.Clamp01(state.CoreHp / state.CoreMaxHp) : 0f;
            var lowPulse = 0f;
            if (lowHp > 0.7f)
            {
                // 残り30%以下で赤く脈打つ。減るほど強く
                lowPulse = (0.5f + 0.5f * Mathf.Sin(Time.unscaledTime * 6f)) * ((lowHp - 0.7f) / 0.3f);
            }
            var danger = Mathf.Clamp01(Mathf.Max(state.CoreHitFlash, lowPulse));
            if (danger <= 0.02f) return;

            var a = danger * 0.5f;
            var red = new Color(0.8f, 0.1f, 0.1f, a);
            var w = Screen.width;
            var h = Screen.height;
            var t = Mathf.Min(w, h) * 0.14f; // 端の帯の太さ

            var prev = GUI.color;
            GUI.color = red;
            var tex = Texture2D.whiteTexture;
            GUI.DrawTexture(new Rect(0, 0, w, t), tex);        // 上
            GUI.DrawTexture(new Rect(0, h - t, w, t), tex);    // 下
            GUI.DrawTexture(new Rect(0, 0, t, h), tex);        // 左
            GUI.DrawTexture(new Rect(w - t, 0, t, h), tex);    // 右
            GUI.color = prev;
        }

        static void DrawBar(Rect rect, float frac, Color fill)
        {
            var bg = Texture2D.whiteTexture;
            var prev = GUI.color;
            GUI.color = new Color(0f, 0f, 0f, 0.5f);
            GUI.DrawTexture(rect, bg);
            GUI.color = fill;
            GUI.DrawTexture(new Rect(rect.x, rect.y, rect.width * frac, rect.height), bg);
            GUI.color = prev;
        }
    }
}
