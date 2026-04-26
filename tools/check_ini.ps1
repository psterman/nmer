param([string]$Name = 'CursorShortcut.ini')
$path = Join-Path (Split-Path -Parent $PSScriptRoot) $Name
Write-Host ('Path: ' + $path)
if (-not (Test-Path $path)) { Write-Host 'Not found'; exit }
$b = [IO.File]::ReadAllBytes($path)
Write-Host ('Size: ' + $b.Length)
$show = [Math]::Min(32, $b.Length)
Write-Host ('First bytes: ' + (($b[0..($show-1)] | ForEach-Object { '{0:X2}' -f $_ }) -join ' '))
# count leading FFFE pairs
$bomCount = 0
$i = 0
while ($i + 1 -lt $b.Length -and $b[$i] -eq 0xFF -and $b[$i+1] -eq 0xFE) { $bomCount++; $i += 2 }
Write-Host ('Leading FF FE pair count: ' + $bomCount)
