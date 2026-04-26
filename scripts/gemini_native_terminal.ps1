param(
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][string]$Workdir,
    [Parameter(Mandatory = $true)][string]$Executable
)

$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot "gemini_env.ps1")
Import-GeminiEnvironmentLikeInteractiveTerminal
Apply-GeminiCliEnvironment -Root $Workdir
$Host.UI.RawUI.WindowTitle = $Title
Set-Location -LiteralPath $Workdir
& $Executable
