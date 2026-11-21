function Uninstall-DevEnv {
    <#
    .SYNOPSIS
    Removes what Install-DevEnv set up.

    .DESCRIPTION
    Undoes each component's changes, leaving anything else alone:

      VSCode    removes the settings that still have the manifest's values and uninstalls the theme.
                Other extensions are left installed.
      Prompt    removes the block Install-DevEnv added to your PowerShell profile
      Terminal  removes the color scheme, and the default color scheme and font if they're still the manifest's
      Font      uninstalls the Nerd Font. Close Windows Terminal and VS Code first, since they keep it in use.

    Settings you changed after installing are kept, because only values that still match the manifest are
    removed. Changed files are backed up to <file>.bak first. Asks for confirmation unless -Confirm:$false
    is given.

    .PARAMETER Component
    Which components to remove. Defaults to all of them.

    .PARAMETER Manifest
    The personal manifest that was used to install, so the same values are removed.

    .EXAMPLE
    Uninstall-DevEnv -WhatIf

    Shows what would be removed.

    .EXAMPLE
    Uninstall-DevEnv -Component Prompt -Confirm:$false

    Removes the prompt from your profile without asking.

    .OUTPUTS
    DevEnv.Result objects with Component, Status and Detail.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType('DevEnv.Result')]
    param(
        [ValidateSet('Font', 'Terminal', 'Prompt', 'VSCode')]
        [string[]]$Component = $script:Components,
        [string]$Manifest
    )
    # With -WhatIf, skip the confirmation so each component can list exactly what it would remove
    if (-not $WhatIfPreference -and
        -not $PSCmdlet.ShouldProcess(($Component -join ', '), 'Remove the dev environment customizations')) {
        return
    }
    Invoke-DevEnvComponent -Verb Remove -Component $Component -Manifest $Manifest -Reverse
}
