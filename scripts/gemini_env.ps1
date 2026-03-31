# 供 cli_queue_worker.ps1 与 gemini_native_terminal.ps1 共用：加载 GEMINI/GOOGLE API Key（.env、注册表、cache 等）

function Import-GeminiEnvironmentLikeInteractiveTerminal {
    $profileCandidates = @(
        $PROFILE
        (Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1")
        (Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\profile.ps1")
        (Join-Path $env:USERPROFILE "Documents\PowerShell\Microsoft.PowerShell_profile.ps1")
        (Join-Path $env:USERPROFILE "Documents\PowerShell\profile.ps1")
    )
    foreach ($p in $profileCandidates) {
        if ($p -and (Test-Path -LiteralPath $p)) {
            try {
                . $p
            } catch {
            }
        }
    }
    if (-not $env:GEMINI_API_KEY -or -not $env:GEMINI_API_KEY.Trim()) {
        $v = [System.Environment]::GetEnvironmentVariable('GEMINI_API_KEY', 'User')
        if (-not $v) {
            $v = [System.Environment]::GetEnvironmentVariable('GEMINI_API_KEY', 'Machine')
        }
        if ($v) {
            $env:GEMINI_API_KEY = $v
        }
    }
    if (-not $env:GOOGLE_API_KEY -or -not $env:GOOGLE_API_KEY.Trim()) {
        $v = [System.Environment]::GetEnvironmentVariable('GOOGLE_API_KEY', 'User')
        if (-not $v) {
            $v = [System.Environment]::GetEnvironmentVariable('GOOGLE_API_KEY', 'Machine')
        }
        if ($v) {
            $env:GOOGLE_API_KEY = $v
        }
    }
}

function Unquote-DotEnvValue {
    param([string]$Value)
    $v = $Value.Trim()
    if ($v.Length -ge 2 -and $v.StartsWith('"') -and $v.EndsWith('"')) {
        return $v.Substring(1, $v.Length - 2)
    }
    if ($v.Length -ge 2 -and $v.StartsWith("'") -and $v.EndsWith("'")) {
        return $v.Substring(1, $v.Length - 2)
    }
    return $v
}

function Merge-DotEnvLineIntoProcess {
    param([string]$RawLine)
    $line = $RawLine.Trim()
    if ($line.Length -eq 0) {
        return
    }
    $line = $line.TrimStart([char]0xFEFF)
    if ($line.StartsWith('#')) {
        return
    }
    if ($line -match '^(?i)export\s+') {
        $line = $line -replace '^(?i)export\s+', ''
    } elseif ($line -match '^(?i)set\s+') {
        $line = $line -replace '^(?i)set\s+', ''
    }
    $eq = $line.IndexOf('=')
    if ($eq -lt 1) {
        return
    }
    $k = $line.Substring(0, $eq).Trim()
    $v = Unquote-DotEnvValue -Value $line.Substring($eq + 1)
    if ($k -eq 'GEMINI_API_KEY' -and -not [string]::IsNullOrWhiteSpace($v)) {
        $env:GEMINI_API_KEY = $v
    }
    if ($k -eq 'GOOGLE_API_KEY' -and -not [string]::IsNullOrWhiteSpace($v)) {
        $env:GOOGLE_API_KEY = $v
    }
}

function Merge-DotEnvFileIntoProcess {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    Get-Content -LiteralPath $Path -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object {
        Merge-DotEnvLineIntoProcess -RawLine $_
    }
}

function Sync-GeminiApiKeyFromGoogleIfNeeded {
    if ($env:GEMINI_API_KEY -and $env:GEMINI_API_KEY.Trim()) {
        return
    }
    if ($env:GOOGLE_API_KEY -and $env:GOOGLE_API_KEY.Trim()) {
        $env:GEMINI_API_KEY = $env:GOOGLE_API_KEY.Trim()
    }
}

function Apply-GeminiCliEnvironment {
    param([string]$Root)
    $userDotEnv = Join-Path $env:USERPROFILE ".env"
    Merge-DotEnvFileIntoProcess -Path $userDotEnv
    $dotEnv = Join-Path $Root ".env"
    Merge-DotEnvFileIntoProcess -Path $dotEnv
    if (-not $env:GEMINI_API_KEY -or -not $env:GEMINI_API_KEY.Trim()) {
        $keyFile = Join-Path $Root "cache\gemini_api_key.txt"
        if (Test-Path -LiteralPath $keyFile) {
            $k = (Get-Content -LiteralPath $keyFile -Raw -Encoding UTF8).Trim()
            if (-not [string]::IsNullOrWhiteSpace($k)) {
                $env:GEMINI_API_KEY = $k
            }
        }
    }
    Sync-GeminiApiKeyFromGoogleIfNeeded
}
