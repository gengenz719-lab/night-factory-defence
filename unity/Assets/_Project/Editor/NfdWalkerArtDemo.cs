#if UNITY_EDITOR
using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace NightFactoryDefence.Editor
{
    // Walkerゾンビの見た目アップグレードのデモ。
    // メニュー1回で「改修前スクショ → スプライト生成 → プレハブ改修 → 改修後スクショ」まで自動で行う。
    public static class NfdWalkerArtDemo
    {
        const string Root = "Assets/_Project";
        const string ArtDir = Root + "/Art/Generated";
        const string PreviewDir = Root + "/ArtDirection";
        const string PrefabPath = Root + "/Prefabs/Runtime/WalkerEnemy.prefab";
        const string LitMaterialPath = Root + "/Materials/NfdSpriteLit.mat";
        const string UnlitMaterialPath = Root + "/Materials/NfdSpriteUnlit.mat";
        const string PlayableScenePath = Root + "/Scenes/PlayableSlice.unity";

        static Material spriteLit;
        static Material spriteUnlit;

        [MenuItem("Night Factory Defence/Walker Art Demo (Before-After)")]
        public static void Run()
        {
            // ユーザーの未保存シーンを失わないよう、先に保存しておく
            EditorSceneManager.SaveOpenScenes();

            spriteLit = AssetDatabase.LoadAssetAtPath<Material>(LitMaterialPath);
            spriteUnlit = AssetDatabase.LoadAssetAtPath<Material>(UnlitMaterialPath);

            // 1. 改修前の姿を撮影
            BuildDemoSceneAndCapture(PreviewDir + "/walker_before.png");

            // 2. 新スプライト生成 + プレハブ改修
            CreateWalkerBodySprite();
            AssetDatabase.Refresh();
            UpgradeWalkerPrefab();

            // 3. 改修後の姿を撮影
            BuildDemoSceneAndCapture(PreviewDir + "/walker_after.png");

            // 4. 元のシーンに戻す
            EditorSceneManager.OpenScene(PlayableScenePath);
            AssetDatabase.SaveAssets();
            Debug.Log("Walker art demo done: walker_before.png / walker_after.png");
        }

        // ---------- 撮影用のミニシーン ----------

        static void BuildDemoSceneAndCapture(string previewPath)
        {
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            var root = new GameObject("Walker Demo").transform;

            DrawFloor(root);
            AddLight(root, "moon ambience", Vector3.zero, Hex("#8fb7ff"), 0.32f, 0f, 0f, true);
            AddLight(root, "core cyan light", new Vector3(0f, -0.6f, -1f), Hex("#3fd2ff"), 1.1f, 5f, 1f);
            AddLight(root, "furnace warm light", new Vector3(3.4f, 1.2f, -1f), Hex("#ff6a1a"), 0.6f, 3.5f, 0.6f);
            AddLight(root, "danger red light", new Vector3(-3.6f, 1.1f, -1f), Hex("#ff3b30"), 0.5f, 3f, 0.4f);

            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(PrefabPath);
            PlaceWalker(prefab, new Vector3(-2.6f, 0.15f, 0f), 15f);
            PlaceWalker(prefab, new Vector3(0f, -0.15f, 0f), -30f);
            PlaceWalker(prefab, new Vector3(2.6f, 0.2f, 0f), 50f);

            var camera = CreateCamera();
            ExportPreview(camera, previewPath, 1400, 640);
        }

        static void PlaceWalker(GameObject prefab, Vector3 pos, float angle)
        {
            var instance = (GameObject)PrefabUtility.InstantiatePrefab(prefab);
            instance.transform.position = pos;
            // 改修後プレハブは "visual" 子を回す。改修前はルートごと回す
            var visual = instance.transform.Find("visual");
            (visual != null ? visual : instance.transform).rotation = Quaternion.Euler(0f, 0f, angle);
        }

        static void DrawFloor(Transform parent)
        {
            var square = Sprite("square");
            var glow = Sprite("soft_glow");
            for (var y = 0; y < 7; y++)
            {
                for (var x = 0; x < 14; x++)
                {
                    var n = Hash01(x, y);
                    var baseColor = Color.Lerp(Hex("#111821"), Hex("#1c2630"), n);
                    if ((x + y) % 7 == 0) baseColor = Color.Lerp(baseColor, Hex("#26303a"), 0.35f);
                    CreateSprite("floor " + x + "," + y, square, new Vector3(-7f + x + 0.5f, -3.5f + y + 0.5f, 0f), new Vector2(0.98f, 0.98f), baseColor, 0, parent);
                }
            }
            CreateSprite("vignette", glow, new Vector3(0f, 0f, 1f), new Vector2(16f, 8f), Hex("#000000", 0.25f), 80, parent);
        }

        // ---------- 新しいWalkerスプライト(上から見た歩行ゾンビ) ----------

        static void CreateWalkerBodySprite()
        {
            const int size = 256;
            var outline = Hex("#16200f");
            var socketCol = Hex("#0d140a");
            var torsoCol = Hex("#43603a");
            var headCol = Hex("#4f7345");
            var limbCol = Hex("#38512f");
            var handCol = Hex("#466339");

            CreateSpriteTexture("walker_body", size, size, (x, y) =>
            {
                float fx = x + 0.5f, fy = y + 0.5f;

                // 体のパーツをSDF(距離)で合成。上向きが正面
                var d = float.MaxValue;
                var col = torsoCol;
                Take(EllipseD(fx, fy, 128f, 122f, 54f, 46f), torsoCol, ref d, ref col);   // 肩・胴
                Take(EllipseD(fx, fy, 128f, 88f, 38f, 30f), limbCol, ref d, ref col);     // 腰
                Take(CircleD(fx, fy, 128f, 162f, 36f), headCol, ref d, ref col);          // 頭
                Take(CapsuleD(fx, fy, 86f, 138f, 70f, 196f, 13f), limbCol, ref d, ref col);   // 左腕(前に伸ばす)
                Take(CapsuleD(fx, fy, 170f, 138f, 182f, 188f, 12f), limbCol, ref d, ref col); // 右腕(少し短く=非対称)
                Take(CircleD(fx, fy, 69f, 204f, 16f), handCol, ref d, ref col);           // 左手
                Take(CircleD(fx, fy, 183f, 196f, 15f), handCol, ref d, ref col);          // 右手

                if (d > 0.5f) return Color.clear;
                var alpha = Mathf.Clamp01(0.5f - d); // 縁を1pxなめらかに

                // 縁ほど暗くして丸みを出す + 中心をほんのり明るく
                var t = Mathf.Clamp01(-d / 16f);
                col = Color.Lerp(col * 0.72f, col, t);
                var hd = Mathf.Sqrt((fx - 128f) * (fx - 128f) + (fy - 150f) * (fy - 150f));
                col = Color.Lerp(col, col * 1.22f, Mathf.Clamp01(1f - hd / 95f) * 0.5f);

                // 腐敗の斑点(ブロックノイズ)
                if (Hash01(x / 7, y / 7) > 0.8f) col *= 0.8f;

                // アウトライン
                if (d > -2.6f) col = outline;

                // 目のソケット(発光は別スプライトを重ねる)
                if (CircleD(fx, fy, 114f, 170f, 7f) < 0f || CircleD(fx, fy, 142f, 170f, 7f) < 0f) col = socketCol;

                col.a = alpha;
                return col;
            });
        }

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

        // ---------- プレハブ改修 ----------

        static void UpgradeWalkerPrefab()
        {
            var root = PrefabUtility.LoadPrefabContents(PrefabPath);

            // 古い見た目(body / left eye / right eye)を全部除去
            foreach (var child in root.transform.Cast<Transform>().ToArray())
            {
                UnityEngine.Object.DestroyImmediate(child.gameObject);
            }

            // 新しい見た目: 回転用の "visual" の下に重ねる
            var visual = new GameObject("visual").transform;
            visual.SetParent(root.transform, false);

            CreateSprite("under glow", Sprite("soft_glow"), Vector3.zero, new Vector2(1.7f, 1.7f), Hex("#6fae4f", 0.3f), 40, visual);
            CreateSprite("shadow", Sprite("circle"), new Vector3(0.05f, -0.12f, 0f), new Vector2(0.9f, 0.68f), Hex("#030405", 0.55f), 41, visual);
            CreateSprite("body", Sprite("walker_body"), Vector3.zero, new Vector2(1.15f, 1.15f), Color.white, 42, visual);
            CreateSprite("eye glow left", Sprite("soft_glow"), new Vector3(-0.063f, 0.189f, 0f), new Vector2(0.26f, 0.26f), Hex("#ff3b30", 0.85f), 43, visual);
            CreateSprite("eye glow right", Sprite("soft_glow"), new Vector3(0.063f, 0.189f, 0f), new Vector2(0.26f, 0.26f), Hex("#ff3b30", 0.85f), 43, visual);
            CreateSprite("eye dot left", Sprite("circle"), new Vector3(-0.063f, 0.189f, 0f), new Vector2(0.05f, 0.05f), Hex("#ffb0a0", 0.999f), 44, visual);
            CreateSprite("eye dot right", Sprite("circle"), new Vector3(0.063f, 0.189f, 0f), new Vector2(0.05f, 0.05f), Hex("#ffb0a0", 0.999f), 44, visual);

            if (root.GetComponent<NfdEnemyVisual>() == null)
            {
                root.AddComponent<NfdEnemyVisual>();
            }

            PrefabUtility.SaveAsPrefabAsset(root, PrefabPath);
            PrefabUtility.UnloadPrefabContents(root);
        }

        // ---------- 共通ヘルパー(NfdWorldVisualBuilderと同じ流儀) ----------

        static GameObject CreateSprite(string name, Sprite sprite, Vector3 localPos, Vector2 scale, Color color, int order, Transform parent)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            go.transform.localScale = new Vector3(scale.x, scale.y, 1f);
            var renderer = go.AddComponent<SpriteRenderer>();
            renderer.sprite = sprite;
            renderer.color = color;
            renderer.sortingOrder = order;
            renderer.material = color.a < 1f ? spriteUnlit : spriteLit;
            return go;
        }

        static Sprite Sprite(string name)
        {
            return AssetDatabase.LoadAssetAtPath<Sprite>(ArtDir + "/" + name + ".png");
        }

        static Camera CreateCamera()
        {
            var go = new GameObject("Main Camera");
            go.tag = "MainCamera";
            go.transform.position = new Vector3(0f, 0f, -10f);
            var camera = go.AddComponent<Camera>();
            camera.orthographic = true;
            camera.orthographicSize = 2.05f;
            camera.backgroundColor = Hex("#05070b");
            camera.clearFlags = CameraClearFlags.SolidColor;
            return camera;
        }

        static void CreateSpriteTexture(string name, int width, int height, Func<int, int, Color> colorAt)
        {
            var assetPath = ArtDir + "/" + name + ".png";
            var fullPath = FullPath(assetPath);
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

        static void AddLight(Transform parent, string name, Vector3 position, Color color, float intensity, float outerRadius, float innerRadius, bool global = false)
        {
            var lightType = Type.GetType("UnityEngine.Rendering.Universal.Light2D, Unity.RenderPipelines.Universal.Runtime");
            if (lightType == null) return;

            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            go.transform.position = position;
            var component = go.AddComponent(lightType);
            SetMember(component, "lightType", global ? "Global" : "Point");
            SetMember(component, "color", color);
            SetMember(component, "intensity", intensity);
            if (!global)
            {
                SetMember(component, "pointLightOuterRadius", outerRadius);
                SetMember(component, "pointLightInnerRadius", innerRadius);
            }
        }

        static void ExportPreview(Camera camera, string assetPath, int width, int height)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(FullPath(assetPath)));
            var rt = new RenderTexture(width, height, 24, RenderTextureFormat.ARGB32);
            var previousActive = RenderTexture.active;
            camera.targetTexture = rt;
            RenderTexture.active = rt;
            camera.Render();

            var image = new Texture2D(rt.width, rt.height, TextureFormat.RGBA32, false);
            image.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
            image.Apply();
            File.WriteAllBytes(FullPath(assetPath), image.EncodeToPNG());

            camera.targetTexture = null;
            RenderTexture.active = previousActive;
            UnityEngine.Object.DestroyImmediate(image);
            UnityEngine.Object.DestroyImmediate(rt);
            AssetDatabase.ImportAsset(assetPath, ImportAssetOptions.ForceUpdate);
        }

        static string FullPath(string assetPath)
        {
            var projectRoot = Directory.GetParent(Application.dataPath).FullName;
            return Path.Combine(projectRoot, assetPath.Replace('/', Path.DirectorySeparatorChar));
        }

        static Color Hex(string hex, float alphaOverride = -1f)
        {
            if (!ColorUtility.TryParseHtmlString(hex, out var color)) color = Color.magenta;
            if (alphaOverride >= 0f) color.a = alphaOverride;
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

        static void SetMember(object target, string memberName, object value)
        {
            var type = target.GetType();
            var property = type.GetProperty(memberName);
            if (property != null)
            {
                property.SetValue(target, ConvertValue(property.PropertyType, value));
                return;
            }
            var field = type.GetField(memberName);
            if (field != null)
            {
                field.SetValue(target, ConvertValue(field.FieldType, value));
            }
        }

        static object ConvertValue(Type type, object value)
        {
            if (value is string text && type.IsEnum) return Enum.Parse(type, text);
            if (type == typeof(float) && value is double d) return (float)d;
            return value;
        }
    }
}
#endif
