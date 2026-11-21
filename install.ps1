# Applies everything the manifest describes: Nerd Font, Windows Terminal settings, PowerShell prompt and
# VS Code settings, theme and extensions. A wrapper around Install-DevEnv from the DevEnv module, for
# bootstrap.ps1 and for running without importing the module. Safe to run again.
# Needs PowerShell 7. On a new machine use bootstrap.ps1 instead, which installs PowerShell 7 first.
# Run with:  & "$HOME\code\dev-env-customization\install.ps1" [-Component <names>] [-Manifest <path>] [-WhatIf]
# -WhatIf/-Confirm flow through to Install-DevEnv
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Justification = 'Delegated to Install-DevEnv')]
[CmdletBinding(SupportsShouldProcess)]
param(
    # Which components to set up (Font, Terminal, Prompt, VSCode); defaults to all of them
    [ValidateSet('Font', 'Terminal', 'Prompt', 'VSCode')]
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
