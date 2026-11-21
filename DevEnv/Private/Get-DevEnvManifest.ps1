# The manifest describes what the install scripts set up. manifests/default.psd1 holds the defaults, and a
# personal manifest can be merged over it with only the values to change.

# Returns the personal manifest's path, or nothing when there isn't one. The first of these is used:
# -Path, $env:DEVENV_MANIFEST, ~/.config/devenv/manifest.psd1
function Get-DevEnvManifestPath {
    param([string]$Path)
    if (-not $Path) { $Path = $env:DEVENV_MANIFEST }
    if (-not $Path) {
        $userManifest = Join-Path $HOME '.config\devenv\manifest.psd1'
        if (Test-Path -LiteralPath $userManifest) { $Path = $userManifest }
    }
    if ($Path -and -not (Test-Path -LiteralPath $Path)) { throw "Manifest not found: $Path" }
    $Path
}

# Returns the default manifest with the personal manifest (see Get-DevEnvManifestPath) merged over it
function Get-DevEnvManifest {
    param([string]$Path)
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $repoRoot 'manifests\default.psd1')
    $Path = Get-DevEnvManifestPath $Path
    if ($Path) {
        $manifest = Merge-Hashtable $manifest (Import-PowerShellDataFile -LiteralPath $Path)
    }
    $manifest
}
