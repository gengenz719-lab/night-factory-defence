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

            DrawTopLeft(state);
            DrawTopCenter(state);
            DrawBottomLeft(state);
            DrawBuildBar();
            DrawCenterMessage(state);
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

        // 左下: 資源(Phase Cで本実装。ここでは数字だけ)
        static void DrawBottomLeft(NfdGameState state)
        {
            var y = Screen.height - 78f;
            GUI.Box(new Rect(14, y, 200, 64), GUIContent.none);
            var s = new GUIStyle(GUI.skin.label) { fontSize = 16, normal = { textColor = Color.white } };
            GUI.Label(new Rect(26, y + 8, 190, 22), $"鉄   {state.Iron}", s);
            GUI.Label(new Rect(26, y + 32, 190, 22), $"弾薬  {state.Ammo}", s);
        }

        static void DrawCenterMessage(NfdGameState state)
        {
            string msg = null;
            if (state.Result == NfdRunResult.Won) msg = "VICTORY - 10 WAVE 生存!  (R でリスタート)";
            else if (state.Result == NfdRunResult.Lost) msg = "CORE DESTROYED  (R でリスタート)";
            if (msg == null) return;

            var style = new GUIStyle(GUI.skin.label)
            {
                alignment = TextAnchor.MiddleCenter,
                fontSize = 30,
                fontStyle = FontStyle.Bold,
                normal = { textColor = new Color(1f, 0.84f, 0.28f) }
            };
            GUI.Label(new Rect(0, Screen.height * 0.44f, Screen.width, 70), msg, style);
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
