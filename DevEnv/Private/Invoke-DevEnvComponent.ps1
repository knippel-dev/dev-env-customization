# Runs <Verb>-DevEnv<Component> for each selected component, in install order (or reverse order for
# uninstalling). A component that throws is reported as Failed and the others still run.
function Invoke-DevEnvComponent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Sync', 'Remove')]
        [string]$Verb,
        [Parameter(Mandatory)]
        [string[]]$Component,
        [string]$Manifest,
        # Extra parameters for each component function, like @{ Check = $true }
        [hashtable]$Parameters = @{},
        [switch]$Reverse
    )
    $ErrorActionPreference = 'Stop'
    $config = Get-DevEnvManifest $Manifest
    $manifestPath = Get-DevEnvManifestPath $Manifest
    if ($manifestPath) { Write-Verbose "Using personal manifest $manifestPath" }

    $order = if ($Reverse) { $script:Components[-1..-($script:Components.Count)] } else { $script:Components }
    foreach ($name in $order) {
        if ($name -notin $Component) { continue }
        try {
            & "$Verb-DevEnv$name" -Config $config @Parameters
        }
        catch {
            Write-Verbose $_.ScriptStackTrace
            New-DevEnvResult $name Failed $_.Exception.Message
        }
    }
}
