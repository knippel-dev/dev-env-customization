# What the public commands return for each component, one row per thing checked or changed.
# Status is one of:
#   UpToDate     already set up, nothing to do
#   Updated      set up or changed now
#   NeedsUpdate  not set up yet (Get-DevEnv, or Sync-DevEnv -WhatIf)
#   NotFound     the app it customizes isn't installed, so it was skipped
#   Removed      removed by Uninstall-DevEnv
#   WouldRemove  would be removed (Uninstall-DevEnv -WhatIf)
#   NotInstalled nothing to remove
#   Skipped      deliberately left alone
#   Failed       something went wrong; Detail says what
function New-DevEnvResult {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Only creates an object')]
    param(
        [Parameter(Mandatory)]
        [string]$Component,
        [Parameter(Mandatory)]
        [string]$Status,
        [string]$Detail
    )
    [pscustomobject]@{
        PSTypeName = 'DevEnv.Result'
        Component  = $Component
        Status     = $Status
        Detail     = $Detail
    }
}

# Translates Update-JsonSettingsFile's result for an uninstall
function ConvertTo-RemovalStatus([string]$Status) {
    switch ($Status) {
        'UpToDate' { 'NotInstalled' }
        'Updated' { 'Removed' }
        'NeedsUpdate' { 'WouldRemove' }
    }
}
