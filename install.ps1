# Applies all the customizations in this repo: Nerd Font, Windows Terminal settings, PowerShell prompt
# and VS Code settings, theme and extensions. Safe to run again; anything already done is skipped.
# Needs PowerShell 7. On a new machine use bootstrap.ps1 instead, which installs PowerShell 7 first.
# Run with:  & "$HOME\code\dev-env-customization\install.ps1"
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'Run this with PowerShell 7 (pwsh), or use bootstrap.ps1 which installs it first.'
}

# The font goes first because Windows Terminal and VS Code are both set to use it
& "$PSScriptRoot\fonts\install.ps1"
& "$PSScriptRoot\terminal\install.ps1"
& "$PSScriptRoot\powershell\install.ps1"
& "$PSScriptRoot\vscode\install.ps1"
