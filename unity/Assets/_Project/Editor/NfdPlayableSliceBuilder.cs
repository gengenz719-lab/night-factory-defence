#if UNITY_EDITOR
using System;
using System.IO;
using System.Linq;
using NightFactoryDefence;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace NightFactoryDefence.Editor
{
    public static class NfdPlayableSliceBuilder
    {
        const int GridW = 30;
        const int GridH = 17;
        const float Left = -GridW / 2f;
        const float Bottom = -GridH / 2f;

        const string Root = "Assets/_Project";
        const string ScenePath = Root + "/Scenes/PlayableSlice.unity";
        const string PrefabDir = Root + "/Prefabs/Runtime";
        const string PreviewPath = Root + "/ArtDirection/playable_slice_preview.png";

        static Material litMaterial;
        static Material unlitMaterial;

        [MenuItem("Night Factory Defence/Build Playable Slice")]
        public static void BuildPlayableSlice()
        {
            EnsureFolder("Assets", "_Project");
            EnsureFolder(Root, "Scenes");
            EnsureFolder(Root, "Prefabs");
            EnsureFolder(Root + "/Prefabs", "Runtime");
            EnsureFolder(Root, "ArtDirection");

            litMaterial = AssetDatabase.LoadAssetAtPath<Material>(Root + "/Materials/NfdSpriteLit.mat");
            unlitMaterial = AssetDatabase.LoadAssetAtPath<Material>(Root + "/Materials/NfdSpriteUnlit.mat");

            var bulletPrefab = CreateBulletPrefab();
            var enemyPrefab = CreateEnemyPrefab();

            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            scene.name = "PlayableSlice";

            var world = new GameObject("Playable Slice - moving gameplay").transform;
            var ground = AddGroup(world, "visual ground");
            var props = AddGroup(world, "factory props");
            var defences = AddGroup(world, "core and defences");

            DrawGround(ground);
            DrawFence(props);
            DrawOreAndMachines(props);
            var core = CreateCore(defences);
            CreateWallsAndTurrets(defences);
            var camera = CreateCamera();
            CreatePlayer(bulletPrefab, camera);
            CreateGameController(core, enemyPrefab);
            CreateLights();

            EditorSceneManager.SaveScene(scene, ScenePath);
            AddSceneToBuildSettings(ScenePath);
            ExportPreview(camera, PreviewPath);

            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log("Built playable Unity slice: " + ScenePath);
        }

        static NfdBullet CreateBulletPrefab()
        {
            var prefabPath = PrefabDir + "/Bullet.prefab";
            var existing = AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath);
            if (existing != null) return existing.GetComponent<NfdBullet>();

            var go = new GameObject("Bullet");
            CreateSpriteChild(go.transform, "visual", Sprite("circle"), Vector3.zero, new Vector2(0.24f, 0.24f), ColorFromHex("#ffe9a0"), 50);
            var bullet = go.AddComponent<NfdBullet>();
            SetSerialized(bullet, "speed", 13f);
            SetSerialized(bullet, "damage", 24f);
            SetSerialized(bullet, "lifeSeconds", 1.6f);
            SetSerialized(bullet, "hitRadius", 0.52f);
            PrefabUtility.SaveAsPrefabAsset(go, prefabPath);
            AssetDatabase.ImportAsset(prefabPath, ImportAssetOptions.ForceUpdate);
            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath).GetComponent<NfdBullet>();
            UnityEngine.Object.DestroyImmediate(go);
            return prefab;
        }

        static NfdEnemy CreateEnemyPrefab()
        {
            var prefabPath = PrefabDir + "/WalkerEnemy.prefab";
            var existing = AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath);
            if (existing != null) return existing.GetComponent<NfdEnemy>();

            var go = new GameObject("WalkerEnemy");
            CreateSpriteChild(go.transform, "body", Sprite("circle"), Vector3.zero, new Vector2(0.55f, 0.68f), ColorFromHex("#335b32"), 42);
            CreateSpriteChild(go.transform, "left eye", Sprite("square"), new Vector3(-0.11f, 0.09f, 0f), new Vector2(0.06f, 0.04f), ColorFromHex("#ff3b30"), 43);
            CreateSpriteChild(go.transform, "right eye", Sprite("square"), new Vector3(0.11f, 0.09f, 0f), new Vector2(0.06f, 0.04f), ColorFromHex("#ff3b30"), 43);
            var enemy = go.AddComponent<NfdEnemy>();
            SetSerialized(enemy, "maxHp", 42f);
            SetSerialized(enemy, "speed", 1.7f);
            SetSerialized(enemy, "contactDamagePerSecond", 18f);
            SetSerialized(enemy, "contactRange", 0.78f);
            PrefabUtility.SaveAsPrefabAsset(go, prefabPath);
            AssetDatabase.ImportAsset(prefabPath, ImportAssetOptions.ForceUpdate);
            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath).GetComponent<NfdEnemy>();
            UnityEngine.Object.DestroyImmediate(go);
            return prefab;
        }

        static void DrawGround(Transform parent)
        {
            var square = Sprite("square");
            for (var y = 0; y < GridH; y++)
            {
                for (var x = 0; x < GridW; x++)
                {
                    var color = Color.Lerp(ColorFromHex("#111821"), ColorFromHex("#202832"), Hash01(x, y));
                    if (x == 14 || x == 15 || y == 8) color = Color.Lerp(color, ColorFromHex("#2b3131"), 0.35f);
                    CreateSpriteChild(parent, $"floor {x},{y}", square, TileCenter(x, y), new Vector2(0.98f, 0.98f), color, 0);
                }
            }

            CreateSpriteChild(parent, "core glow", Sprite("soft_glow"), new Vector3(0f, 0.2f, 0f), new Vector2(6f, 4.8f), ColorFromHex("#3fd2ff", 0.18f), 20);
            CreateSpriteChild(parent, "north warning stripe", Sprite("hazard"), new Vector3(0f, 7.85f, 0f), new Vector2(10f, 0.32f), Color.white, 10);
            CreateSpriteChild(parent, "south warning stripe", Sprite("hazard"), new Vector3(0f, -7.85f, 0f), new Vector2(10f, 0.32f), Color.white, 10);
        }

        static void DrawFence(Transform parent)
        {
            var square = Sprite("square");
            CreateSpriteChild(parent, "north rail", square, new Vector3(0f, 8.28f, 0f), new Vector2(29.6f, 0.16f), ColorFromHex("#4a5360"), 8);
            CreateSpriteChild(parent, "south rail", square, new Vector3(0f, -8.28f, 0f), new Vector2(29.6f, 0.16f), ColorFromHex("#4a5360"), 8);
            CreateSpriteChild(parent, "west rail", square, new Vector3(-14.78f, 0f, 0f), new Vector2(0.16f, 16.6f), ColorFromHex("#4a5360"), 8);
            CreateSpriteChild(parent, "east rail", square, new Vector3(14.78f, 0f, 0f), new Vector2(0.16f, 16.6f), ColorFromHex("#4a5360"), 8);
            for (var x = -14; x <= 14; x += 2)
            {
                CreateSpriteChild(parent, "north post " + x, square, new Vector3(x, 8.18f, 0f), new Vector2(0.24f, 0.55f), ColorFromHex("#7a8390"), 9);
                CreateSpriteChild(parent, "south post " + x, square, new Vector3(x, -8.18f, 0f), new Vector2(0.24f, 0.55f), ColorFromHex("#7a8390"), 9);
            }
        }

        static void DrawOreAndMachines(Transform parent)
        {
            DrawOre(parent, new Vector3(-10.5f, 4.5f, 0f));
            DrawOre(parent, new Vector3(10f, -4.9f, 0f));
            DrawMachine(parent, "miner west", new Vector3(-10.5f, 4.5f, 0f), ColorFromHex("#5fb0d0"), ColorFromHex("#3fd2ff"));
            DrawMachine(parent, "miner east", new Vector3(10f, -4.9f, 0f), ColorFromHex("#5fb0d0"), ColorFromHex("#3fd2ff"));
            DrawMachine(parent, "furnace", new Vector3(-6.1f, -1.35f, 0f), ColorFromHex("#d0705f"), ColorFromHex("#ff6a1a"));
            DrawMachine(parent, "ammo press", new Vector3(5.75f, 2.6f, 0f), ColorFromHex("#d0aa47"), ColorFromHex("#3fd2ff"));
            DrawBelt(parent, new Vector3(-9.7f, 3.8f, 0f), new Vector3(-6.7f, -0.6f, 0f), 8);
            DrawBelt(parent, new Vector3(-5.3f, -1.0f, 0f), new Vector3(4.75f, 2.1f, 0f), 13);
            DrawBelt(parent, new Vector3(9.15f, -4.3f, 0f), new Vector3(5.95f, 1.75f, 0f), 9);
        }

        static void DrawOre(Transform parent, Vector3 center)
        {
            CreateSpriteChild(parent, "ore glow " + center, Sprite("soft_glow"), center, new Vector2(2.6f, 1.8f), ColorFromHex("#3fd2ff", 0.22f), 6);
            for (var i = 0; i < 7; i++)
            {
                var angle = i * 137.5f * Mathf.Deg2Rad;
                var p = center + new Vector3(Mathf.Cos(angle) * 0.55f, Mathf.Sin(angle) * 0.38f, 0f);
                CreateSpriteChild(parent, "ore shard " + i + center, Sprite("circle"), p, Vector2.one * 0.18f, ColorFromHex("#61d9ff"), 14);
            }
        }

        static void DrawMachine(Transform parent, string name, Vector3 pos, Color main, Color accent)
        {
            var group = AddGroup(parent, name);
            CreateSpriteChild(group, "shadow", Sprite("square"), pos + new Vector3(0.08f, -0.08f, 0f), new Vector2(1.34f, 1.04f), ColorFromHex("#030405", 0.45f), 10);
            CreateSpriteChild(group, "base", Sprite("square"), pos, new Vector2(1.2f, 0.94f), ColorFromHex("#222b34"), 15);
            CreateSpriteChild(group, "casing", Sprite("square"), pos, new Vector2(0.92f, 0.66f), main, 16);
            CreateSpriteChild(group, "status", Sprite("circle"), pos + new Vector3(0.43f, 0.19f, 0f), new Vector2(0.16f, 0.16f), accent, 18);
        }

        static void DrawBelt(Transform parent, Vector3 from, Vector3 to, int segments)
        {
            var delta = to - from;
            var angle = Mathf.Atan2(delta.y, delta.x) * Mathf.Rad2Deg;
            var step = delta / Mathf.Max(1, segments - 1);
            for (var i = 0; i < segments; i++)
            {
                var p = from + step * i;
                CreateSpriteChild(parent, "belt " + i + from, Sprite("square"), p, new Vector2(0.48f, 0.22f), ColorFromHex("#11151b"), 13, angle);
                if (i % 2 == 0) CreateSpriteChild(parent, "belt arrow " + i + from, Sprite("diamond"), p, new Vector2(0.18f, 0.1f), ColorFromHex("#ff8c3a"), 14, angle);
            }
        }

        static NfdCore CreateCore(Transform parent)
        {
            var root = new GameObject("Core");
            root.transform.SetParent(parent, false);
            root.transform.position = new Vector3(0f, 0.35f, 0f);
            var core = root.AddComponent<NfdCore>();
            CreateSpriteChild(root.transform, "base", Sprite("square"), Vector3.zero, new Vector2(2.25f, 2.25f), ColorFromHex("#17120b"), 31);
            CreateSpriteChild(root.transform, "plate", Sprite("diamond"), Vector3.zero, new Vector2(1.72f, 1.72f), ColorFromHex("#2c2412"), 32);
            CreateSpriteChild(root.transform, "reactor", Sprite("diamond"), Vector3.zero, new Vector2(1.1f, 1.1f), ColorFromHex("#ffd75e"), 33);
            CreateSpriteChild(root.transform, "cyan heart", Sprite("circle"), Vector3.zero, new Vector2(0.72f, 0.72f), ColorFromHex("#3fd2ff"), 34);
            CreateSpriteChild(root.transform, "orange heat", Sprite("circle"), Vector3.zero, new Vector2(0.36f, 0.36f), ColorFromHex("#ff6a1a"), 35);
            return core;
        }

        static void CreateWallsAndTurrets(Transform parent)
        {
            for (var x = -4; x <= 4; x++)
            {
                if (x == 0) continue;
                DrawWall(parent, new Vector3(x, 2.6f, 0f));
                DrawWall(parent, new Vector3(x, -2.1f, 0f));
            }

            DrawTurret(parent, new Vector3(-5.15f, 3.3f, 0f), 35f);
            DrawTurret(parent, new Vector3(5.15f, 3.3f, 0f), -35f);
            DrawTurret(parent, new Vector3(-5.15f, -2.85f, 0f), 140f);
            DrawTurret(parent, new Vector3(5.15f, -2.85f, 0f), -140f);
        }

        static void DrawWall(Transform parent, Vector3 pos)
        {
            CreateSpriteChild(parent, "wall " + pos, Sprite("square"), pos, new Vector2(0.86f, 0.68f), ColorFromHex("#8a8f98"), 25);
            CreateSpriteChild(parent, "wall face " + pos, Sprite("square"), pos + new Vector3(0f, 0.14f, 0f), new Vector2(0.7f, 0.13f), ColorFromHex("#c2c7cf", 0.55f), 26);
        }

        static void DrawTurret(Transform parent, Vector3 pos, float barrelAngle)
        {
            var group = AddGroup(parent, "turret " + pos);
            CreateSpriteChild(group, "range", Sprite("circle"), pos, new Vector2(3.8f, 3.8f), ColorFromHex("#e0b341", 0.075f), 21);
            CreateSpriteChild(group, "base", Sprite("circle"), pos, new Vector2(0.86f, 0.86f), ColorFromHex("#242b3a"), 36);
            CreateSpriteChild(group, "ring", Sprite("circle"), pos, new Vector2(0.62f, 0.62f), ColorFromHex("#e0b341"), 37);
            CreateSpriteChild(group, "barrel", Sprite("square"), pos + AngleOffset(barrelAngle, 0.42f), new Vector2(0.18f, 0.76f), ColorFromHex("#dce6ef"), 38, barrelAngle - 90f);
        }

        static void CreatePlayer(NfdBullet bulletPrefab, Camera camera)
        {
            var player = new GameObject("Player");
            player.transform.position = new Vector3(0f, -3.75f, 0f);
            CreateSpriteChild(player.transform, "body", Sprite("circle"), Vector3.zero, new Vector2(0.62f, 0.62f), ColorFromHex("#7fd0ff"), 60);
            var muzzle = CreateSpriteChild(player.transform, "muzzle", Sprite("square"), new Vector3(0f, 0.42f, 0f), new Vector2(0.13f, 0.42f), ColorFromHex("#e6e8ee"), 61);
            var controller = player.AddComponent<NfdPlayerController>();
            SetSerialized(controller, "bulletPrefab", bulletPrefab);
            SetSerialized(controller, "muzzle", muzzle.transform);
            SetSerialized(controller, "worldCamera", camera);
        }

        static void CreateGameController(NfdCore core, NfdEnemy enemyPrefab)
        {
            var go = new GameObject("GameController");
            var controller = go.AddComponent<NfdPlayableSliceController>();
            SetSerialized(controller, "core", core);
            SetSerialized(controller, "enemyPrefab", enemyPrefab);
            SetSerialized(controller, "enemyCount", 24);
            SetSerialized(controller, "spawnInterval", 0.8f);
        }

        static Camera CreateCamera()
        {
            var go = new GameObject("Main Camera");
            go.tag = "MainCamera";
            go.transform.position = new Vector3(0f, 0f, -10f);
            var camera = go.AddComponent<Camera>();
            camera.orthographic = true;
            camera.orthographicSize = 9.05f;
            camera.backgroundColor = ColorFromHex("#05070b");
            camera.clearFlags = CameraClearFlags.SolidColor;
            go.AddComponent<AudioListener>();
            return camera;
        }

        static void CreateLights()
        {
            var lightType = Type.GetType("UnityEngine.Rendering.Universal.Light2D, Unity.RenderPipelines.Universal.Runtime");
            if (lightType == null) return;

            AddLight2D("Global ambience", lightType, Vector3.zero, ColorFromHex("#8fb7ff"), 0.24f, 0f, true);
            AddLight2D("Core reactor light", lightType, new Vector3(0f, 0.35f, -1f), ColorFromHex("#3fd2ff"), 1.35f, 6.5f, false);
            AddLight2D("Furnace work light", lightType, new Vector3(-6.1f, -1.35f, -1f), ColorFromHex("#ff6a1a"), 0.95f, 4.2f, false);
        }

        static void AddLight2D(string name, Type type, Vector3 pos, Color color, float intensity, float radius, bool global)
        {
            var go = new GameObject(name);
            go.transform.position = pos;
            var light = go.AddComponent(type);
            SetMember(light, "lightType", global ? "Global" : "Point");
            SetMember(light, "color", color);
            SetMember(light, "intensity", intensity);
            if (!global) SetMember(light, "pointLightOuterRadius", radius);
        }

        static GameObject CreateSpriteChild(Transform parent, string name, Sprite sprite, Vector3 localPosition, Vector2 scale, Color color, int order, float rotationZ = 0f)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPosition;
            go.transform.localRotation = Quaternion.Euler(0f, 0f, rotationZ);
            go.transform.localScale = new Vector3(scale.x, scale.y, 1f);
            var renderer = go.AddComponent<SpriteRenderer>();
            renderer.sprite = sprite;
            renderer.color = color;
            renderer.sortingOrder = order;
            if (litMaterial != null && color.a >= 1f) renderer.material = litMaterial;
            else if (unlitMaterial != null) renderer.material = unlitMaterial;
            return go;
        }

        static Transform AddGroup(Transform parent, string name)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            return go.transform;
        }

        static Sprite Sprite(string name)
        {
            var sprite = AssetDatabase.LoadAssetAtPath<Sprite>(Root + "/Art/Generated/" + name + ".png");
            if (sprite == null) throw new FileNotFoundException("Generated sprite missing: " + name);
            return sprite;
        }

        static Vector3 TileCenter(int x, int y) => new(Left + x + 0.5f, Bottom + y + 0.5f, 0f);

        static Vector3 AngleOffset(float degrees, float distance)
        {
            var rad = degrees * Mathf.Deg2Rad;
            return new Vector3(Mathf.Cos(rad) * distance, Mathf.Sin(rad) * distance, 0f);
        }

        static void SetSerialized(UnityEngine.Object target, string propertyName, object value)
        {
            var serialized = new SerializedObject(target);
            var property = serialized.FindProperty(propertyName);
            if (property == null) throw new MissingFieldException(target.GetType().Name, propertyName);

            switch (value)
            {
                case int i:
                    property.intValue = i;
                    break;
                case float f:
                    property.floatValue = f;
                    break;
                case UnityEngine.Object obj:
                    property.objectReferenceValue = obj;
                    break;
                default:
                    throw new NotSupportedException("Unsupported serialized value: " + value);
            }

            serialized.ApplyModifiedPropertiesWithoutUndo();

            var field = target.GetType().GetField(propertyName, System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Public);
            if (field != null)
            {
                field.SetValue(target, value);
            }
            EditorUtility.SetDirty(target);
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
            if (field != null) field.SetValue(target, ConvertValue(field.FieldType, value));
        }

        static object ConvertValue(Type type, object value)
        {
            if (value is string text && type.IsEnum) return Enum.Parse(type, text);
            return value;
        }

        static Color ColorFromHex(string hex, float alphaOverride = -1f)
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

        static void AddSceneToBuildSettings(string scenePath)
        {
            var scenes = EditorBuildSettings.scenes.ToList();
            if (scenes.All(s => s.path != scenePath))
            {
                scenes.Add(new EditorBuildSettingsScene(scenePath, true));
                EditorBuildSettings.scenes = scenes.ToArray();
            }
        }

        static void ExportPreview(Camera camera, string assetPath)
        {
            var fullPath = Path.Combine(Directory.GetParent(Application.dataPath).FullName, assetPath.Replace('/', Path.DirectorySeparatorChar));
            Directory.CreateDirectory(Path.GetDirectoryName(fullPath));

            var rt = new RenderTexture(1600, 900, 24, RenderTextureFormat.ARGB32);
            var previousTarget = camera.targetTexture;
            var previousActive = RenderTexture.active;
            camera.targetTexture = rt;
            RenderTexture.active = rt;
            camera.Render();

            var image = new Texture2D(rt.width, rt.height, TextureFormat.RGBA32, false);
            image.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
            image.Apply();
            File.WriteAllBytes(fullPath, image.EncodeToPNG());

            camera.targetTexture = previousTarget;
            RenderTexture.active = previousActive;
            UnityEngine.Object.DestroyImmediate(image);
            UnityEngine.Object.DestroyImmediate(rt);
            AssetDatabase.ImportAsset(assetPath, ImportAssetOptions.ForceUpdate);
        }

        static void EnsureFolder(string parent, string name)
        {
            var path = parent + "/" + name;
            if (!AssetDatabase.IsValidFolder(path)) AssetDatabase.CreateFolder(parent, name);
        }
    }
}
#endif
