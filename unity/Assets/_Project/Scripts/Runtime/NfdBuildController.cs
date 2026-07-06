using UnityEngine;
using UnityEngine.InputSystem;

namespace NightFactoryDefence
{
    // 建設の入力とプレビューを担当する。
    // 操作の考え方:
    // - 通常は「射撃モード」(建物は未選択=SelectedIndex -1)。左クリックは射撃(プレイヤー側で処理)
    // - [1]〜[4] または建設バーのスロットで建物を選ぶと「設置モード」になり、左クリックで設置(銃は撃たない)
    // - もう一度同じキー/スロット、または Esc/Q で設置モード解除 → 射撃に戻る
    // - 右クリックはいつでも撤去(50%返金)
    public sealed class NfdBuildController : MonoBehaviour
    {
        [SerializeField] NfdGameConfig config;
        [SerializeField] Camera worldCamera;
        [SerializeField] Sprite ghostSprite;
        [SerializeField] GameObject[] prefabs; // config.buildings と同じ並び(wall/turret/miner/smelter)

        public int SelectedIndex { get; private set; } = -1; // -1 = 未選択(射撃モード)
        public bool IsArmed => SelectedIndex >= 0;            // 設置モードか

        int armedFrame = -1; // 選択した瞬間のフレーム(同フレームの誤設置を防ぐ)

        // キー/HUDスロットから呼ぶ。同じものを選ぶと解除(トグル)。
        public void Select(int index)
        {
            if (config == null || config.buildings == null) return;
            if (index < 0 || index >= config.buildings.Length) return;
            SelectedIndex = (SelectedIndex == index) ? -1 : index;
            armedFrame = Time.frameCount;
        }

        public void Disarm()
        {
            SelectedIndex = -1;
        }

        public NfdBuildingData Selected =>
            IsArmed && config != null && config.buildings != null && SelectedIndex < config.buildings.Length
                ? config.buildings[SelectedIndex] : null;

        public static NfdBuildController Instance { get; private set; }

        SpriteRenderer ghost;
        int hoverX, hoverY;
        bool hoverValid;

        void Awake()
        {
            Instance = this;
            var go = new GameObject("BuildGhost");
            go.transform.SetParent(transform, false);
            ghost = go.AddComponent<SpriteRenderer>();
            ghost.sprite = ghostSprite;
            ghost.sortingOrder = 70;
            ghost.enabled = false;
        }

        void OnDestroy()
        {
            if (Instance == this) Instance = null;
        }

        void Update()
        {
            var manager = NfdGameManager.Instance;
            if (manager == null || manager.IsRunEnded)
            {
                if (ghost != null) ghost.enabled = false;
                return;
            }

            ReadHotkeys();
            UpdateHover();
            HandleClicks(manager);
        }

        void ReadHotkeys()
        {
            var kb = Keyboard.current;
            if (kb == null) return;
            if (kb.digit1Key.wasPressedThisFrame) Select(0);
            if (kb.digit2Key.wasPressedThisFrame) Select(1);
            if (kb.digit3Key.wasPressedThisFrame) Select(2);
            if (kb.digit4Key.wasPressedThisFrame) Select(3);
            // Esc / Q で設置モード解除(射撃に戻る)
            if (kb.escapeKey.wasPressedThisFrame || kb.qKey.wasPressedThisFrame) Disarm();
        }

        void UpdateHover()
        {
            if (worldCamera == null || Mouse.current == null || ghost == null) return;

            // 設置モードでないときはゴーストを出さない
            if (!IsArmed)
            {
                ghost.enabled = false;
                return;
            }

            var mouse = Mouse.current.position.ReadValue();
            var world = worldCamera.ScreenToWorldPoint(new Vector3(mouse.x, mouse.y, -worldCamera.transform.position.z));
            if (!NfdBuildGrid.WorldToTile(world, out hoverX, out hoverY))
            {
                ghost.enabled = false;
                return;
            }

            hoverValid = CanPlace(hoverX, hoverY);
            ghost.enabled = true;
            ghost.transform.position = NfdBuildGrid.TileToWorld(hoverX, hoverY);
            ghost.transform.localScale = new Vector3(0.9f, 0.9f, 1f);
            var c = Selected != null ? Selected.color : Color.white;
            ghost.color = hoverValid
                ? new Color(c.r, c.g, c.b, 0.55f)
                : new Color(1f, 0.2f, 0.2f, 0.45f);
        }

        bool CanPlace(int x, int y)
        {
            var grid = NfdBuildGrid.Instance;
            var data = Selected;
            if (grid == null || data == null) return false;
            if (!NfdBuildGrid.In(x, y) || grid.IsOccupied(x, y)) return false;
            if (data.needsOre && !grid.IsOre(x, y)) return false; // 採掘機は鉱床の上のみ
            return true;
        }

        void HandleClicks(NfdGameManager manager)
        {
            var mouse = Mouse.current;
            if (mouse == null) return;

            // 設置は「設置モード」のときだけ。選択した同フレームは設置しない(スロットクリックの誤爆防止)
            if (mouse.leftButton.wasPressedThisFrame && IsArmed && Time.frameCount != armedFrame)
            {
                TryPlace(manager);
            }
            if (mouse.rightButton.wasPressedThisFrame) TryRemove(manager);
        }

        void TryPlace(NfdGameManager manager)
        {
            var data = Selected;
            if (data == null || !hoverValid) return;
            if (!manager.TrySpendIron(data.cost)) return;

            var prefab = prefabs != null && SelectedIndex < prefabs.Length ? prefabs[SelectedIndex] : null;
            if (prefab == null) { manager.AddIron(data.cost); return; }

            var go = Instantiate(prefab, NfdBuildGrid.TileToWorld(hoverX, hoverY), Quaternion.identity);
            var building = go.GetComponent<NfdBuilding>();
            building.Setup(data, hoverX, hoverY);
            NfdBuildGrid.Instance.Place(hoverX, hoverY, building);
            NfdAudioManager.Instance?.Build();
        }

        void TryRemove(NfdGameManager manager)
        {
            var grid = NfdBuildGrid.Instance;
            if (grid == null) return;
            if (!NfdBuildGrid.WorldToTile(GhostWorld(), out var x, out var y)) return;

            var building = grid.GetBuilding(x, y);
            if (building == null) return;

            manager.AddIron(building.Data.cost / 2); // 50%返金
            grid.Clear(x, y);
            Destroy(building.gameObject);
        }

        Vector3 GhostWorld()
        {
            var mouse = Mouse.current.position.ReadValue();
            return worldCamera.ScreenToWorldPoint(new Vector3(mouse.x, mouse.y, -worldCamera.transform.position.z));
        }
    }
}
