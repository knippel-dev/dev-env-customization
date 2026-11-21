function Sync-DevEnv {
    <#
    .SYNOPSIS
    Makes this machine match the manifest.

    .DESCRIPTION
    Sets up each component from the manifest (manifests/default.psd1, with your personal manifest merged
    over it):

      Packages  apps, installed with winget
      Font      the Nerd Font, installed for the current user
      Terminal  Windows Terminal's default color scheme and font
      Prompt    the dual line prompt: its config for PowerShell and bash, and your PowerShell 7 profile
      VSCode    VS Code settings, the Dualline Dark theme and extensions
      Git       global git config
      Wsl       the dual line prompt in ~/.bashrc in WSL

    Safe to run any time, like after changing your manifest or pulling the repo: anything already set up is
    left alone. Settings files are merged, not replaced, and the original is kept as <file>.bak whenever one
    is changed.

    .PARAMETER Component
    Which components to sync. Defaults to all of them.

    .PARAMETER Manifest
    A personal manifest to merge over manifests/default.psd1. When not given, $env:DEVENV_MANIFEST or
    ~/.config/devenv/manifest.psd1 is used if present.

    .EXAMPLE
    Sync-DevEnv

    Syncs everything.

    .EXAMPLE
    Sync-DevEnv -Component Terminal, VSCode -WhatIf

    Shows what would change in Windows Terminal and VS Code, without changing anything.

    .EXAMPLE
    Sync-DevEnv -Manifest ~/work-manifest.psd1 -Verbose

    Uses a different personal manifest and shows each step.

    .OUTPUTS
    DevEnv.Result objects with Component, Status and Detail.
    #>
    # -WhatIf/-Confirm flow through to the component functions, which call ShouldProcess for each change
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Justification = 'Delegated to the component functions')]
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('DevEnv.Result')]
    param(
        [ValidateSet('Packages', 'Font', 'Terminal', 'Prompt', 'VSCode', 'Git', 'Wsl')]
        [string[]]$Component = $script:Components,
        [string]$Manifest
    )
    # Show progress messages, unless the caller chose otherwise (like -InformationAction SilentlyContinue)
    if (-not $PSBoundParameters.ContainsKey('InformationAction')) { $InformationPreference = 'Continue' }
    Invoke-DevEnvComponent -Verb Sync -Component $Component -Manifest $Manifest
}
