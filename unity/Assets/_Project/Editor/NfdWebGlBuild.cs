#if UNITY_EDITOR
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;

namespace NightFactoryDefence.Editor
{
    public static class NfdWebGlBuild
    {
        const string ScenePath = "Assets/_Project/Scenes/PlayableSlice.unity";
        const string OutputPath = "../play";

        [MenuItem("Night Factory Defence/Build WebGL Playtest")]
        public static void BuildWebGlPlaytest()
        {
            var absoluteOutput = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), OutputPath));
            if (Directory.Exists(absoluteOutput)) Directory.Delete(absoluteOutput, true);
            Directory.CreateDirectory(absoluteOutput);

            var previousTarget = EditorUserBuildSettings.activeBuildTarget;
            var previousGroup = EditorUserBuildSettings.selectedBuildTargetGroup;

            EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.WebGL, BuildTarget.WebGL);
            PlayerSettings.productName = "Night Factory Defence";
            PlayerSettings.companyName = "Kagyo games";
            PlayerSettings.WebGL.compressionFormat = WebGLCompressionFormat.Disabled;
            PlayerSettings.WebGL.decompressionFallback = false;

            var options = new BuildPlayerOptions
            {
                scenes = new[] { ScenePath },
                locationPathName = absoluteOutput,
                target = BuildTarget.WebGL,
                options = BuildOptions.None
            };

            var report = BuildPipeline.BuildPlayer(options);
            if (report.summary.result != BuildResult.Succeeded)
            {
                throw new BuildFailedException("WebGL playtest build failed: " + report.summary.result);
            }

            WritePagesStyle(Path.Combine(absoluteOutput, "TemplateData", "style.css"));
            PostProcessIndex(Path.Combine(absoluteOutput, "index.html"));

            if (previousTarget != BuildTarget.WebGL)
            {
                EditorUserBuildSettings.SwitchActiveBuildTarget(previousGroup, previousTarget);
            }

            AssetDatabase.Refresh();
            UnityEngine.Debug.Log("Built WebGL playtest to " + absoluteOutput);
        }

        static void WritePagesStyle(string path)
        {
            File.WriteAllText(path,
@"html, body {
  width: 100%;
  height: 100%;
  padding: 0;
  margin: 0;
  overflow: hidden;
  background: #080b0f;
}

#unity-container,
#unity-container.unity-desktop,
#unity-container.unity-mobile {
  position: fixed;
  inset: 0;
  width: 100%;
  height: 100%;
  transform: none;
}

#unity-canvas {
  width: 100vw !important;
  height: 100vh !important;
  display: block;
  background: #080b0f;
}

#unity-loading-bar {
  position: absolute;
  left: 50%;
  top: 50%;
  transform: translate(-50%, -50%);
  display: none;
}

#unity-logo {
  width: 154px;
  height: 130px;
  background: url('unity-logo-dark.png') no-repeat center;
}

#unity-progress-bar-empty {
  width: 141px;
  height: 18px;
  margin-top: 10px;
  margin-left: 6.5px;
  background: url('progress-bar-empty-dark.png') no-repeat center;
}

#unity-progress-bar-full {
  width: 0%;
  height: 18px;
  margin-top: 10px;
  background: url('progress-bar-full-dark.png') no-repeat center;
}

#unity-footer {
  display: none;
}

#unity-warning {
  position: absolute;
  left: 50%;
  top: 5%;
  transform: translate(-50%);
  background: #fff;
  color: #111;
  padding: 10px;
  display: none;
}");
        }

        static void PostProcessIndex(string path)
        {
            var html = File.ReadAllText(path);
            html = html.Replace(
                "<title>Unity Web Player | Night Factory Defence</title>",
                "<title>Night Factory Defence - Unity Playtest</title>");
            html = html.Replace(
                "}).then((unityInstance) => {",
                "}).then((unityInstance) => {\n                window.unityInstance = unityInstance;");
            File.WriteAllText(path, html);
        }
    }
}
#endif
