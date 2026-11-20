# Adds the dual line prompt to the PowerShell 7 'Current User, All Hosts' profile, using the VSCode
# variant automatically inside the VS Code integrated terminal. Does nothing if the profile already loads it.
# Run with PowerShell 7:  & "$HOME\code\dev-env-customization\powershell\install.ps1"
param(
    [string]$ProfilePath = $PROFILE.CurrentUserAllHosts
)
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'Run this with PowerShell 7 (pwsh) so it updates the PowerShell 7 profile.'
}

$promptScript = Join-Path $PSScriptRoot 'dualline-prompt.ps1'
if ((Test-Path -LiteralPath $ProfilePath) -and
    (Select-String -LiteralPath $ProfilePath -Pattern 'dualline-prompt\.ps1' -Quiet)) {
    Write-Host "Profile already loads the prompt: $ProfilePath"
    return
}

# Write the path relative to $HOME when possible, so a profile synced to another machine (for example
# through OneDrive) still works there
$pathText = if ($promptScript.StartsWith("$HOME\", [StringComparison]::OrdinalIgnoreCase)) {
    '$HOME' + $promptScript.Substring($HOME.Length)
}
else { $promptScript }

$block = @"

# Dual line prompt from dev-env-customization (added by powershell/install.ps1)
`$devEnvPrompt = "$pathText"
if (Test-Path -LiteralPath `$devEnvPrompt) {
    . `$devEnvPrompt -Variant `$(if (`$env:TERM_PROGRAM -eq 'vscode') { 'VSCode' } else { 'Default' })
}
Remove-Variable devEnvPrompt
"@

New-Item -ItemType Directory -Force (Split-Path -Parent $ProfilePath) | Out-Null
Add-Content -LiteralPath $ProfilePath -Value $block -Encoding utf8NoBOM
Write-Host "Added the prompt to $ProfilePath"
