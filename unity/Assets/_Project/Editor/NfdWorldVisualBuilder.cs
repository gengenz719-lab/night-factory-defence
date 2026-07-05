#if UNITY_EDITOR
using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace NightFactoryDefence.Editor
{
    public static class NfdWorldVisualBuilder
    {
        const int GridW = 30;
        const int GridH = 17;
        const float Left = -GridW / 2f;
        const float Bottom = -GridH / 2f;

        const string Root = "Assets/_Project";
        const string ScenesDir = Root + "/Scenes";
        const string ArtDir = Root + "/Art/Generated";
        const string MaterialDir = Root + "/Materials";
        const string PreviewDir = Root + "/ArtDirection";
        const string ScenePath = ScenesDir + "/WorldVisualPrototype.unity";
        const string LitMaterialPath = MaterialDir + "/NfdSpriteLit.mat";
        const string UnlitMaterialPath = MaterialDir + "/NfdSpriteUnlit.mat";

        static Material spriteLit;
        static Material spriteUnlit;

        [MenuItem("Night Factory Defence/Build World Visual Prototype")]
        public static void BuildWorldVisualSlice()
        {
            EnsureProjectFolders();
            CreateGeneratedSprites();
            CreateMaterials();
            AssetDatabase.Refresh();

            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            scene.name = "WorldVisualPrototype";

            var root = new GameObject("World Visual Prototype").transform;
            var ground = AddGroup(root, "Layer 00 - cracked asphalt factory yard");
            var props = AddGroup(root, "Layer 10 - industrial props");
            var buildings = AddGroup(root, "Layer 20 - defence and factory machines");
            var enemies = AddGroup(root, "Layer 30 - enemy silhouettes");
            var lights = AddGroup(root, "Layer 90 - 2D lights");

            DrawFactoryYard(ground);
            DrawOuterFence(props);
            DrawOreFields(props);
            DrawFactoryFlow(props);
            DrawCoreAndDefences(buildings, lights);
            DrawEnemyPressure(enemies, lights);

            var camera = CreateCamera();
            AddGlobalLight(lights);
            AddLight(lights, "Core cyan reactor light", new Vector3(0f, 0.25f, -1f), ColorFromHex("#3fd2ff"), 1.35f, 6.5f, 1.2f);
            AddLight(lights, "Furnace orange work light", new Vector3(-6f, -1.35f, -1f), ColorFromHex("#ff6a1a"), 0.9f, 4.2f, 0.8f);
            AddLight(lights, "Ammo line cool light", new Vector3(5.75f, 2.6f, -1f), ColorFromHex("#3fd2ff"), 0.7f, 3.6f, 0.5f);

            EditorSceneManager.SaveScene(scene, ScenePath);
            AddSceneToBuildSettings(ScenePath);
            ExportPreview(camera, PreviewDir + "/world_visual_prototype_preview.png");

            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log("Built Night Factory Defence world visual prototype: " + ScenePath);
        }

        static void DrawFactoryYard(Transform parent)
        {
            var square = Sprite("square");
            var circle = Sprite("circle");
            var glow = Sprite("soft_glow");

            for (var y = 0; y < GridH; y++)
            {
                for (var x = 0; x < GridW; x++)
                {
                    var n = Hash01(x, y);
                    var baseColor = Color.Lerp(ColorFromHex("#111821"), ColorFromHex("#1c2630"), n);
                    if ((x + y) % 7 == 0) baseColor = Color.Lerp(baseColor, ColorFromHex("#26303a"), 0.35f);
                    if (x == 14 || x == 15 || y == 8) baseColor = Color.Lerp(baseColor, ColorFromHex("#2a3030"), 0.35f);
                    CreateSprite("floor tile " + x + "," + y, square, TileCenter(x, y), new Vector2(0.98f, 0.98f), baseColor, 0, parent);
                }
            }

            for (var x = 0; x <= GridW; x++)
            {
                CreateSprite("vertical expansion joint " + x, square, new Vector3(Left + x, 0f, 0f), new Vector2(0.025f, GridH), ColorFromHex("#05080d", 0.45f), 1, parent);
            }

            for (var y = 0; y <= GridH; y++)
            {
                CreateSprite("horizontal expansion joint " + y, square, new Vector3(0f, Bottom + y, 0f), new Vector2(GridW, 0.025f), ColorFromHex("#05080d", 0.45f), 1, parent);
            }

            CreateSprite("old oil stain west", circle, new Vector3(-9.25f, -2.9f, 0f), new Vector2(3.7f, 1.15f), ColorFromHex("#050607", 0.5f), 2, parent, 11f);
            CreateSprite("old oil stain north", circle, new Vector3(4.2f, 5.3f, 0f), new Vector2(3.2f, 1.0f), ColorFromHex("#07090c", 0.42f), 2, parent, -17f);
            CreateSprite("cold night vignette", glow, new Vector3(0f, 0f, 1f), new Vector2(31f, 19f), ColorFromHex("#000000", 0.28f), 80, parent);
        }

        static void DrawOuterFence(Transform parent)
        {
            var square = Sprite("square");
            var hazard = Sprite("hazard");

            CreateSprite("north perimeter rail", square, new Vector3(0f, 8.28f, 0f), new Vector2(29.6f, 0.16f), ColorFromHex("#4a5360"), 8, parent);
            CreateSprite("south perimeter rail", square, new Vector3(0f, -8.28f, 0f), new Vector2(29.6f, 0.16f), ColorFromHex("#4a5360"), 8, parent);
            CreateSprite("west perimeter rail", square, new Vector3(-14.78f, 0f, 0f), new Vector2(0.16f, 16.6f), ColorFromHex("#4a5360"), 8, parent);
            CreateSprite("east perimeter rail", square, new Vector3(14.78f, 0f, 0f), new Vector2(0.16f, 16.6f), ColorFromHex("#4a5360"), 8, parent);

            for (var x = -14; x <= 14; x += 2)
            {
                CreateSprite("north fence post " + x, square, new Vector3(x, 8.18f, 0f), new Vector2(0.24f, 0.55f), ColorFromHex("#7a8390"), 9, parent);
                CreateSprite("south fence post " + x, square, new Vector3(x, -8.18f, 0f), new Vector2(0.24f, 0.55f), ColorFromHex("#7a8390"), 9, parent);
            }

            for (var y = -7; y <= 7; y += 2)
            {
                CreateSprite("west fence post " + y, square, new Vector3(-14.7f, y, 0f), new Vector2(0.55f, 0.24f), ColorFromHex("#7a8390"), 9, parent);
                CreateSprite("east fence post " + y, square, new Vector3(14.7f, y, 0f), new Vector2(0.55f, 0.24f), ColorFromHex("#7a8390"), 9, parent);
            }

            CreateSprite("north warning chevron", hazard, new Vector3(0f, 7.85f, 0f), new Vector2(10f, 0.32f), Color.white, 10, parent);
            CreateSprite("south warning chevron", hazard, new Vector3(0f, -7.85f, 0f), new Vector2(10f, 0.32f), Color.white, 10, parent);
        }

        static void DrawOreFields(Transform parent)
        {
            DrawOrePatch(parent, new Vector3(-10.5f, 4.5f, 0f), 7, 0.55f);
            DrawOrePatch(parent, new Vector3(10.0f, -4.9f, 0f), 8, 0.58f);
            DrawOrePatch(parent, new Vector3(-4.0f, -5.9f, 0f), 6, 0.48f);
        }

        static void DrawOrePatch(Transform parent, Vector3 center, int rocks, float radius)
        {
            var square = Sprite("square");
            var circle = Sprite("circle");
            var glow = Sprite("soft_glow");

            CreateSprite("ore bed glow " + center, glow, center + Vector3.back * 0.1f, new Vector2(2.7f, 2f), ColorFromHex("#3fd2ff", 0.22f), 6, parent);
            for (var i = 0; i < rocks; i++)
            {
                var angle = i * 137.5f * Mathf.Deg2Rad;
                var r = radius * (0.35f + Hash01(i, rocks) * 1.2f);
                var p = center + new Vector3(Mathf.Cos(angle) * r, Mathf.Sin(angle) * r * 0.7f, 0f);
                CreateSprite("ore shard " + i + " " + center, circle, p, Vector2.one * (0.16f + Hash01(rocks, i) * 0.18f), ColorFromHex("#61d9ff"), 14, parent);
            }

            CreateSprite("ore cracked tile " + center, square, center, new Vector2(1.45f, 1.0f), ColorFromHex("#172b3a", 0.75f), 5, parent, 3f);
        }

        static void DrawFactoryFlow(Transform parent)
        {
            var square = Sprite("square");
            var diamond = Sprite("diamond");

            DrawMachine(parent, "west miner", new Vector3(-10.5f, 4.5f, 0f), ColorFromHex("#5fb0d0"), ColorFromHex("#163040"), true);
            DrawMachine(parent, "east miner", new Vector3(10.0f, -4.9f, 0f), ColorFromHex("#5fb0d0"), ColorFromHex("#163040"), true);
            DrawMachine(parent, "south smelter", new Vector3(-6.1f, -1.35f, 0f), ColorFromHex("#d0705f"), ColorFromHex("#ff6a1a"), false);
            DrawMachine(parent, "ammo press", new Vector3(5.75f, 2.6f, 0f), ColorFromHex("#d0aa47"), ColorFromHex("#3fd2ff"), false);

            DrawBelt(parent, new Vector3(-9.7f, 3.8f, 0f), new Vector3(-6.7f, -0.6f, 0f), 8);
            DrawBelt(parent, new Vector3(-5.3f, -1.0f, 0f), new Vector3(4.75f, 2.1f, 0f), 13);
            DrawBelt(parent, new Vector3(9.15f, -4.3f, 0f), new Vector3(5.95f, 1.75f, 0f), 9);

            for (var i = 0; i < 5; i++)
            {
                CreateSprite("ammo crate " + i, square, new Vector3(6.9f + i * 0.33f, 3.35f - (i % 2) * 0.28f, 0f), new Vector2(0.28f, 0.22f), ColorFromHex("#d9b95a"), 18, parent);
                CreateSprite("ammo crate blue latch " + i, square, new Vector3(6.9f + i * 0.33f, 3.35f - (i % 2) * 0.28f, 0f), new Vector2(0.08f, 0.23f), ColorFromHex("#3fd2ff"), 19, parent);
            }

            CreateSprite("factory cable trunk north", square, new Vector3(0f, 4.95f, 0f), new Vector2(11f, 0.08f), ColorFromHex("#15191f"), 12, parent);
            for (var x = -5; x <= 5; x++)
            {
                CreateSprite("cable cyan marker " + x, diamond, new Vector3(x, 4.95f, 0f), new Vector2(0.16f, 0.16f), ColorFromHex("#3fd2ff", 0.72f), 13, parent);
            }
        }

        static void DrawMachine(Transform parent, string name, Vector3 pos, Color main, Color accent, bool drill)
        {
            var square = Sprite("square");
            var circle = Sprite("circle");
            var diamond = Sprite("diamond");
            var group = AddGroup(parent, name);

            CreateSprite(name + " shadow", square, pos + new Vector3(0.08f, -0.08f, 0f), new Vector2(1.34f, 1.04f), ColorFromHex("#030405", 0.45f), 10, group);
            CreateSprite(name + " base", square, pos, new Vector2(1.2f, 0.94f), ColorFromHex("#222b34"), 15, group);
            CreateSprite(name + " casing", square, pos, new Vector2(0.92f, 0.66f), main, 16, group);
            CreateSprite(name + " top panel", square, pos + new Vector3(0f, 0.21f, 0f), new Vector2(0.74f, 0.13f), ColorFromHex("#e8ecf2", 0.42f), 17, group);
            CreateSprite(name + " status light", circle, pos + new Vector3(0.43f, 0.19f, 0f), new Vector2(0.16f, 0.16f), accent, 18, group);

            if (drill)
            {
                CreateSprite(name + " drill bit", diamond, pos + new Vector3(0f, -0.35f, 0f), new Vector2(0.28f, 0.55f), ColorFromHex("#c7d2df"), 19, group);
                CreateSprite(name + " scan glow", Sprite("soft_glow"), pos + new Vector3(0f, -0.38f, 0f), new Vector2(1.6f, 0.8f), ColorFromHex("#3fd2ff", 0.2f), 14, group);
            }
            else
            {
                CreateSprite(name + " furnace slit", square, pos + new Vector3(0f, -0.23f, 0f), new Vector2(0.52f, 0.13f), accent, 19, group);
                CreateSprite(name + " heat glow", Sprite("soft_glow"), pos + new Vector3(0f, -0.15f, 0f), new Vector2(1.8f, 1.2f), ColorFromHex("#ff6a1a", 0.22f), 14, group);
            }
        }

        static void DrawBelt(Transform parent, Vector3 from, Vector3 to, int segments)
        {
            var square = Sprite("square");
            var diamond = Sprite("diamond");
            var delta = to - from;
            var angle = Mathf.Atan2(delta.y, delta.x) * Mathf.Rad2Deg;
            var step = delta / Mathf.Max(1, segments - 1);

            for (var i = 0; i < segments; i++)
            {
                var p = from + step * i;
                CreateSprite("conveyor belt " + from + " " + i, square, p, new Vector2(0.48f, 0.22f), ColorFromHex("#11151b"), 13, parent, angle);
                if (i % 2 == 0)
                {
                    CreateSprite("conveyor arrow " + from + " " + i, diamond, p, new Vector2(0.18f, 0.1f), ColorFromHex("#ff8c3a"), 14, parent, angle);
                }
            }
        }

        static void DrawCoreAndDefences(Transform parent, Transform lights)
        {
            var square = Sprite("square");
            var circle = Sprite("circle");
            var diamond = Sprite("diamond");
            var glow = Sprite("soft_glow");
            var hazard = Sprite("hazard");

            var corePos = new Vector3(0f, 0.35f, 0f);
            var core = AddGroup(parent, "reactor core defensive focus");

            CreateSprite("core ground glow", glow, corePos, new Vector2(5.8f, 5.0f), ColorFromHex("#3fd2ff", 0.18f), 20, core);
            CreateSprite("core hazard north", hazard, corePos + new Vector3(0f, 1.42f, 0f), new Vector2(2.65f, 0.26f), Color.white, 30, core);
            CreateSprite("core hazard south", hazard, corePos + new Vector3(0f, -1.42f, 0f), new Vector2(2.65f, 0.26f), Color.white, 30, core);
            CreateSprite("core base", square, corePos, new Vector2(2.25f, 2.25f), ColorFromHex("#17120b"), 31, core);
            CreateSprite("core armored plate", square, corePos, new Vector2(1.72f, 1.72f), ColorFromHex("#2c2412"), 32, core, 45f);
            CreateSprite("core reactor diamond", diamond, corePos, new Vector2(1.1f, 1.1f), ColorFromHex("#ffd75e"), 33, core);
            CreateSprite("core cyan heart", circle, corePos, new Vector2(0.72f, 0.72f), ColorFromHex("#3fd2ff"), 34, core);
            CreateSprite("core inner heat", circle, corePos, new Vector2(0.36f, 0.36f), ColorFromHex("#ff6a1a"), 35, core);

            AddLight(lights, "north turret lamp", new Vector3(-4.7f, 3.35f, -1f), ColorFromHex("#ff8c3a"), 0.55f, 3f, 0.4f);
            AddLight(lights, "east turret lamp", new Vector3(5.1f, 3.35f, -1f), ColorFromHex("#ff8c3a"), 0.55f, 3f, 0.4f);

            for (var x = -4; x <= 4; x++)
            {
                if (x == 0) continue;
                DrawWall(parent, new Vector3(x, 2.6f, 0f), x % 2 == 0);
                DrawWall(parent, new Vector3(x, -2.1f, 0f), x % 2 != 0);
            }

            for (var y = -1; y <= 2; y++)
            {
                if (y == 0) continue;
                DrawWall(parent, new Vector3(-4.8f, y, 0f), y % 2 == 0);
                DrawWall(parent, new Vector3(4.8f, y, 0f), y % 2 != 0);
            }

            DrawTurret(parent, new Vector3(-5.15f, 3.3f, 0f), 35f);
            DrawTurret(parent, new Vector3(5.15f, 3.3f, 0f), -35f);
            DrawTurret(parent, new Vector3(-5.15f, -2.85f, 0f), 140f);
            DrawTurret(parent, new Vector3(5.15f, -2.85f, 0f), -140f);
        }

        static void DrawWall(Transform parent, Vector3 pos, bool lit)
        {
            var square = Sprite("square");
            CreateSprite("wall shadow " + pos, square, pos + new Vector3(0.04f, -0.06f, 0f), new Vector2(0.96f, 0.78f), ColorFromHex("#030405", 0.5f), 24, parent);
            CreateSprite("wall block " + pos, square, pos, new Vector2(0.86f, 0.68f), ColorFromHex("#8a8f98"), 25, parent);
            CreateSprite("wall face " + pos, square, pos + new Vector3(0f, 0.14f, 0f), new Vector2(0.7f, 0.13f), ColorFromHex("#c2c7cf", 0.55f), 26, parent);
            if (lit)
            {
                CreateSprite("wall warning stripe " + pos, Sprite("hazard"), pos + new Vector3(0f, -0.19f, 0f), new Vector2(0.58f, 0.12f), Color.white, 27, parent);
            }
        }

        static void DrawTurret(Transform parent, Vector3 pos, float barrelAngle)
        {
            var square = Sprite("square");
            var circle = Sprite("circle");
            var glow = Sprite("soft_glow");
            var group = AddGroup(parent, "turret " + pos);

            CreateSprite("turret range hint " + pos, circle, pos, new Vector2(3.8f, 3.8f), ColorFromHex("#e0b341", 0.075f), 21, group);
            CreateSprite("turret foot glow " + pos, glow, pos, new Vector2(1.65f, 1.65f), ColorFromHex("#ff8c3a", 0.18f), 22, group);
            CreateSprite("turret base " + pos, circle, pos, new Vector2(0.86f, 0.86f), ColorFromHex("#242b3a"), 36, group);
            CreateSprite("turret ring " + pos, circle, pos, new Vector2(0.62f, 0.62f), ColorFromHex("#e0b341"), 37, group);
            CreateSprite("turret barrel " + pos, square, pos + AngleOffset(barrelAngle, 0.42f), new Vector2(0.18f, 0.76f), ColorFromHex("#dce6ef"), 38, group, barrelAngle - 90f);
            CreateSprite("turret optic " + pos, circle, pos + AngleOffset(barrelAngle, 0.18f), new Vector2(0.15f, 0.15f), ColorFromHex("#3fd2ff"), 39, group);
        }

        static void DrawEnemyPressure(Transform parent, Transform lights)
        {
            DrawEnemyGroup(parent, new Vector3(-13.2f, 5.8f, 0f), 5, 0.55f);
            DrawEnemyGroup(parent, new Vector3(13.1f, -5.5f, 0f), 6, 0.62f);
            DrawEnemyGroup(parent, new Vector3(0.4f, -7.2f, 0f), 4, 0.5f);
            AddLight(lights, "enemy red edge warning west", new Vector3(-13.1f, 5.7f, -1f), ColorFromHex("#ff3b30"), 0.55f, 2.6f, 0.2f);
            AddLight(lights, "enemy red edge warning east", new Vector3(13.0f, -5.5f, -1f), ColorFromHex("#ff3b30"), 0.55f, 2.7f, 0.2f);
        }

        static void DrawEnemyGroup(Transform parent, Vector3 origin, int count, float spread)
        {
            var circle = Sprite("circle");
            var square = Sprite("square");
            var glow = Sprite("soft_glow");

            CreateSprite("enemy approach fog " + origin, glow, origin, new Vector2(3.2f, 2.0f), ColorFromHex("#7fbf5f", 0.13f), 28, parent);
            for (var i = 0; i < count; i++)
            {
                var p = origin + new Vector3((Hash01(i, 2) - 0.5f) * spread * 2.2f, (Hash01(i, 7) - 0.5f) * spread * 1.4f, 0f);
                var size = 0.35f + Hash01(i, count) * 0.23f;
                CreateSprite("enemy body " + origin + " " + i, circle, p, new Vector2(size, size * 1.25f), ColorFromHex("#335b32"), 42, parent);
                CreateSprite("enemy eye left " + origin + " " + i, square, p + new Vector3(-0.08f, 0.08f, 0f), new Vector2(0.055f, 0.035f), ColorFromHex("#ff3b30"), 43, parent);
                CreateSprite("enemy eye right " + origin + " " + i, square, p + new Vector3(0.08f, 0.08f, 0f), new Vector2(0.055f, 0.035f), ColorFromHex("#ff3b30"), 43, parent);
            }
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

        static void AddGlobalLight(Transform parent)
        {
            AddLight(parent, "Global moonlit factory ambience", Vector3.zero, ColorFromHex("#8fb7ff"), 0.22f, 0f, 0f, true);
        }

        static void AddLight(Transform parent, string name, Vector3 position, Color color, float intensity, float outerRadius, float innerRadius, bool global = false)
        {
            var lightType = Type.GetType("UnityEngine.Rendering.Universal.Light2D, Unity.RenderPipelines.Universal.2D.Runtime");
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

        static Transform AddGroup(Transform parent, string name)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            return go.transform;
        }

        static GameObject CreateSprite(string name, Sprite sprite, Vector3 position, Vector2 scale, Color color, int order, Transform parent, float rotationZ = 0f)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            go.transform.position = position;
            go.transform.rotation = Quaternion.Euler(0f, 0f, rotationZ);
            go.transform.localScale = new Vector3(scale.x, scale.y, 1f);
            var renderer = go.AddComponent<SpriteRenderer>();
            renderer.sprite = sprite;
            renderer.color = color;
            renderer.sortingOrder = order;
            renderer.sharedMaterial = color.a < 1f ? spriteUnlit : spriteLit;
            return go;
        }

        static Vector3 TileCenter(int x, int y)
        {
            return new Vector3(Left + x + 0.5f, Bottom + y + 0.5f, 0f);
        }

        static Vector3 AngleOffset(float degrees, float distance)
        {
            var rad = degrees * Mathf.Deg2Rad;
            return new Vector3(Mathf.Cos(rad) * distance, Mathf.Sin(rad) * distance, 0f);
        }

        static Sprite Sprite(string name)
        {
            return AssetDatabase.LoadAssetAtPath<Sprite>(ArtDir + "/" + name + ".png");
        }

        static void CreateMaterials()
        {
            var litShader = Shader.Find("Universal Render Pipeline/2D/Sprite-Lit-Default") ?? Shader.Find("Sprites/Default");
            var unlitShader = Shader.Find("Universal Render Pipeline/2D/Sprite-Unlit-Default") ?? Shader.Find("Sprites/Default");

            spriteLit = AssetDatabase.LoadAssetAtPath<Material>(LitMaterialPath);
            if (spriteLit == null)
            {
                spriteLit = new Material(litShader);
                AssetDatabase.CreateAsset(spriteLit, LitMaterialPath);
            }
            spriteLit.shader = litShader;

            spriteUnlit = AssetDatabase.LoadAssetAtPath<Material>(UnlitMaterialPath);
            if (spriteUnlit == null)
            {
                spriteUnlit = new Material(unlitShader);
                AssetDatabase.CreateAsset(spriteUnlit, UnlitMaterialPath);
            }
            spriteUnlit.shader = unlitShader;
        }

        static void CreateGeneratedSprites()
        {
            CreateSpriteTexture("square", 16, 16, (x, y) => Color.white, true);
            CreateSpriteTexture("circle", 64, 64, (x, y) =>
            {
                var dx = (x + 0.5f) / 64f - 0.5f;
                var dy = (y + 0.5f) / 64f - 0.5f;
                return dx * dx + dy * dy <= 0.245f ? Color.white : Color.clear;
            }, false);
            CreateSpriteTexture("diamond", 64, 64, (x, y) =>
            {
                var dx = Mathf.Abs((x + 0.5f) / 64f - 0.5f);
                var dy = Mathf.Abs((y + 0.5f) / 64f - 0.5f);
                return dx + dy <= 0.5f ? Color.white : Color.clear;
            }, false);
            CreateSpriteTexture("soft_glow", 128, 128, (x, y) =>
            {
                var dx = (x + 0.5f) / 128f - 0.5f;
                var dy = (y + 0.5f) / 128f - 0.5f;
                var d = Mathf.Sqrt(dx * dx + dy * dy) / 0.5f;
                var a = Mathf.Clamp01(1f - d);
                a = a * a * 0.75f;
                return new Color(1f, 1f, 1f, a);
            }, false);
            CreateSpriteTexture("hazard", 64, 16, (x, y) =>
            {
                var stripe = ((x + y * 2) / 8) % 2 == 0;
                return stripe ? ColorFromHex("#ffb800") : ColorFromHex("#161616");
            }, true);
        }

        static void CreateSpriteTexture(string name, int width, int height, Func<int, int, Color> colorAt, bool pointFilter)
        {
            var assetPath = ArtDir + "/" + name + ".png";
            var fullPath = FullPath(assetPath);
            Directory.CreateDirectory(Path.GetDirectoryName(fullPath));

            var texture = new Texture2D(width, height, TextureFormat.RGBA32, false);
            var pixels = new Color[width * height];
            for (var y = 0; y < height; y++)
            {
                for (var x = 0; x < width; x++)
                {
                    pixels[y * width + x] = colorAt(x, y);
                }
            }
            texture.SetPixels(pixels);
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
            importer.filterMode = pointFilter ? FilterMode.Point : FilterMode.Bilinear;
            importer.wrapMode = TextureWrapMode.Clamp;
            importer.SaveAndReimport();
        }

        static void ExportPreview(Camera camera, string assetPath)
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(FullPath(assetPath)));
                var rt = new RenderTexture(1600, 900, 24, RenderTextureFormat.ARGB32);
                var previousActive = RenderTexture.active;
                var previousTarget = camera.targetTexture;
                camera.targetTexture = rt;
                RenderTexture.active = rt;
                camera.Render();

                var image = new Texture2D(rt.width, rt.height, TextureFormat.RGBA32, false);
                image.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
                image.Apply();
                File.WriteAllBytes(FullPath(assetPath), image.EncodeToPNG());

                camera.targetTexture = previousTarget;
                RenderTexture.active = previousActive;
                UnityEngine.Object.DestroyImmediate(image);
                UnityEngine.Object.DestroyImmediate(rt);
                AssetDatabase.ImportAsset(assetPath, ImportAssetOptions.ForceUpdate);
            }
            catch (Exception e)
            {
                Debug.LogWarning("Preview export skipped: " + e.Message);
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

        static void EnsureProjectFolders()
        {
            EnsureFolder("Assets", "_Project");
            EnsureFolder(Root, "Scenes");
            EnsureFolder(Root, "Art");
            EnsureFolder(Root + "/Art", "Generated");
            EnsureFolder(Root, "ArtDirection");
            EnsureFolder(Root, "Materials");
            EnsureFolder(Root, "Editor");
        }

        static void EnsureFolder(string parent, string name)
        {
            var path = parent + "/" + name;
            if (!AssetDatabase.IsValidFolder(path))
            {
                AssetDatabase.CreateFolder(parent, name);
            }
        }

        static string FullPath(string assetPath)
        {
            var projectRoot = Directory.GetParent(Application.dataPath).FullName;
            return Path.Combine(projectRoot, assetPath.Replace('/', Path.DirectorySeparatorChar));
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
            if (value is string text && type.IsEnum)
            {
                return Enum.Parse(type, text);
            }

            if (type == typeof(float) && value is double d) return (float)d;
            return value;
        }
    }
}
#endif
