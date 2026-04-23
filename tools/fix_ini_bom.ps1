param([string]$Name = 'CursorShortcut.ini')
$path = Join-Path (Split-Path -Parent $PSScriptRoot) $Name
if (-not (Test-Path $path)) { Write-Host ('Not found: ' + $path); exit 1 }

$b = [IO.File]::ReadAllBytes($path)
Write-Host ('Before size: ' + $b.Length)

# Detect UTF-16 LE by leading FF FE
if ($b.Length -lt 2 -or $b[0] -ne 0xFF -or $b[1] -ne 0xFE) {
    Write-Host 'Not UTF-16 LE with BOM; aborting for safety.'
    exit 1
}

# Count leading FF FE pairs
$i = 0
while ($i + 1 -lt $b.Length -and $b[$i] -eq 0xFF -and $b[$i+1] -eq 0xFE) { $i += 2 }
$bomCount = $i / 2
Write-Host ('Leading BOM pair count: ' + $bomCount)
if ($bomCount -le 1) { Write-Host 'Already clean. No change.'; exit 0 }

# Backup
$backup = $path + '.bak_fixbom_' + (Get-Date -Format 'yyyyMMddHHmmss')
Copy-Item $path $backup -Force
Write-Host ('Backup: ' + $backup)

# Write back: keep only single leading BOM, preserve the rest
$fs = [IO.File]::Open($path, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)
try {
    $fs.WriteByte(0xFF); $fs.WriteByte(0xFE)
    # $i points to first byte after leading BOMs
    $fs.Write($b, $i, $b.Length - $i)
} finally {
    $fs.Dispose()
}
$b2 = [IO.File]::ReadAllBytes($path)
Write-Host ('After size: ' + $b2.Length)
Write-Host ('After first bytes: ' + (($b2[0..23] | ForEach-Object { '{0:X2}' -f $_ }) -join ' '))
