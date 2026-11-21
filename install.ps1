# Installs DevEnv from this repo: runs Install-DevEnv, which makes the DevEnv commands available in every
# PowerShell session and syncs the machine with the manifest (apps, Nerd Font, Windows Terminal settings,
# PowerShell and WSL prompt, VS Code settings, theme and extensions, and git config). Used by bootstrap.ps1,
# and for the first install, before the commands are available. Safe to run again.
# Needs PowerShell 7. On a new machine use bootstrap.ps1 instead, which installs PowerShell 7 first.
# Run with:  & "$HOME\code\dev-env-customization\install.ps1" [-Component <names>] [-Manifest <path>] [-WhatIf]
# -WhatIf/-Confirm flow through to Install-DevEnv
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Justification = 'Delegated to Install-DevEnv')]
[CmdletBinding(SupportsShouldProcess)]
param(
    # Which components to set up (Packages, Font, Terminal, Prompt, VSCode, Git, Wsl); defaults to all of them
    [string[]]$Component,
    # Personal manifest to merge over manifests/default.psd1. When not given, $env:DEVENV_MANIFEST or
    # ~/.config/devenv/manifest.psd1 is used if present.
    [string]$Manifest
)
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'Run this with PowerShell 7 (pwsh), or use bootstrap.ps1 which installs it first.'
}

Import-Module (Join-Path $PSScriptRoot 'DevEnv') -Force
$results = Install-DevEnv @PSBoundParameters
$results | Format-Table -AutoSize -Wrap | Out-Host
if ($results.Status -contains 'Failed') { exit 1 }
