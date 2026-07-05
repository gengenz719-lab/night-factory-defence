using UnityEngine;

namespace NightFactoryDefence
{
    // 縦スライス用の最小HUD。状態(NfdGameState)を「読むだけ」で、状態は変えない。
    // これは state.js と ui.js を混ぜないルールの実演でもある。
    //
    // 注意: これは暫定表示。Phase F で UI Toolkit 製の本UI(モックの配置)に差し替える。
    public sealed class NfdSliceHud : MonoBehaviour
    {
        void OnGUI()
        {
            var manager = NfdGameManager.Instance;
            if (manager == null) return;
            var state = manager.State;

            var style = new GUIStyle(GUI.skin.label)
            {
                fontSize = 22,
                normal = { textColor = Color.white }
            };
            var small = new GUIStyle(style) { fontSize = 16 };

            GUI.Box(new Rect(14, 14, 430, 126), GUIContent.none);
            GUI.Label(new Rect(28, 24, 390, 28), "Night Factory Defence - Unity Playable Slice", style);
            GUI.Label(new Rect(28, 58, 390, 24), $"Core HP: {Mathf.CeilToInt(state.CoreHp)} / {Mathf.CeilToInt(state.CoreMaxHp)}", small);
            GUI.Label(new Rect(28, 82, 390, 24), $"Enemies: {state.EnemiesRemaining}   Kills: {state.Kills}", small);
            GUI.Label(new Rect(28, 106, 390, 24), "Move: WASD / Aim: Mouse / Shoot: Left Click / Restart: R", small);

            if (!state.WaveRunning && !state.IsRunEnded)
            {
                CenterMessage("Press SPACE to start the test wave");
            }
            else if (state.Result == NfdRunResult.Won)
            {
                CenterMessage("WAVE CLEAR - Press R to restart");
            }
            else if (state.Result == NfdRunResult.Lost)
            {
                CenterMessage("CORE DESTROYED - Press R to restart");
            }
        }

        static void CenterMessage(string message)
        {
            var style = new GUIStyle(GUI.skin.label)
            {
                alignment = TextAnchor.MiddleCenter,
                fontSize = 32,
                normal = { textColor = new Color(1f, 0.84f, 0.28f) }
            };
            GUI.Label(new Rect(0, Screen.height * 0.46f, Screen.width, 70), message, style);
        }
    }
}
