function Uninstall-DevEnv {
    <#
    .SYNOPSIS
    Removes the dev environment customizations, and DevEnv itself.

    .DESCRIPTION
    Undoes each component's changes, leaving anything else alone:

      Wsl       removes the lines DevEnv added to ~/.bashrc in WSL
      Git       unsets the global git settings that still have the manifest's values
      VSCode    removes the settings that still have the manifest's values and uninstalls the theme.
                Other extensions are left installed.
      Prompt    removes the block DevEnv added to your PowerShell profile
      Terminal  removes the color scheme, and the default color scheme and font if they're still the manifest's
      Font      uninstalls the Nerd Font. Close Windows Terminal and VS Code first, since they keep it in use.
      Packages  nothing: apps are left installed

    Without -Component, it then removes this repo's folder from your PSModulePath (undoing Install-DevEnv),
    so the DevEnv commands are no longer available in new sessions. The repo itself is left in place.

    Settings you changed after syncing are kept, because only values that still match the manifest are
    removed. Changed files are backed up to <file>.bak first. Asks for confirmation unless -Confirm:$false
    is given.

    .PARAMETER Component
    Which components to remove. Defaults to all of them, plus the PSModulePath entry.

    .PARAMETER Manifest
    The personal manifest that was used to sync, so the same values are removed.

    .EXAMPLE
    Uninstall-DevEnv -WhatIf

    Shows what would be removed.

    .EXAMPLE
    Uninstall-DevEnv -Component Prompt -Confirm:$false

    Removes the prompt from your profile without asking, and keeps everything else.

    .OUTPUTS
    DevEnv.Result objects with Component, Status and Detail.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType('DevEnv.Result')]
    param(
        [ValidateSet('Packages', 'Font', 'Terminal', 'Prompt', 'VSCode', 'Git', 'Wsl')]
        [string[]]$Component = $script:Components,
        [string]$Manifest
    )
    $everything = -not $PSBoundParameters.ContainsKey('Component')
    $target = if ($everything) { 'DevEnv and all its customizations' } else { $Component -join ', ' }
    # With -WhatIf, skip the confirmation so each component can list exactly what it would remove
    if (-not $WhatIfPreference -and -not $PSCmdlet.ShouldProcess($target, 'Remove')) {
        return
    }
    Invoke-DevEnvComponent -Verb Remove -Component $Component -Manifest $Manifest -Reverse
    if ($everything) { Remove-DevEnvModule }
}
