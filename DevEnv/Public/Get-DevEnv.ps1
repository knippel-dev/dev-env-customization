function Get-DevEnv {
    <#
    .SYNOPSIS
    Shows which parts of the dev environment match the manifest and which don't.

    .DESCRIPTION
    Checks each component against the manifest without changing anything. A component reports UpToDate
    when it matches the manifest, NeedsUpdate when Sync-DevEnv would change it, and NotFound when the app
    it customizes isn't installed. Without -Component, the first row shows whether Install-DevEnv has made
    the DevEnv commands available in every session.

    .PARAMETER Component
    Which components to check. Defaults to all of them.

    .PARAMETER Manifest
    A personal manifest to merge over manifests/default.psd1. When not given, $env:DEVENV_MANIFEST or
    ~/.config/devenv/manifest.psd1 is used if present.

    .EXAMPLE
    Get-DevEnv

    .EXAMPLE
    Get-DevEnv | Where-Object Status -ne UpToDate

    Lists only what Sync-DevEnv would change.

    .OUTPUTS
    DevEnv.Result objects with Component, Status and Detail.
    #>
    [CmdletBinding()]
    [OutputType('DevEnv.Result')]
    param(
        [ValidateSet('Packages', 'Font', 'Terminal', 'Prompt', 'VSCode', 'Git', 'Wsl')]
        [string[]]$Component = $script:Components,
        [string]$Manifest
    )
    if (-not $PSBoundParameters.ContainsKey('Component')) { Sync-DevEnvModule -Check }
    Invoke-DevEnvComponent -Verb Sync -Component $Component -Manifest $Manifest -Parameters @{ Check = $true }
}
