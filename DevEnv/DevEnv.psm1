# The repo the module lives in, for the default manifest, the prompt script and the VS Code theme
$script:RepoRoot = Split-Path -Parent $PSScriptRoot

# Components in the order they're installed: Packages first since later ones use the apps it installs (like
# git and code), and the font before Windows Terminal and VS Code, which use it.
$script:Components = 'Packages', 'Font', 'Terminal', 'Prompt', 'VSCode', 'Git', 'Wsl'

foreach ($folder in 'Private', 'Public') {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot $folder) -Filter *.ps1) {
        . $file.FullName
    }
}

Export-ModuleMember -Function Install-DevEnv, Sync-DevEnv, Get-DevEnv, Uninstall-DevEnv
