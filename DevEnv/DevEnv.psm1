# The repo the module lives in, for the default manifest, the prompt script and the VS Code theme
$script:RepoRoot = Split-Path -Parent $PSScriptRoot

# Components in the order they're installed. The font goes first because Windows Terminal and VS Code use it.
$script:Components = 'Font', 'Terminal', 'Prompt', 'VSCode'

foreach ($folder in 'Private', 'Public') {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot $folder) -Filter *.ps1) {
        . $file.FullName
    }
}

Export-ModuleMember -Function Install-DevEnv, Get-DevEnvStatus, Uninstall-DevEnv
