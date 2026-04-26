param(
    [int]$Port = 8765,
    [int]$IntervalMs = 1000
)

$ErrorActionPreference = 'Stop'
$base = $PSScriptRoot
$statusPath = Join-Path $base 'status.json'
$collectorScript = Join-Path $base 'collect.ps1'

$collector = Start-Process -FilePath powershell -ArgumentList @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', $collectorScript,
    '-OutputPath', $statusPath,
    '-IntervalMs', $IntervalMs
) -WorkingDirectory $base -WindowStyle Hidden -PassThru

$server = Start-Process -FilePath python -ArgumentList @(
    '-m', 'http.server', $Port
) -WorkingDirectory $base -WindowStyle Hidden -PassThru

$url = "http://127.0.0.1:$Port/dashboard.html"
Start-Process $url | Out-Null

Write-Host ''
Write-Host "Search Diagnostics 已启动"
Write-Host "Dashboard: $url"
Write-Host "Collector PID: $($collector.Id)"
Write-Host "Server PID: $($server.Id)"
Write-Host ''
Write-Host '停止命令：'
Write-Host "Stop-Process -Id $($collector.Id),$($server.Id)"
