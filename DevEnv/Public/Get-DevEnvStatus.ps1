function Get-DevEnvStatus {
    <#
    .SYNOPSIS
    Shows which parts of the dev environment are set up and which aren't.

    .DESCRIPTION
    Checks each component against the manifest without changing anything. A component reports UpToDate
    when it matches the manifest, NeedsUpdate when Install-DevEnv would change it, and NotFound when the
    app it customizes isn't installed.

    .PARAMETER Component
    Which components to check. Defaults to all of them.

    .PARAMETER Manifest
    A personal manifest to merge over manifests/default.psd1. When not given, $env:DEVENV_MANIFEST or
    ~/.config/devenv/manifest.psd1 is used if present.

    .EXAMPLE
    Get-DevEnvStatus

    .EXAMPLE
    Get-DevEnvStatus | Where-Object Status -ne UpToDate

    Lists only what Install-DevEnv would change.

    .OUTPUTS
    DevEnv.Result objects with Component, Status and Detail.
    #>
    [CmdletBinding()]
    [OutputType('DevEnv.Result')]
    param(
        [ValidateSet('Font', 'Terminal', 'Prompt', 'VSCode')]
        [string[]]$Component = $script:Components,
        [string]$Manifest
    )
    Invoke-DevEnvComponent -Verb Sync -Component $Component -Manifest $Manifest -Parameters @{ Check = $true }
}
