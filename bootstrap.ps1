# Sets up a new Windows machine: installs PowerShell 7 and Git with winget, clones this repo and runs
# install.ps1, which installs the rest of the apps in the manifest and applies all the customizations.
# Runs on the Windows PowerShell 5.1 that ships with Windows, so nothing needs to be installed first:
#   irm https://raw.githubusercontent.com/knippel-dev/dev-env-customization/main/bootstrap.ps1 | iex
# To pass parameters, run it as a script block instead:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/knippel-dev/dev-env-customization/main/bootstrap.ps1))) -Manifest ~\my-manifest.psd1
# Parameters (each can also be set with an environment variable before running):
#   -Path         where to clone the repo ($env:DEVENV_DIR; default $HOME\code\dev-env-customization)
#   -Manifest     a personal manifest for install.ps1 ($env:DEVENV_MANIFEST)
#   -SkipInstall  only install PowerShell 7 and Git and clone, without running install.ps1 ($env:DEVENV_SKIP_INSTALL = '1')
# Safe to run again; anything already installed or cloned is skipped.
#
# Everything is in a script block, with the arguments forwarded to it, so that when piped to iex neither
# the parameters nor settings like $ErrorActionPreference leak into the caller's session.
& {
    param(
        [string]$Path = $(if ($env:DEVENV_DIR) { $env:DEVENV_DIR } else { Join-Path $HOME 'code\dev-env-customization' }),
        [string]$Manifest = $env:DEVENV_MANIFEST,
        [switch]$SkipInstall = ($env:DEVENV_SKIP_INSTALL -eq '1')
    )
    $ErrorActionPreference = 'Stop'

    $repoUrl = 'https://github.com/knippel-dev/dev-env-customization.git'
    # Just what's needed to clone the repo and run install.ps1; the manifest's other apps are installed by it
    $packages = [ordered]@{
        'Microsoft.PowerShell' = 'PowerShell 7'
        'Git.Git'              = 'Git'
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget was not found. Install or update 'App Installer' from the Microsoft Store, then run this again."
    }
    if ($Manifest) {
        # Resolved now, since install.ps1 runs from another process
        $Manifest = (Resolve-Path -LiteralPath $Manifest).ProviderPath
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

    if (Test-Path -LiteralPath (Join-Path $Path '.git')) {
        Write-Host "Repo already cloned at $Path"
    }
    else {
        Write-Host "Cloning $repoUrl to $Path"
        New-Item -ItemType Directory -Force (Split-Path -Parent $Path) | Out-Null
        git clone $repoUrl $Path
        if ($LASTEXITCODE -ne 0) { throw "git clone failed (exit code $LASTEXITCODE)" }
    }

    # install.ps1 needs PowerShell 7, so run it with pwsh rather than in this session
    if (-not $SkipInstall) {
        $installArgs = @('-NoProfile', '-File', (Join-Path $Path 'install.ps1'))
        if ($Manifest) { $installArgs += '-Manifest', $Manifest }
        pwsh @installArgs
        if ($LASTEXITCODE -ne 0) { throw "install.ps1 failed (exit code $LASTEXITCODE)" }
    }

    Write-Host ''
    Write-Host 'Done. Remaining steps:'
    Write-Host '  - Open a new terminal (restart Windows Terminal and VS Code) to pick up the PATH, font and prompt'
    Write-Host '  - Sign in to GitHub:  gh auth login'
    Write-Host '  - If you install WSL later, run install.ps1 -Component Wsl to add the prompt there'
} @args
