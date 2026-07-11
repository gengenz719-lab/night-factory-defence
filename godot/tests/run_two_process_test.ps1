param(
    [int]$Port = 29240,
    [int]$TimeoutSeconds = 20
)

$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
$godotPath = (Resolve-Path (Join-Path $projectPath '..\.tools\godot-4.7\Godot_v4.7-stable_win64_console.exe')).Path
$reportRoot = Join-Path $env:TEMP ('nfd-wp2-3-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $reportRoot | Out-Null

function Wait-ForPair {
    param($HostProcess, $ClientProcess, [int]$Seconds)
    $deadline = [DateTime]::Now.AddSeconds($Seconds)
    while ((-not $HostProcess.HasExited -or -not $ClientProcess.HasExited) -and [DateTime]::Now -lt $deadline) {
        Start-Sleep -Milliseconds 200
    }
    if (-not $HostProcess.HasExited) { Stop-Process -Id $HostProcess.Id -Force }
    if (-not $ClientProcess.HasExited) { Stop-Process -Id $ClientProcess.Id -Force }
    $HostProcess.WaitForExit()
    $ClientProcess.WaitForExit()
}

function Start-GamePair {
    param([string]$Name, [int]$PairPort, [string]$ClientVersion = '')
    $pairPath = Join-Path $reportRoot $Name
    New-Item -ItemType Directory -Path $pairPath | Out-Null
    $hostOut = Join-Path $pairPath 'host.log'
    $hostErr = Join-Path $pairPath 'host.err.log'
    $clientOut = Join-Path $pairPath 'client.log'
    $clientErr = Join-Path $pairPath 'client.err.log'
    $hostProcess = Start-Process -FilePath $godotPath `
        -ArgumentList "--headless --path `"$projectPath`" -- --network-test-host --port=$PairPort" `
        -RedirectStandardOutput $hostOut -RedirectStandardError $hostErr -WindowStyle Hidden -PassThru
    Start-Sleep -Milliseconds 700
    $versionArgument = if ($ClientVersion) { " --version=$ClientVersion" } else { '' }
    $clientProcess = Start-Process -FilePath $godotPath `
        -ArgumentList "--headless --path `"$projectPath`" -- --network-test-client --address=127.0.0.1 --port=$PairPort$versionArgument" `
        -RedirectStandardOutput $clientOut -RedirectStandardError $clientErr -WindowStyle Hidden -PassThru
    return @{
        Host = $hostProcess; Client = $clientProcess
        HostOut = $hostOut; HostErr = $hostErr; ClientOut = $clientOut; ClientErr = $clientErr
    }
}

$syncPair = Start-GamePair -Name 'sync' -PairPort $Port
Wait-ForPair -HostProcess $syncPair.Host -ClientProcess $syncPair.Client -Seconds $TimeoutSeconds
$hostText = Get-Content -Raw -Encoding utf8 $syncPair.HostOut
$clientText = Get-Content -Raw -Encoding utf8 $syncPair.ClientOut
$syncErrors = (Get-Item $syncPair.HostErr).Length + (Get-Item $syncPair.ClientErr).Length
if (-not $hostText.Contains('NETWORK_TEST_PASS') -or -not $clientText.Contains('NETWORK_CLIENT_PASS') -or $syncErrors -ne 0) {
    Write-Host $hostText
    Write-Host $clientText
    throw "Two-process synchronization test failed. Logs: $reportRoot"
}

$versionPair = Start-GamePair -Name 'version' -PairPort ($Port + 1) -ClientVersion '9.9.9'
$versionDeadline = [DateTime]::Now.AddSeconds(8)
while (-not $versionPair.Client.HasExited -and [DateTime]::Now -lt $versionDeadline) { Start-Sleep -Milliseconds 200 }
if (-not $versionPair.Client.HasExited) { Stop-Process -Id $versionPair.Client.Id -Force }
if (-not $versionPair.Host.HasExited) { Stop-Process -Id $versionPair.Host.Id -Force }
$versionPair.Client.WaitForExit()
$versionPair.Host.WaitForExit()
$versionText = Get-Content -Raw -Encoding utf8 $versionPair.ClientOut
if (-not $versionText.Contains('VERSION_TEST_PASS') -or (Get-Item $versionPair.ClientErr).Length -ne 0) {
    Write-Host $versionText
    throw "Version rejection test failed. Logs: $reportRoot"
}

Write-Host "WP2_3_TWO_PROCESS_PASS"
Write-Host "Logs: $reportRoot"
Write-Host ($hostText -split "`r?`n" | Where-Object { $_ -like 'NETWORK_TEST_PASS*' })
Write-Host ($versionText -split "`r?`n" | Where-Object { $_ -like 'VERSION_TEST_PASS*' })
