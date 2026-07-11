param(
    [ValidateRange(1, 3600)]
    [int]$DurationSeconds = 600,
    [ValidateRange(1024, 65535)]
    [int]$Port = 29117,
    [string]$OutputDirectory = "",
    [switch]$NoImpairment
)

$ErrorActionPreference = "Stop"
$projectDirectory = $PSScriptRoot
$repositoryRoot = (Resolve-Path (Join-Path $projectDirectory "..\..")).Path
$godotPath = Join-Path $repositoryRoot ".tools\godot-4.7\Godot_v4.7-stable_win64_console.exe"

if (-not (Test-Path -LiteralPath $godotPath)) {
    throw "Godot 4.7 was not found: $godotPath"
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputDirectory = Join-Path $env:TEMP "spike-b-enet-$timestamp"
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$hostLog = Join-Path $OutputDirectory "host.log"
$hostErrorLog = Join-Path $OutputDirectory "host.err.log"
$clientLog = Join-Path $OutputDirectory "client.log"
$clientErrorLog = Join-Path $OutputDirectory "client.err.log"
$reportPath = Join-Path $OutputDirectory "report.json"

$commonArguments = @("--headless", "--path", $projectDirectory, "--")
$impairmentArgument = if ($NoImpairment) { @("--no-impairment") } else { @() }
$hostArguments = $commonArguments + @("--host", "--duration=$DurationSeconds", "--port=$Port", "--report=$reportPath") + $impairmentArgument
$clientArguments = $commonArguments + @("--client", "--duration=$DurationSeconds", "--port=$Port") + $impairmentArgument

$hostProcess = Start-Process -FilePath $godotPath -ArgumentList $hostArguments `
    -RedirectStandardOutput $hostLog -RedirectStandardError $hostErrorLog `
    -WindowStyle Hidden -PassThru

Start-Sleep -Milliseconds 500

$clientProcess = Start-Process -FilePath $godotPath -ArgumentList $clientArguments `
    -RedirectStandardOutput $clientLog -RedirectStandardError $clientErrorLog `
    -WindowStyle Hidden -PassThru

$timeoutSeconds = $DurationSeconds + 15
$hostProcess, $clientProcess | Wait-Process -Timeout $timeoutSeconds
$hostProcess.Refresh()
$clientProcess.Refresh()

Write-Output "Output: $OutputDirectory"
Write-Output "===== HOST ====="
Get-Content -Encoding utf8 $hostLog
if ((Get-Item $hostErrorLog).Length -gt 0) { Get-Content -Encoding utf8 $hostErrorLog }
Write-Output "===== CLIENT ====="
Get-Content -Encoding utf8 $clientLog
if ((Get-Item $clientErrorLog).Length -gt 0) { Get-Content -Encoding utf8 $clientErrorLog }
Write-Output "===== REPORT ====="
if (Test-Path -LiteralPath $reportPath) { Get-Content -Encoding utf8 $reportPath }

if ($hostProcess.ExitCode -ne 0 -or $clientProcess.ExitCode -ne 0) {
    throw "A validation process failed: host=$($hostProcess.ExitCode) client=$($clientProcess.ExitCode)"
}

$report = Get-Content -Raw -Encoding utf8 $reportPath | ConvertFrom-Json
if (-not $report.success) {
    throw "Spike B acceptance validation failed"
}
