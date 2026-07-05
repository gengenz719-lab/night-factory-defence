using UnityEngine;

namespace NightFactoryDefence
{
    // 建設用のタイルグリッド。どのタイルが埋まっているか/鉱床かを管理する。
    // 30×17タイル、1タイル=1unit。原点は左下 (Left, Bottom)。
    // タイル⇔ワールド変換は静的メソッド、占有状況はインスタンスが持つ。
    public sealed class NfdBuildGrid : MonoBehaviour
    {
        public const int W = 30;
        public const int H = 17;
        public const float Left = -15f;
        public const float Bottom = -8.5f;

        // builderが設定: 鉱床の中心(ワールド)と、コアの占有範囲
        [SerializeField] Vector2[] oreCenters;
        [SerializeField] Vector2 coreCenter = new Vector2(0f, 0.35f);
        [SerializeField] int coreTileRadius = 1; // 中心タイルからこの範囲を占有(2x2相当)

        public static NfdBuildGrid Instance { get; private set; }

        readonly bool[,] occupied = new bool[W, H];
        readonly bool[,] ore = new bool[W, H];
        readonly NfdBuilding[,] buildings = new NfdBuilding[W, H];

        void Awake()
        {
            Instance = this;

            // 鉱床タイルを登録(中心タイル+隣接。採掘機を置ける場所)
            if (oreCenters != null)
            {
                foreach (var c in oreCenters)
                {
                    if (!WorldToTile(new Vector3(c.x, c.y, 0f), out var ox, out var oy)) continue;
                    for (var dx = -1; dx <= 1; dx++)
                    for (var dy = -1; dy <= 1; dy++)
                        if (In(ox + dx, oy + dy)) ore[ox + dx, oy + dy] = true;
                }
            }

            // コアのタイルを占有(建設不可)
            if (WorldToTile(new Vector3(coreCenter.x, coreCenter.y, 0f), out var cx, out var cy))
            {
                for (var dx = -coreTileRadius; dx <= 0; dx++)
                for (var dy = 0; dy <= coreTileRadius; dy++)
                    if (In(cx + dx, cy + dy)) occupied[cx + dx, cy + dy] = true;
            }
        }

        void OnDestroy()
        {
            if (Instance == this) Instance = null;
        }

        public static Vector3 TileToWorld(int x, int y)
        {
            return new Vector3(Left + x + 0.5f, Bottom + y + 0.5f, 0f);
        }

        public static bool WorldToTile(Vector3 world, out int x, out int y)
        {
            x = Mathf.FloorToInt(world.x - Left);
            y = Mathf.FloorToInt(world.y - Bottom);
            return In(x, y);
        }

        public static bool In(int x, int y) => x >= 0 && x < W && y >= 0 && y < H;

        public bool IsOccupied(int x, int y) => In(x, y) && occupied[x, y];
        public bool IsOre(int x, int y) => In(x, y) && ore[x, y];
        public NfdBuilding GetBuilding(int x, int y) => In(x, y) ? buildings[x, y] : null;

        public void Place(int x, int y, NfdBuilding building)
        {
            if (!In(x, y)) return;
            occupied[x, y] = true;
            buildings[x, y] = building;
        }

        public void Clear(int x, int y)
        {
            if (!In(x, y)) return;
            occupied[x, y] = false;
            buildings[x, y] = null;
        }
    }
}
