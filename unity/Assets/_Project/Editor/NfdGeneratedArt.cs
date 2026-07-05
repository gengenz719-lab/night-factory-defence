#if UNITY_EDITOR
using System;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace NightFactoryDefence.Editor
{
    // コード生成スプライトの置き場。
    // 画像編集ソフトを使わず、距離関数(SDF)でピクセルを塗ってPNGを書き出す。
    // 形や色を変えたいときは、ここの数値を変えて Build Playable Slice を再実行するだけ。
    public static class NfdGeneratedArt
    {
        const string ArtDir = "Assets/_Project/Art/Generated";

        public static void EnsureAll()
        {
            CreateWalkerBody();
            CreatePlayerBody();
            CreateRing();
        }

        // タレット射程などに使う細いリング(透明度はテクスチャに焼き込む。
        // tintのアルファはURPスプライトシェーダーで正しくブレンドされないため)
        static void CreateRing()
        {
            CreateSpriteTexture("ring", 256, 256, (x, y) =>
            {
                float fx = x + 0.5f - 128f, fy = y + 0.5f - 128f;
                var dist = Mathf.Sqrt(fx * fx + fy * fy);
                var d = Mathf.Abs(dist - 118f) - 5f;
                var a = Mathf.Clamp01(0.5f - d) * 0.35f;
                return new Color(1f, 1f, 1f, a);
            });
        }

        // 上から見た歩行ゾンビ(上向きが正面)
        static void CreateWalkerBody()
        {
            var outline = Hex("#16200f");
            var socketCol = Hex("#0d140a");
            var torsoCol = Hex("#43603a");
            var headCol = Hex("#4f7345");
            var limbCol = Hex("#38512f");
            var handCol = Hex("#466339");

            CreateSpriteTexture("walker_body", 256, 256, (x, y) =>
            {
                float fx = x + 0.5f, fy = y + 0.5f;

                var d = float.MaxValue;
                var col = torsoCol;
                Take(EllipseD(fx, fy, 128f, 122f, 54f, 46f), torsoCol, ref d, ref col);   // 肩・胴
                Take(EllipseD(fx, fy, 128f, 88f, 38f, 30f), limbCol, ref d, ref col);     // 腰
                Take(CircleD(fx, fy, 128f, 162f, 36f), headCol, ref d, ref col);          // 頭
                Take(CapsuleD(fx, fy, 86f, 138f, 70f, 196f, 13f), limbCol, ref d, ref col);   // 左腕
                Take(CapsuleD(fx, fy, 170f, 138f, 182f, 188f, 12f), limbCol, ref d, ref col); // 右腕(短め=非対称)
                Take(CircleD(fx, fy, 69f, 204f, 16f), handCol, ref d, ref col);           // 左手
                Take(CircleD(fx, fy, 183f, 196f, 15f), handCol, ref d, ref col);          // 右手

                if (d > 0.5f) return Color.clear;
                var alpha = Mathf.Clamp01(0.5f - d);

                col = Shade(col, d, fx, fy, 128f, 150f);
                if (Hash01(x / 7, y / 7) > 0.8f) col *= 0.8f;      // 腐敗の斑点
                if (d > -2.6f) col = outline;

                // 目のソケット(発光は別スプライトを重ねる)
                if (CircleD(fx, fy, 114f, 170f, 7f) < 0f || CircleD(fx, fy, 142f, 170f, 7f) < 0f) col = socketCol;

                col.a = alpha;
                return col;
            });
        }

        // 上から見た生存者(プレイヤー)。両腕で武器を前に構えている(上向きが正面)
        static void CreatePlayerBody()
        {
            var outline = Hex("#101820");
            var packCol = Hex("#22333d");
            var torsoCol = Hex("#2e4a5e");
            var padCol = Hex("#3f617a");
            var armCol = Hex("#35516a");
            var handCol = Hex("#4a7090");
            var helmetCol = Hex("#9fb8cc");
            var visorCol = Hex("#3fd2ff");

            CreateSpriteTexture("player_body", 256, 256, (x, y) =>
            {
                float fx = x + 0.5f, fy = y + 0.5f;

                var d = float.MaxValue;
                var col = torsoCol;
                Take(EllipseD(fx, fy, 128f, 92f, 26f, 16f), packCol, ref d, ref col);     // 背嚢
                Take(EllipseD(fx, fy, 128f, 124f, 46f, 38f), torsoCol, ref d, ref col);   // 胴・装甲
                Take(CircleD(fx, fy, 86f, 132f, 15f), padCol, ref d, ref col);            // 左肩パッド
                Take(CircleD(fx, fy, 170f, 132f, 15f), padCol, ref d, ref col);           // 右肩パッド
                Take(CapsuleD(fx, fy, 88f, 140f, 120f, 196f, 9f), armCol, ref d, ref col);    // 左腕(前で構える)
                Take(CapsuleD(fx, fy, 168f, 140f, 136f, 198f, 9f), armCol, ref d, ref col);   // 右腕
                Take(CircleD(fx, fy, 126f, 198f, 10f), handCol, ref d, ref col);          // 左手
                Take(CircleD(fx, fy, 138f, 196f, 10f), handCol, ref d, ref col);          // 右手
                Take(CircleD(fx, fy, 128f, 140f, 24f), helmetCol, ref d, ref col);        // ヘルメット

                if (d > 0.5f) return Color.clear;
                var alpha = Mathf.Clamp01(0.5f - d);

                col = Shade(col, d, fx, fy, 128f, 145f);
                if (d > -2.4f) col = outline;

                // 発光バイザー(味方=シアンの記号)
                if (EllipseD(fx, fy, 128f, 152f, 14f, 6f) < 0f) col = visorCol;

                col.a = alpha;
                return col;
            });
        }

        // 縁ほど暗く+中心をほんのり明るくして丸みを出す共通シェーディング
        static Color Shade(Color col, float d, float fx, float fy, float lightX, float lightY)
        {
            var t = Mathf.Clamp01(-d / 16f);
            col = Color.Lerp(col * 0.72f, col, t);
            var hd = Mathf.Sqrt((fx - lightX) * (fx - lightX) + (fy - lightY) * (fy - lightY));
            return Color.Lerp(col, col * 1.22f, Mathf.Clamp01(1f - hd / 95f) * 0.5f);
        }

        // ---------- SDF(距離関数) ----------

        static void Take(float newD, Color newCol, ref float d, ref Color col)
        {
            if (newD < d) { d = newD; col = newCol; }
        }

        static float CircleD(float x, float y, float cx, float cy, float r)
        {
            return Mathf.Sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) - r;
        }

        static float EllipseD(float x, float y, float cx, float cy, float rx, float ry)
        {
            var f = Mathf.Sqrt(((x - cx) / rx) * ((x - cx) / rx) + ((y - cy) / ry) * ((y - cy) / ry));
            return (f - 1f) * Mathf.Min(rx, ry);
        }

        static float CapsuleD(float x, float y, float ax, float ay, float bx, float by, float r)
        {
            float px = x - ax, py = y - ay, vx = bx - ax, vy = by - ay;
            var h = Mathf.Clamp01((px * vx + py * vy) / (vx * vx + vy * vy));
            float dx = px - vx * h, dy = py - vy * h;
            return Mathf.Sqrt(dx * dx + dy * dy) - r;
        }

        // ---------- PNG書き出し ----------

        static void CreateSpriteTexture(string name, int width, int height, Func<int, int, Color> colorAt)
        {
            var assetPath = ArtDir + "/" + name + ".png";
            var fullPath = Path.Combine(Directory.GetParent(Application.dataPath).FullName, assetPath.Replace('/', Path.DirectorySeparatorChar));
            Directory.CreateDirectory(Path.GetDirectoryName(fullPath));

            var texture = new Texture2D(width, height, TextureFormat.RGBA32, false);
            for (var y = 0; y < height; y++)
            {
                for (var x = 0; x < width; x++)
                {
                    texture.SetPixel(x, y, colorAt(x, y));
                }
            }
            texture.Apply();
            File.WriteAllBytes(fullPath, texture.EncodeToPNG());
            UnityEngine.Object.DestroyImmediate(texture);

            AssetDatabase.ImportAsset(assetPath, ImportAssetOptions.ForceUpdate);
            var importer = AssetImporter.GetAtPath(assetPath) as TextureImporter;
            if (importer == null) return;
            importer.textureType = TextureImporterType.Sprite;
            importer.spriteImportMode = SpriteImportMode.Single;
            importer.spritePixelsPerUnit = width;
            importer.mipmapEnabled = false;
            importer.alphaIsTransparency = true;
            importer.filterMode = FilterMode.Bilinear;
            importer.wrapMode = TextureWrapMode.Clamp;
            importer.SaveAndReimport();
        }

        static Color Hex(string hex)
        {
            if (!ColorUtility.TryParseHtmlString(hex, out var color)) color = Color.magenta;
            return color;
        }

        static float Hash01(int a, int b)
        {
            unchecked
            {
                var n = a * 73856093 ^ b * 19349663;
                n = (n << 13) ^ n;
                return ((n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff) / 2147483647f;
            }
        }
    }
}
#endif
