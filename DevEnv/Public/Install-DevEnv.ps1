function Install-DevEnv {
    <#
    .SYNOPSIS
    Sets up the dev environment described by the manifest.

    .DESCRIPTION
    Installs and configures each component from the manifest (manifests/default.psd1, with your personal
    manifest merged over it):

      Font      the Nerd Font, installed for the current user
      Terminal  Windows Terminal's default color scheme and font
      Prompt    the dual line prompt in your PowerShell 7 profile
      VSCode    VS Code settings, the Dualline Dark theme and extensions

    Safe to run again: anything already set up is left alone. Settings files are merged, not replaced, and
    the original is kept as <file>.bak whenever one is changed.

    .PARAMETER Component
    Which components to set up. Defaults to all of them.

    .PARAMETER Manifest
    A personal manifest to merge over manifests/default.psd1. When not given, $env:DEVENV_MANIFEST or
    ~/.config/devenv/manifest.psd1 is used if present.

    .EXAMPLE
    Install-DevEnv

    Sets up everything.

    .EXAMPLE
    Install-DevEnv -Component Terminal, VSCode -WhatIf

    Shows what would change in Windows Terminal and VS Code, without changing anything.

    .EXAMPLE
    Install-DevEnv -Manifest ~/work-manifest.psd1 -Verbose

    Uses a different personal manifest and shows each step.

    .OUTPUTS
    DevEnv.Result objects with Component, Status and Detail.
    #>
    # -WhatIf/-Confirm flow through to the component functions, which call ShouldProcess for each change
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Justification = 'Delegated to the component functions')]
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('DevEnv.Result')]
    param(
        [ValidateSet('Font', 'Terminal', 'Prompt', 'VSCode')]
        [string[]]$Component = $script:Components,
        [string]$Manifest
    )
    Invoke-DevEnvComponent -Verb Sync -Component $Component -Manifest $Manifest
}
