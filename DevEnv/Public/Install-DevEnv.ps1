function Install-DevEnv {
    <#
    .SYNOPSIS
    Installs DevEnv: makes its commands available in every PowerShell session and syncs the machine with
    the manifest.

    .DESCRIPTION
    Adds this repo's folder to your user PSModulePath, so Sync-DevEnv, Get-DevEnv and Uninstall-DevEnv work
    in any PowerShell session without Import-Module, then runs Sync-DevEnv. This is what install.ps1 and
    bootstrap.ps1 run. Safe to run again.

    Afterwards, use Sync-DevEnv to apply changes to your manifest, and Get-DevEnv to see what's set up.

    .PARAMETER Component
    Which components to sync. Defaults to all of them. The commands are made available either way.

    .PARAMETER Manifest
    A personal manifest to merge over manifests/default.psd1. When not given, $env:DEVENV_MANIFEST or
    ~/.config/devenv/manifest.psd1 is used if present.

    .EXAMPLE
    Install-DevEnv

    .EXAMPLE
    Install-DevEnv -WhatIf

    Shows everything that would change, without changing anything.

    .OUTPUTS
    DevEnv.Result objects with Component, Status and Detail.
    #>
    # -WhatIf/-Confirm flow through to the functions that make the changes, which call ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Justification = 'Delegated to Sync-DevEnvModule and Sync-DevEnv')]
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('DevEnv.Result')]
    param(
        [ValidateSet('Packages', 'Font', 'Terminal', 'Prompt', 'VSCode', 'Git', 'Wsl')]
        [string[]]$Component = $script:Components,
        [string]$Manifest
    )
    try { Sync-DevEnvModule -ErrorAction Stop }
    catch { New-DevEnvResult Module Failed $_.Exception.Message }
    Sync-DevEnv -Component $Component -Manifest $Manifest
}
