# Applies all the customizations in this repo: Nerd Font, Windows Terminal settings, PowerShell prompt
# and VS Code settings, theme and extensions, as described by the manifest (manifests/default.psd1 plus
# your personal manifest, if any). Safe to run again; anything already done is skipped.
# Needs PowerShell 7. On a new machine use bootstrap.ps1 instead, which installs PowerShell 7 first.
# Run with:  & "$HOME\code\dev-env-customization\install.ps1"
param(
    # Personal manifest to merge over manifests/default.psd1. When not given, $env:DEVENV_MANIFEST or
    # ~/.config/devenv/manifest.psd1 is used if present.
    [string]$Manifest
)
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'Run this with PowerShell 7 (pwsh), or use bootstrap.ps1 which installs it first.'
}

foreach ($helper in Get-ChildItem "$PSScriptRoot\DevEnv\Private\*.ps1") { . $helper.FullName }
$Manifest = Get-DevEnvManifestPath $Manifest
if ($Manifest) { Write-Host "Using personal manifest $Manifest" }

# The font goes first because Windows Terminal and VS Code are both set to use it
& "$PSScriptRoot\fonts\install.ps1" -Manifest $Manifest
& "$PSScriptRoot\terminal\install.ps1" -Manifest $Manifest
& "$PSScriptRoot\powershell\install.ps1"
& "$PSScriptRoot\vscode\install.ps1" -Manifest $Manifest
