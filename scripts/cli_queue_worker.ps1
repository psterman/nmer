param(
    [Parameter(Mandatory = $true)][string]$Engine,
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][string]$Workdir,
    [Parameter(Mandatory = $true)][string]$QueueDir,
    [Parameter(Mandatory = $true)][string]$Executable
)

$ErrorActionPreference = "Continue"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $Utf8NoBom
[Console]::OutputEncoding = $Utf8NoBom
$OutputEncoding = $Utf8NoBom
$Host.UI.RawUI.WindowTitle = $Title
Set-Location -LiteralPath $Workdir
New-Item -ItemType Directory -Force -Path $QueueDir | Out-Null

$OpenClawStateDir = Join-Path $Workdir "cache\openclaw-state"
$OpenClawConfigPath = Join-Path $OpenClawStateDir "config.json"
$OpenClawAgentDir = Join-Path $OpenClawStateDir "agents\main\agent"
$DefaultOpenClawConfig = Join-Path $env:USERPROFILE ".openclaw\openclaw.json"
$DefaultOpenClawAuth = Join-Path $env:USERPROFILE ".openclaw\agents\main\agent\auth-profiles.json"
$DefaultOpenClawModels = Join-Path $env:USERPROFILE ".openclaw\agents\main\agent\models.json"
$OpenClawAuthPath = Join-Path $OpenClawAgentDir "auth-profiles.json"
$OpenClawModelsPath = Join-Path $OpenClawAgentDir "models.json"
New-Item -ItemType Directory -Force -Path $OpenClawStateDir | Out-Null
New-Item -ItemType Directory -Force -Path $OpenClawAgentDir | Out-Null

if (Test-Path -LiteralPath $DefaultOpenClawConfig) {
    Copy-Item -LiteralPath $DefaultOpenClawConfig -Destination $OpenClawConfigPath -Force
}
if (Test-Path -LiteralPath $DefaultOpenClawAuth) {
    Copy-Item -LiteralPath $DefaultOpenClawAuth -Destination $OpenClawAuthPath -Force
}
if (Test-Path -LiteralPath $DefaultOpenClawModels) {
    Copy-Item -LiteralPath $DefaultOpenClawModels -Destination $OpenClawModelsPath -Force
}

Write-Host ""
Write-Host "[$Engine] worker ready" -ForegroundColor Cyan
Write-Host "queue: $QueueDir" -ForegroundColor DarkGray
Write-Host ""

function Add-OpenClawPayloadTexts {
    param(
        [Parameter(Mandatory = $true)]$Node,
        [Parameter(Mandatory = $true)][ref]$Texts
    )

    if ($null -eq $Node) {
        return
    }

    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
        foreach ($Item in $Node) {
            Add-OpenClawPayloadTexts -Node $Item -Texts $Texts
        }
        return
    }

    if ($Node.PSObject -and $Node.PSObject.Properties["payloads"]) {
        foreach ($Payload in $Node.payloads) {
            if ($Payload -and $Payload.PSObject -and $Payload.PSObject.Properties["text"] -and -not [string]::IsNullOrWhiteSpace([string]$Payload.text)) {
                $Texts.Value += [string]$Payload.text
            }
        }
    }
}

function Get-OpenClawSessionSnapshot {
    param(
        [Parameter(Mandatory = $true)][string]$SessionsDir
    )

    $sessionFile = Get-ChildItem -LiteralPath $SessionsDir -Filter *.jsonl -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $sessionFile) {
        return @{
            Path = ""
            LineCount = 0
        }
    }

    $lineCount = (Get-Content -LiteralPath $sessionFile.FullName -Encoding UTF8 -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
    return @{
        Path = $sessionFile.FullName
        LineCount = $lineCount
    }
}

function Get-OpenClawAssistantTextsFromLines {
    param(
        [Parameter(Mandatory = $true)][string[]]$Lines
    )

    $results = @()
    foreach ($line in $Lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        try {
            $entry = $line | ConvertFrom-Json -Depth 100
        } catch {
            continue
        }

        if ($entry.type -ne "message" -or -not $entry.message -or $entry.message.role -ne "assistant") {
            continue
        }

        foreach ($part in $entry.message.content) {
            if ($part.type -eq "text" -and -not [string]::IsNullOrWhiteSpace([string]$part.text)) {
                $results += [string]$part.text
            }
        }
    }

    return $results
}

function Get-OpenClawAssistantErrorFromLines {
    param(
        [Parameter(Mandatory = $true)][string[]]$Lines
    )

    $lastError = ""
    foreach ($line in $Lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        try {
            $entry = $line | ConvertFrom-Json -Depth 100
        } catch {
            continue
        }

        if ($entry.type -ne "message" -or -not $entry.message -or $entry.message.role -ne "assistant") {
            continue
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$entry.message.errorMessage)) {
            $lastError = [string]$entry.message.errorMessage
        }
    }

    return $lastError
}

function Wait-ForOpenClawAssistantTexts {
    param(
        [Parameter(Mandatory = $true)][string]$SessionsDir,
        [Parameter(Mandatory = $true)]$Snapshot,
        [int]$TimeoutSeconds = 15
    )

    $deadline = (Get-Date).ToUniversalTime().AddSeconds($TimeoutSeconds)
    do {
        $sessionFile = Get-ChildItem -LiteralPath $SessionsDir -Filter *.jsonl -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        $texts = @()
        if ($sessionFile) {
            $allLines = Get-Content -LiteralPath $sessionFile.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
            $startIndex = 0

            if ($Snapshot.Path -eq $sessionFile.FullName) {
                $startIndex = [Math]::Min([int]$Snapshot.LineCount, $allLines.Count)
            }

            $newLines = @()
            if ($allLines.Count -gt $startIndex) {
                $newLines = $allLines[$startIndex..($allLines.Count - 1)]
            }

            $texts = Get-OpenClawAssistantTextsFromLines -Lines $newLines
        }

        if ($texts.Count -gt 0) {
            return $texts
        }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date).ToUniversalTime() -lt $deadline)

    return @()
}

function Wait-ForOpenClawAssistantError {
    param(
        [Parameter(Mandatory = $true)][string]$SessionsDir,
        [Parameter(Mandatory = $true)]$Snapshot,
        [int]$TimeoutSeconds = 2
    )

    $deadline = (Get-Date).ToUniversalTime().AddSeconds($TimeoutSeconds)
    do {
        $sessionFile = Get-ChildItem -LiteralPath $SessionsDir -Filter *.jsonl -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($sessionFile) {
            $allLines = Get-Content -LiteralPath $sessionFile.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
            $startIndex = 0

            if ($Snapshot.Path -eq $sessionFile.FullName) {
                $startIndex = [Math]::Min([int]$Snapshot.LineCount, $allLines.Count)
            }

            $newLines = @()
            if ($allLines.Count -gt $startIndex) {
                $newLines = $allLines[$startIndex..($allLines.Count - 1)]
            }

            $errorMessage = Get-OpenClawAssistantErrorFromLines -Lines $newLines
            if (-not [string]::IsNullOrWhiteSpace($errorMessage)) {
                return $errorMessage
            }
        }

        Start-Sleep -Milliseconds 300
    } while ((Get-Date).ToUniversalTime() -lt $deadline)

    return ""
}

function Get-OpenClawReplyForPrompt {
    param(
        [Parameter(Mandatory = $true)][string]$SessionsDir,
        [Parameter(Mandatory = $true)][string]$Prompt
    )

    $sessionFile = Get-ChildItem -LiteralPath $SessionsDir -Filter *.jsonl -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $sessionFile) {
        return $null
    }

    $entries = @()
    foreach ($line in (Get-Content -LiteralPath $sessionFile.FullName -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        try {
            $entries += ($line | ConvertFrom-Json -Depth 100)
        } catch {
        }
    }

    for ($i = $entries.Count - 1; $i -ge 0; $i--) {
        $entry = $entries[$i]
        if ($entry.type -ne "message" -or -not $entry.message -or $entry.message.role -ne "user") {
            continue
        }

        $userTexts = @()
        foreach ($part in $entry.message.content) {
            if ($part.type -eq "text" -and -not [string]::IsNullOrWhiteSpace([string]$part.text)) {
                $userTexts += [string]$part.text
            }
        }

        if (($userTexts -join "`n").Trim() -ne $Prompt.Trim()) {
            continue
        }

        for ($j = $i + 1; $j -lt $entries.Count; $j++) {
            $nextEntry = $entries[$j]
            if ($nextEntry.type -ne "message" -or -not $nextEntry.message -or $nextEntry.message.role -ne "assistant") {
                continue
            }

            $texts = @()
            foreach ($part in $nextEntry.message.content) {
                if ($part.type -eq "text" -and -not [string]::IsNullOrWhiteSpace([string]$part.text)) {
                    $texts += [string]$part.text
                }
            }

            if ($texts.Count -gt 0) {
                return @{
                    Text = ($texts -join "`r`n`r`n")
                    Error = ""
                }
            }

            if (-not [string]::IsNullOrWhiteSpace([string]$nextEntry.message.errorMessage)) {
                return @{
                    Text = ""
                    Error = [string]$nextEntry.message.errorMessage
                }
            }
        }

        break
    }

    return $null
}

function Wait-ForOpenClawReplyForPrompt {
    param(
        [Parameter(Mandatory = $true)][string]$SessionsDir,
        [Parameter(Mandatory = $true)][string]$Prompt,
        [int]$TimeoutSeconds = 15
    )

    $deadline = (Get-Date).ToUniversalTime().AddSeconds($TimeoutSeconds)
    do {
        $reply = Get-OpenClawReplyForPrompt -SessionsDir $SessionsDir -Prompt $Prompt
        if ($null -ne $reply) {
            return $reply
        }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date).ToUniversalTime() -lt $deadline)

    return $null
}

function Get-OpenClawDeltaReply {
    param(
        [Parameter(Mandatory = $true)][string]$SessionsDir,
        [Parameter(Mandatory = $true)]$Snapshot
    )

    $sessionFile = Get-ChildItem -LiteralPath $SessionsDir -Filter *.jsonl -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $sessionFile) {
        return $null
    }

    $allLines = Get-Content -LiteralPath $sessionFile.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    $startIndex = 0
    if ($Snapshot.Path -eq $sessionFile.FullName) {
        $startIndex = [Math]::Min([int]$Snapshot.LineCount, $allLines.Count)
    }

    if ($allLines.Count -le $startIndex) {
        return $null
    }

    $newLines = $allLines[$startIndex..($allLines.Count - 1)]
    $lastText = ""
    $lastError = ""

    foreach ($line in $newLines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        try {
            $entry = $line | ConvertFrom-Json -Depth 100
        } catch {
            continue
        }

        if ($entry.type -ne "message" -or -not $entry.message -or $entry.message.role -ne "assistant") {
            continue
        }

        foreach ($part in $entry.message.content) {
            if ($part.type -eq "text" -and -not [string]::IsNullOrWhiteSpace([string]$part.text)) {
                $lastText = [string]$part.text
            }
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$entry.message.errorMessage)) {
            $lastError = [string]$entry.message.errorMessage
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($lastText) -or -not [string]::IsNullOrWhiteSpace($lastError)) {
        return @{
            Text = $lastText
            Error = $lastError
        }
    }

    return $null
}

function Wait-ForOpenClawReply {
    param(
        [Parameter(Mandatory = $true)][string]$SessionsDir,
        [Parameter(Mandatory = $true)]$Snapshot,
        [Parameter(Mandatory = $true)][string]$Prompt,
        [int]$TimeoutSeconds = 15
    )

    $deadline = (Get-Date).ToUniversalTime().AddSeconds($TimeoutSeconds)
    do {
        $reply = Get-OpenClawDeltaReply -SessionsDir $SessionsDir -Snapshot $Snapshot
        if ($null -ne $reply) {
            return $reply
        }

        $reply = Get-OpenClawReplyForPrompt -SessionsDir $SessionsDir -Prompt $Prompt
        if ($null -ne $reply) {
            return $reply
        }

        Start-Sleep -Milliseconds 500
    } while ((Get-Date).ToUniversalTime() -lt $deadline)

    return $null
}

function Invoke-AgentPrompt {
    param(
        [string]$CurrentEngine,
        [string]$Prompt
    )

    switch ($CurrentEngine) {
        "gemini_cli" {
            & $Executable -p $Prompt
            break
        }
        "codex_cli" {
            & $Executable exec -C $Workdir --skip-git-repo-check $Prompt
            break
        }
        "qwen_cli" {
            & $Executable -p $Prompt
            break
        }
        "openclaw_cli" {
            $env:OPENCLAW_STATE_DIR = $OpenClawStateDir
            $env:OPENCLAW_CONFIG_PATH = $OpenClawConfigPath
            $sessionsDir = Join-Path $OpenClawStateDir "agents\main\sessions"
            $snapshot = Get-OpenClawSessionSnapshot -SessionsDir $sessionsDir
            $raw = (& $Executable agent --local --agent main --message $Prompt --timeout 60 --json 2>&1 | Out-String).Trim()

            $sessionFile = Get-ChildItem -LiteralPath $sessionsDir -Filter *.jsonl -File -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1

            $sessionDelta = ""
            if ($sessionFile) {
                $allLines = Get-Content -LiteralPath $sessionFile.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
                $startIndex = 0
                if ($snapshot.Path -eq $sessionFile.FullName) {
                    $startIndex = [Math]::Min([int]$snapshot.LineCount, $allLines.Count)
                }
                if ($allLines.Count -gt $startIndex) {
                    $sessionDelta = ($allLines[$startIndex..($allLines.Count - 1)] -join "`r`n").Trim()
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($sessionDelta)) {
                $sessionDelta
            } elseif (-not [string]::IsNullOrWhiteSpace($raw)) {
                $raw
            } else {
                "[openclaw_cli] no output"
            }
            break
        }
        default {
            throw "Unsupported engine: $CurrentEngine"
        }
    }
}

while ($true) {
    $items = Get-ChildItem -LiteralPath $QueueDir -Filter *.txt -File -ErrorAction SilentlyContinue | Sort-Object Name
    foreach ($item in $items) {
        try {
            $prompt = Get-Content -LiteralPath $item.FullName -Raw -ErrorAction Stop
            Remove-Item -LiteralPath $item.FullName -Force -ErrorAction SilentlyContinue
            if ([string]::IsNullOrWhiteSpace($prompt)) {
                continue
            }

            Write-Host ""
            Write-Host ("[{0}] {1}" -f $Engine, (Get-Date -Format "HH:mm:ss")) -ForegroundColor Yellow
            $result = $null
            if ($Engine -eq "openclaw_cli") {
                $result = Invoke-AgentPrompt -CurrentEngine $Engine -Prompt $prompt.Trim()
            } else {
                Invoke-AgentPrompt -CurrentEngine $Engine -Prompt $prompt.Trim()
            }
            Write-Host ""
            Write-Host ("[{0}] done" -f $Engine) -ForegroundColor Green
            if ($Engine -eq "openclaw_cli" -and -not [string]::IsNullOrWhiteSpace([string]$result)) {
                Write-Host ""
                Write-Host ([string]$result)
            }
            Write-Host ""
        } catch {
            Write-Host ""
            Write-Host ("[{0}] failed: {1}" -f $Engine, $_.Exception.Message) -ForegroundColor Red
            Write-Host ""
        }
    }

    Start-Sleep -Milliseconds 500
}
