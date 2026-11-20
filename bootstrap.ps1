# Sets up a new Windows machine for this repo: installs PowerShell 7, Git, GitHub CLI and VS Code with
# winget, clones the repo and runs the VS Code install script.
# Runs on the Windows PowerShell 5.1 that ships with Windows, so nothing needs to be installed first:
#   irm https://raw.githubusercontent.com/knippel-dev/dev-env-customization/main/bootstrap.ps1 | iex
# Safe to run again; anything already installed or cloned is skipped.
# Optional environment variables (set before running):
#   DEVENV_DIR          where to clone the repo (default: $HOME\code\dev-env-customization)
#   DEVENV_SKIP_VSCODE  set to 1 to skip running vscode\install.ps1
# Wrapped in a script block so settings like $ErrorActionPreference don't leak into the caller when piped to iex
& {
    $ErrorActionPreference = 'Stop'

    $repoUrl = 'https://github.com/knippel-dev/dev-env-customization.git'
    $repoDir = if ($env:DEVENV_DIR) { $env:DEVENV_DIR } else { Join-Path $HOME 'code\dev-env-customization' }

    $packages = [ordered]@{
        'Microsoft.PowerShell'       = 'PowerShell 7'
        'Git.Git'                    = 'Git'
        'GitHub.cli'                 = 'GitHub CLI'
        'Microsoft.VisualStudioCode' = 'VS Code'
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget was not found. Install or update 'App Installer' from the Microsoft Store, then run this again."
    }

    foreach ($id in $packages.Keys) {
        $name = $packages[$id]
        # winget list exits non-zero when the package isn't installed
        winget list --id $id --exact --accept-source-agreements | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "$name already installed"
            continue
        }
        Write-Host "Installing $name"
        winget install --id $id --exact --source winget --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { throw "Installing $name failed (winget exit code $LASTEXITCODE)" }
    }

    # Installers update PATH in the registry, so reload it to use the new commands without opening a new terminal
    $env:Path = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine')
        [Environment]::GetEnvironmentVariable('Path', 'User')
    ) -join ';'

    if (Test-Path -LiteralPath (Join-Path $repoDir '.git')) {
        Write-Host "Repo already cloned at $repoDir"
    }
    else {
        Write-Host "Cloning $repoUrl to $repoDir"
        New-Item -ItemType Directory -Force (Split-Path -Parent $repoDir) | Out-Null
        git clone $repoUrl $repoDir
        if ($LASTEXITCODE -ne 0) { throw "git clone failed (exit code $LASTEXITCODE)" }
    }

    # vscode\install.ps1 needs PowerShell 7, so run it with pwsh rather than in this session
    if ($env:DEVENV_SKIP_VSCODE -ne '1') {
        Write-Host 'Applying VS Code settings, theme and extensions'
        pwsh -NoProfile -File (Join-Path $repoDir 'vscode\install.ps1')
        if ($LASTEXITCODE -ne 0) { throw "vscode\install.ps1 failed (exit code $LASTEXITCODE)" }
    }

    Write-Host ''
    Write-Host 'Done. Remaining steps (see README.md in the repo):'
    Write-Host '  - Sign in to GitHub:  gh auth login'
    Write-Host '  - Install a Nerd Font and set it as the Windows Terminal font'
    Write-Host '  - Dot source the prompt from your PowerShell profile'
    Write-Host '  - Open a new terminal so the updated PATH is picked up'
}
