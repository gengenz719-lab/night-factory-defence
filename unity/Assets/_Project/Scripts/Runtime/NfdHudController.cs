using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;

namespace NightFactoryDefence
{
    // UI Toolkit製のHUD。ビジュアルツリーはコードで組み立て、毎フレーム状態を読むだけで更新する。
    // (OnGUIのNfdSliceHudを置き換え。モックの配置に準拠: 左上コア/上中央Wave/右上プレイヤー枠/
    //  左下資源/下中央建設バー/オーバーレイ=レリック3択・リザルト・危機ビネット)
    [RequireComponent(typeof(UIDocument))]
    public sealed class NfdHudController : MonoBehaviour
    {
        // 工業/軍用テーマの色
        static readonly Color Panel = new Color(0.04f, 0.06f, 0.09f, 0.82f);
        static readonly Color Edge = new Color(0.25f, 0.7f, 0.9f, 0.5f);
        static readonly Color Cyan = new Color(0.25f, 0.82f, 1f);
        static readonly Color Orange = new Color(1f, 0.62f, 0.28f);
        static readonly Color Green = new Color(0.35f, 0.85f, 0.5f);
        static readonly Color TextDim = new Color(0.72f, 0.78f, 0.85f);

        UIDocument doc;

        // 更新対象の要素
        Label phaseLabel, timeLabel, coreLabel, waveLabel, waveSubLabel, ironLabel, ammoLabel, playerHpLabel;
        VisualElement coreHpFill, playerHpFill, waveFill;
        readonly List<VisualElement> buildSlots = new();
        readonly List<Label> buildCostLabels = new();
        readonly List<Label> buildNameLabels = new();
        readonly List<VisualElement> vignetteEdges = new();
        readonly List<VisualElement> playerChips = new();

        VisualElement relicOverlay;
        readonly List<Label> relicNameLabels = new();
        readonly List<Label> relicDescLabels = new();
        readonly List<VisualElement> relicCards = new();

        VisualElement resultOverlay;
        Label resultTitle, resultStats;

        // 浮遊ダメージ数字
        VisualElement floatingLayer;
        sealed class FloatNum { public Label label; public Vector3 world; public float timer; public float life; }
        readonly List<FloatNum> floats = new();

        bool built;

        public static NfdHudController Instance { get; private set; }

        void OnEnable()
        {
            Instance = this;
            doc = GetComponent<UIDocument>();
        }

        void OnDisable()
        {
            if (Instance == this) Instance = null;
        }

        // 敵が被弾したときに数字をポップさせる(NfdEnemyから呼ぶ)
        public void SpawnDamage(Vector3 worldPos, float amount)
        {
            if (!built || floatingLayer == null || floats.Count > 40) return;
            var label = new Label(Mathf.RoundToInt(amount).ToString());
            label.style.position = Position.Absolute;
            label.style.fontSize = 15;
            label.style.color = new Color(1f, 0.95f, 0.6f);
            label.style.unityFontStyleAndWeight = FontStyle.Bold;
            label.pickingMode = PickingMode.Ignore;
            floatingLayer.Add(label);
            floats.Add(new FloatNum { label = label, world = worldPos + new Vector3(Random.Range(-0.2f, 0.2f), 0.3f, 0f), timer = 0f, life = 0.6f });
        }

        void Start()
        {
            Build();
        }

        void Update()
        {
            if (!built) Build();
            if (!built) return;
            Refresh();
            UpdateFloats();
            UpdateMinimap();
        }

        // 浮遊ダメージ数字: 上昇+フェードし、ワールド座標を画面(パネル)座標に変換して配置
        void UpdateFloats()
        {
            if (floats.Count == 0) return;
            var cam = Camera.main;
            for (var i = floats.Count - 1; i >= 0; i--)
            {
                var f = floats[i];
                f.timer += Time.deltaTime;
                f.world += Vector3.up * 1.3f * Time.deltaTime;
                var k = Mathf.Clamp01(f.timer / f.life);

                if (cam != null && floatingLayer.panel != null)
                {
                    var sp = cam.WorldToScreenPoint(f.world);
                    if (sp.z > 0f)
                    {
                        var panelPos = RuntimePanelUtils.ScreenToPanel(floatingLayer.panel, new Vector2(sp.x, Screen.height - sp.y));
                        f.label.style.left = panelPos.x - 10f;
                        f.label.style.top = panelPos.y - 10f;
                    }
                }
                var c = f.label.style.color.value; c.a = 1f - k; f.label.style.color = c;

                if (f.timer >= f.life)
                {
                    f.label.RemoveFromHierarchy();
                    floats.RemoveAt(i);
                }
            }
        }

        // ---------- 構築 ----------

        void Build()
        {
            if (doc == null) doc = GetComponent<UIDocument>();
            var root = doc != null ? doc.rootVisualElement : null;
            if (root == null) return; // UIDocumentがまだ初期化前

            root.Clear();
            root.style.flexGrow = 1f;
            root.pickingMode = PickingMode.Ignore;

            BuildVignette(root);
            // 浮遊ダメージ数字のレイヤー(全面・ピッキング無効)
            floatingLayer = new VisualElement { pickingMode = PickingMode.Ignore };
            floatingLayer.style.position = Position.Absolute;
            floatingLayer.style.top = 0; floatingLayer.style.left = 0; floatingLayer.style.right = 0; floatingLayer.style.bottom = 0;
            root.Add(floatingLayer);

            BuildTopLeft(root);
            BuildTopCenter(root);
            BuildTopRight(root);
            BuildBottomLeft(root);
            BuildBuildBar(root);
            BuildMinimap(root);
            BuildRelicOverlay(root);
            BuildResultOverlay(root);

            built = true;
        }

        void BuildVignette(VisualElement root)
        {
            // 画面4辺の赤帯(危機表示)。ピッキングは無効
            foreach (var side in new[] { "top", "bottom", "left", "right" })
            {
                var e = new VisualElement { pickingMode = PickingMode.Ignore };
                e.style.position = Position.Absolute;
                var thick = new StyleLength(new Length(13f, LengthUnit.Percent));
                if (side == "top") { e.style.top = 0; e.style.left = 0; e.style.right = 0; e.style.height = thick; }
                else if (side == "bottom") { e.style.bottom = 0; e.style.left = 0; e.style.right = 0; e.style.height = thick; }
                else if (side == "left") { e.style.top = 0; e.style.bottom = 0; e.style.left = 0; e.style.width = thick; }
                else { e.style.top = 0; e.style.bottom = 0; e.style.right = 0; e.style.width = thick; }
                e.style.backgroundColor = new Color(0.8f, 0.1f, 0.1f, 0f);
                root.Add(e);
                vignetteEdges.Add(e);
            }
        }

        void BuildTopLeft(VisualElement root)
        {
            var p = MakePanel(root);
            p.style.top = 14; p.style.left = 14; p.style.width = 260;

            phaseLabel = MakeLabel(p, "昼(建設)", 18, Color.white, true);
            timeLabel = MakeLabel(p, "残り 45s", 13, TextDim);
            coreLabel = MakeLabel(p, "コア 600 / 600", 13, TextDim);
            var bar = MakeBarBg(p);
            coreHpFill = MakeBarFill(bar, Green);
        }

        void BuildTopCenter(VisualElement root)
        {
            var p = MakePanel(root);
            p.style.top = 14;
            p.style.left = new StyleLength(new Length(50f, LengthUnit.Percent));
            p.style.width = 300;
            p.style.marginLeft = -150; // 中央寄せ
            p.style.alignItems = Align.Center;

            waveLabel = MakeLabel(p, "WAVE 1 / 10", 20, Color.white, true);
            var bar = MakeBarBg(p); bar.style.marginTop = 4; bar.style.marginBottom = 4;
            waveFill = MakeBarFill(bar, Cyan);
            waveSubLabel = MakeLabel(p, "建設フェーズ (Space で夜)", 12, Orange);
            waveSubLabel.style.unityTextAlign = TextAnchor.MiddleCenter;
        }

        void BuildTopRight(VisualElement root)
        {
            var row = new VisualElement { pickingMode = PickingMode.Ignore };
            row.style.position = Position.Absolute;
            row.style.top = 14; row.style.right = 14;
            row.style.flexDirection = FlexDirection.Row;
            root.Add(row);

            for (var i = 0; i < 4; i++)
            {
                var chip = MakePanelRaw();
                chip.style.width = 92; chip.style.height = 56; chip.style.marginLeft = 6;
                var name = MakeLabel(chip, "P" + (i + 1), 13, i == 0 ? Cyan : new Color(0.5f, 0.55f, 0.6f), true);
                name.style.unityTextAlign = TextAnchor.MiddleCenter;
                var barBg = MakeBarBg(chip); barBg.style.marginTop = 4;
                var fill = MakeBarFill(barBg, i == 0 ? Green : new Color(0.3f, 0.33f, 0.36f));
                fill.style.width = new StyleLength(new Length(i == 0 ? 100f : 0f, LengthUnit.Percent));
                row.Add(chip);
                playerChips.Add(chip);
                if (i == 0) playerHpFill = fill; // P1=自分
            }
        }

        void BuildBottomLeft(VisualElement root)
        {
            var p = MakePanel(root);
            p.style.bottom = 14; p.style.left = 14; p.style.width = 220;

            ironLabel = MakeLabel(p, "鉄   80", 16, Color.white);
            ammoLabel = MakeLabel(p, "弾薬  80", 16, Color.white);
            playerHpLabel = MakeLabel(p, "体力 100 / 100", 12, TextDim);
            var bar = MakeBarBg(p);
            // 左下のプレイヤーHPは上のP1バーと別に見せる(近接時に見やすい)
            var fill = MakeBarFill(bar, Orange);
            // playerHpFillは右上を主に使うが、ここも同期させる
            bottomPlayerHpFill = fill;
        }
        VisualElement bottomPlayerHpFill;

        void BuildBuildBar(VisualElement root)
        {
            var manager = NfdGameManager.Instance;
            var config = manager != null ? manager.Config : null;
            var count = config != null && config.buildings != null ? config.buildings.Length : 4;

            var bar = new VisualElement();
            bar.style.position = Position.Absolute;
            bar.style.bottom = 14;
            bar.style.left = new StyleLength(new Length(50f, LengthUnit.Percent));
            bar.style.flexDirection = FlexDirection.Row;
            bar.style.marginLeft = -(count * 122) / 2f;
            root.Add(bar);

            for (var i = 0; i < count; i++)
            {
                var idx = i;
                var slot = MakePanelRaw();
                slot.style.width = 114; slot.style.height = 60; slot.style.marginLeft = 4; slot.style.marginRight = 4;
                slot.style.justifyContent = Justify.SpaceBetween;
                slot.RegisterCallback<ClickEvent>(_ => NfdBuildController.Instance?.Select(idx));

                var name = config != null ? $"[{i + 1}] {config.buildings[i].displayName}" : $"[{i + 1}]";
                var nameLabel = MakeLabel(slot, name, 13, Color.white, true);
                var costLabel = MakeLabel(slot, config != null ? $"鉄 {config.buildings[i].cost}" : "", 12, new Color(0.9f, 0.85f, 0.5f));
                costLabel.style.unityTextAlign = TextAnchor.LowerRight;

                bar.Add(slot);
                buildSlots.Add(slot);
                buildNameLabels.Add(nameLabel);
                buildCostLabels.Add(costLabel);
            }
        }

        // 右下ミニマップ + 警告
        const float MapW = 168f, MapH = 95f;
        VisualElement minimapContent;
        readonly List<VisualElement> dotPool = new();
        int dotUsed;
        Label warningLabel;
        float minimapTimer;

        void BuildMinimap(VisualElement root)
        {
            var p = MakePanel(root);
            p.style.bottom = 14; p.style.right = 14;
            p.style.width = MapW + 20; p.style.paddingLeft = 6; p.style.paddingRight = 6; p.style.paddingTop = 6; p.style.paddingBottom = 6;

            warningLabel = MakeLabel(p, "", 12, new Color(1f, 0.4f, 0.35f), true);
            warningLabel.style.marginBottom = 3;

            minimapContent = new VisualElement { pickingMode = PickingMode.Ignore };
            minimapContent.style.width = MapW; minimapContent.style.height = MapH;
            minimapContent.style.backgroundColor = new Color(0.02f, 0.04f, 0.06f, 0.9f);
            SetBorder(minimapContent, new Color(0.2f, 0.4f, 0.5f, 0.6f), 1);
            p.Add(minimapContent);
        }

        void UpdateMinimap()
        {
            if (minimapContent == null) return;
            minimapTimer += Time.deltaTime;
            if (minimapTimer < 0.1f) return; // 10Hz更新
            minimapTimer = 0f;

            dotUsed = 0;

            // コア(中央)
            AddDot(new Vector3(0f, 0.35f, 0f), Cyan, 7f, true);

            // 建物(壁=灰/タレット=橙/採掘機・加工炉=シアン)。低HPは点滅色
            var damaged = 0;
            foreach (var b in Object.FindObjectsByType<NfdBuilding>(FindObjectsSortMode.None))
            {
                if (b == null || b.Data == null) continue;
                Color c = b.Data.kind switch
                {
                    NfdBuildingKind.Turret => Orange,
                    NfdBuildingKind.Wall => new Color(0.6f, 0.65f, 0.7f),
                    _ => new Color(0.35f, 0.7f, 0.85f),
                };
                if (b.HpFraction < 0.5f) { damaged++; c = new Color(1f, 0.5f, 0.2f); }
                AddDot(b.transform.position, c, 4f, false);
            }

            // 敵(赤)
            var mgr = NfdGameManager.Instance;
            if (mgr != null)
            {
                foreach (var e in mgr.Enemies)
                {
                    if (e != null && e.IsAlive) AddDot(e.transform.position, new Color(1f, 0.25f, 0.2f), 4f, false);
                }
            }

            // プレイヤー(明るいシアン)
            var player = NfdPlayerController.Instance;
            if (player != null && player.IsAlive) AddDot(player.transform.position, new Color(0.6f, 0.95f, 1f), 6f, true);

            // 余った点を隠す
            for (var i = dotUsed; i < dotPool.Count; i++) dotPool[i].style.display = DisplayStyle.None;

            // 警告(HPが減っている建物の数)
            if (warningLabel != null)
                warningLabel.text = damaged > 0 ? $"⚠ 損傷 {damaged}" : "";
        }

        void AddDot(Vector3 world, Color color, float size, bool diamond)
        {
            // world(x:-15..15, y:-8.5..8.5) → minimap(0..MapW, MapH..0)
            var mx = (world.x + 15f) / 30f * MapW;
            var my = (1f - (world.y + 8.5f) / 17f) * MapH;

            VisualElement dot;
            if (dotUsed < dotPool.Count) dot = dotPool[dotUsed];
            else
            {
                dot = new VisualElement { pickingMode = PickingMode.Ignore };
                dot.style.position = Position.Absolute;
                minimapContent.Add(dot);
                dotPool.Add(dot);
            }
            dotUsed++;

            dot.style.display = DisplayStyle.Flex;
            dot.style.width = size; dot.style.height = size;
            dot.style.left = mx - size / 2f; dot.style.top = my - size / 2f;
            dot.style.backgroundColor = color;
            var radius = diamond ? 0f : size / 2f;
            dot.style.borderTopLeftRadius = dot.style.borderTopRightRadius =
                dot.style.borderBottomLeftRadius = dot.style.borderBottomRightRadius = radius;
            dot.style.rotate = diamond ? new Rotate(45f) : new Rotate(0f);
        }

        void BuildRelicOverlay(VisualElement root)
        {
            relicOverlay = MakeOverlay(root);
            var title = MakeLabel(relicOverlay, "レリックを選べ", 30, new Color(1f, 0.84f, 0.28f), true);
            title.style.unityTextAlign = TextAnchor.MiddleCenter;
            title.style.marginBottom = 20;

            var cardsRow = new VisualElement();
            cardsRow.style.flexDirection = FlexDirection.Row;
            cardsRow.style.justifyContent = Justify.Center;
            relicOverlay.Add(cardsRow);

            for (var i = 0; i < 3; i++)
            {
                var idx = i;
                var card = MakePanelRaw();
                card.style.width = 220; card.style.height = 150; card.style.marginLeft = 14; card.style.marginRight = 14;
                card.style.alignItems = Align.Center; card.style.justifyContent = Justify.Center;
                card.RegisterCallback<ClickEvent>(_ => NfdGameManager.Instance?.ChooseRelic(idx));

                var name = MakeLabel(card, "", 18, Color.white, true);
                name.style.unityTextAlign = TextAnchor.MiddleCenter;
                var desc = MakeLabel(card, "", 13, TextDim);
                desc.style.unityTextAlign = TextAnchor.MiddleCenter;
                desc.style.whiteSpace = WhiteSpace.Normal;
                desc.style.marginTop = 10;

                cardsRow.Add(card);
                relicCards.Add(card);
                relicNameLabels.Add(name);
                relicDescLabels.Add(desc);
            }
            relicOverlay.style.display = DisplayStyle.None;
        }

        void BuildResultOverlay(VisualElement root)
        {
            resultOverlay = MakeOverlay(root);
            resultTitle = MakeLabel(resultOverlay, "VICTORY", 44, new Color(1f, 0.84f, 0.28f), true);
            resultTitle.style.unityTextAlign = TextAnchor.MiddleCenter;
            resultStats = MakeLabel(resultOverlay, "", 20, Color.white);
            resultStats.style.unityTextAlign = TextAnchor.MiddleCenter;
            resultStats.style.whiteSpace = WhiteSpace.Normal;
            resultStats.style.marginTop = 16;
            var hint = MakeLabel(resultOverlay, "R でリスタート", 18, TextDim);
            hint.style.unityTextAlign = TextAnchor.MiddleCenter;
            hint.style.marginTop = 24;
            resultOverlay.style.display = DisplayStyle.None;
        }

        // ---------- 更新 ----------

        void Refresh()
        {
            var manager = NfdGameManager.Instance;
            if (manager == null) return;
            var s = manager.State;

            // 左上
            phaseLabel.text = s.Phase == NfdPhase.Day ? "昼(建設)" : "夜(防衛)";
            timeLabel.text = s.Phase == NfdPhase.Day ? $"残り {Mathf.CeilToInt(s.PhaseTimer)}s" : "襲来中";
            coreLabel.text = $"コア {Mathf.CeilToInt(s.CoreHp)} / {Mathf.CeilToInt(s.CoreMaxHp)}";
            SetFill(coreHpFill, s.CoreMaxHp > 0 ? s.CoreHp / s.CoreMaxHp : 0f);

            // 上中央
            waveLabel.text = $"WAVE {s.WaveNumber} / {s.TotalWaves}";
            SetFill(waveFill, s.TotalWaves > 0 ? (float)s.WaveNumber / s.TotalWaves : 0f);
            waveSubLabel.text = s.IsNight ? $"残り敵 {s.EnemiesRemaining}   撃破 {s.Kills}" : "建設フェーズ (Space で夜)";

            // 左下・プレイヤー
            ironLabel.text = $"鉄   {s.Iron}";
            ammoLabel.text = $"弾薬  {s.Ammo}";
            var hpFrac = s.PlayerMaxHp > 0 ? Mathf.Clamp01(s.PlayerHp / s.PlayerMaxHp) : 0f;
            playerHpLabel.text = s.PlayerDown ? $"復活まで {Mathf.CeilToInt(s.PlayerRespawn)}s" : $"体力 {Mathf.CeilToInt(s.PlayerHp)} / {Mathf.CeilToInt(s.PlayerMaxHp)}";
            SetFill(bottomPlayerHpFill, hpFrac);
            if (playerHpFill != null) SetFill(playerHpFill, hpFrac);

            // 建設バー(選択ハイライト・鉄不足グレー)
            var build = NfdBuildController.Instance;
            var config = manager.Config;
            for (var i = 0; i < buildSlots.Count; i++)
            {
                var selected = build != null && build.SelectedIndex == i;
                buildSlots[i].style.backgroundColor = selected ? new Color(0.2f, 0.55f, 0.75f, 0.9f) : Panel;
                buildSlots[i].style.borderTopColor = buildSlots[i].style.borderBottomColor =
                    buildSlots[i].style.borderLeftColor = buildSlots[i].style.borderRightColor = selected ? Cyan : Edge;
                var affordable = config != null && i < config.buildings.Length && s.Iron >= config.buildings[i].cost;
                buildNameLabels[i].style.color = affordable ? Color.white : new Color(0.5f, 0.5f, 0.5f);
                buildCostLabels[i].style.color = affordable ? new Color(0.9f, 0.85f, 0.5f) : new Color(0.6f, 0.4f, 0.4f);
            }

            // 危機ビネット
            UpdateVignette(s);

            // レリック3択
            if (s.ChoosingRelic && s.RelicChoices.Count > 0)
            {
                relicOverlay.style.display = DisplayStyle.Flex;
                for (var i = 0; i < relicCards.Count; i++)
                {
                    var has = i < s.RelicChoices.Count;
                    relicCards[i].style.display = has ? DisplayStyle.Flex : DisplayStyle.None;
                    if (has)
                    {
                        relicNameLabels[i].text = s.RelicChoices[i].displayName;
                        relicDescLabels[i].text = s.RelicChoices[i].description;
                    }
                }
            }
            else relicOverlay.style.display = DisplayStyle.None;

            // リザルト
            if (s.IsRunEnded)
            {
                resultOverlay.style.display = DisplayStyle.Flex;
                var win = s.Result == NfdRunResult.Won;
                resultTitle.text = win ? "VICTORY" : "CORE DESTROYED";
                resultTitle.style.color = win ? new Color(1f, 0.84f, 0.28f) : new Color(1f, 0.4f, 0.35f);
                var reached = win ? s.TotalWaves : s.WaveNumber;
                resultStats.text = $"到達 WAVE {reached} / {s.TotalWaves}\n撃破 {s.Kills}   レリック {s.OwnedRelicIds.Count} 個";
            }
            else resultOverlay.style.display = DisplayStyle.None;
        }

        void UpdateVignette(NfdGameState s)
        {
            var lowHp = s.CoreMaxHp > 0 ? 1f - Mathf.Clamp01(s.CoreHp / s.CoreMaxHp) : 0f;
            var lowPulse = 0f;
            if (lowHp > 0.7f) lowPulse = (0.5f + 0.5f * Mathf.Sin(Time.unscaledTime * 6f)) * ((lowHp - 0.7f) / 0.3f);
            var danger = Mathf.Clamp01(Mathf.Max(s.CoreHitFlash, lowPulse)) * 0.45f;

            // 各辺 = コア危機(全辺共通) と その方向の敵接近脅威 の濃い方
            // vignetteEdges の並び: top, bottom, left, right
            SetEdge(vignetteEdges[0], danger, s.ThreatTop);
            SetEdge(vignetteEdges[1], danger, s.ThreatBottom);
            SetEdge(vignetteEdges[2], danger, s.ThreatLeft);
            SetEdge(vignetteEdges[3], danger, s.ThreatRight);
        }

        static void SetEdge(VisualElement e, float danger, float threat)
        {
            var a = Mathf.Max(danger, threat * 0.5f);
            e.style.backgroundColor = new Color(0.85f, 0.12f, 0.12f, a);
        }

        static void SetFill(VisualElement fill, float frac)
        {
            if (fill != null) fill.style.width = new StyleLength(new Length(Mathf.Clamp01(frac) * 100f, LengthUnit.Percent));
        }

        // ---------- 生成ヘルパー ----------

        VisualElement MakePanel(VisualElement parent)
        {
            var p = MakePanelRaw();
            p.style.position = Position.Absolute;
            parent.Add(p);
            return p;
        }

        VisualElement MakePanelRaw()
        {
            var p = new VisualElement();
            p.style.backgroundColor = Panel;
            p.style.paddingLeft = 10; p.style.paddingRight = 10; p.style.paddingTop = 6; p.style.paddingBottom = 6;
            SetBorder(p, Edge, 1);
            p.style.borderTopLeftRadius = p.style.borderTopRightRadius =
                p.style.borderBottomLeftRadius = p.style.borderBottomRightRadius = 4;
            return p;
        }

        VisualElement MakeOverlay(VisualElement root)
        {
            var o = new VisualElement();
            o.style.position = Position.Absolute;
            o.style.top = 0; o.style.left = 0; o.style.right = 0; o.style.bottom = 0;
            o.style.backgroundColor = new Color(0f, 0f, 0f, 0.75f);
            o.style.alignItems = Align.Center;
            o.style.justifyContent = Justify.Center;
            root.Add(o);
            return o;
        }

        static Label MakeLabel(VisualElement parent, string text, int size, Color color, bool bold = false)
        {
            var l = new Label(text);
            l.style.fontSize = size;
            l.style.color = color;
            l.style.unityFontStyleAndWeight = bold ? FontStyle.Bold : FontStyle.Normal;
            l.pickingMode = PickingMode.Ignore;
            parent.Add(l);
            return l;
        }

        VisualElement MakeBarBg(VisualElement parent)
        {
            var bg = new VisualElement();
            bg.style.height = 12;
            bg.style.marginTop = 3;
            bg.style.backgroundColor = new Color(0f, 0f, 0f, 0.5f);
            bg.style.borderTopLeftRadius = bg.style.borderTopRightRadius =
                bg.style.borderBottomLeftRadius = bg.style.borderBottomRightRadius = 2;
            parent.Add(bg);
            return bg;
        }

        static VisualElement MakeBarFill(VisualElement bg, Color color)
        {
            var fill = new VisualElement();
            fill.style.height = Length.Percent(100);
            fill.style.width = Length.Percent(100);
            fill.style.backgroundColor = color;
            fill.style.borderTopLeftRadius = fill.style.borderBottomLeftRadius = 2;
            bg.Add(fill);
            return fill;
        }

        static void SetBorder(VisualElement e, Color c, float w)
        {
            e.style.borderTopWidth = e.style.borderBottomWidth = e.style.borderLeftWidth = e.style.borderRightWidth = w;
            e.style.borderTopColor = e.style.borderBottomColor = e.style.borderLeftColor = e.style.borderRightColor = c;
        }
    }
}
