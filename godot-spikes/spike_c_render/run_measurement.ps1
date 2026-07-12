param(
    [switch]$Quick
)

$ErrorActionPreference = 'Stop'
$projectPath = $PSScriptRoot
$repoRoot = Split-Path (Split-Path $projectPath -Parent) -Parent
$godotPath = Join-Path $repoRoot '.tools\godot-4.7\Godot_v4.7-stable_win64_console.exe'
$outputPath = Join-Path $projectPath 'results\render_load_results.json'

if (-not (Test-Path $godotPath)) {
    throw "Godot 4.7 console executable not found: $godotPath"
}

$userArguments = @("--output=$outputPath")
if ($Quick) { $userArguments += '--quick' }

& $godotPath --path $projectPath -- @userArguments
if ($LASTEXITCODE -ne 0) {
    throw "Spike C measurement failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path $outputPath)) {
    throw "Measurement JSON was not created: $outputPath"
}

Write-Host "SPIKE_C_MEASUREMENT_PASS"
Write-Host $outputPath
