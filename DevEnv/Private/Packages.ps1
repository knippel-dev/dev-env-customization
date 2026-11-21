# Packages component: installs the manifest's apps with winget. Uninstalling leaves them installed, since
# removing tools like Git or VS Code isn't something a customization should do.

function Test-WingetPackage([string]$Id) {
    # winget list exits non-zero when the package isn't installed
    winget list --id $Id --exact --accept-source-agreements --disable-interactivity | Out-Null
    $LASTEXITCODE -eq 0
}

# Installers add to PATH in the registry; add any new entries to this session so later components (like Git
# and VS Code) can use the new commands without opening a new terminal
function Update-SessionPath {
    $current = $env:Path -split ';' | Where-Object { $_ }
    $registry = foreach ($scope in 'Machine', 'User') {
        [Environment]::GetEnvironmentVariable('Path', $scope) -split ';' | Where-Object { $_ }
    }
    $new = $registry | Where-Object { $_ -notin $current }
    if ($new) { $env:Path = (@($current) + @($new)) -join ';' }
}

function Sync-DevEnvPackages {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary]$Config,
        # Only report what would change
        [switch]$Check
    )
    $packages = @($Config.Packages)
    if (-not $packages) { return New-DevEnvResult Packages UpToDate 'No packages in the manifest' }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        return New-DevEnvResult Packages NotFound "winget was not found; install or update 'App Installer' from the Microsoft Store"
    }

    # A running log of each package (shown by Install/Sync-DevEnv), padded so the states line up
    $width = ($packages | Measure-Object -Property Length -Maximum).Maximum
    $missing = @(foreach ($id in $packages) {
            Write-Progress -Activity 'Checking packages' -Status $id
            $installed = Test-WingetPackage $id
            Write-Information ("    {0}  {1}" -f $id.PadRight($width), $(if ($installed) { 'already installed' } else { 'missing' }))
            if (-not $installed) { $id }
        })
    Write-Progress -Activity 'Checking packages' -Completed
    if (-not $missing) { return New-DevEnvResult Packages UpToDate "$($packages.Count) packages" }
    if ($Check) { return New-DevEnvResult Packages NeedsUpdate "Missing: $($missing -join ', ')" }

    $added = [Collections.Generic.List[string]]::new()
    $failed = [Collections.Generic.List[string]]::new()
    $winget = (Get-Command winget).Source
    $i = 0
    foreach ($id in $missing) {
        $i++
        if (-not $PSCmdlet.ShouldProcess($id, 'Install with winget')) { continue }
        $step = "[$i/$($missing.Count)] Installing $id"
        Write-Progress -Activity 'Installing packages' -Status $step -PercentComplete (100 * ($i - 1) / $missing.Count)
        # A line that stays in the scrollback, since winget's own output draws over the progress bar
        Write-Information "    $step"
        # Run straight in the console rather than through the pipeline, so winget shows its download and
        # install progress (and its output doesn't end up in this function's results)
        $process = Start-Process -FilePath $winget -NoNewWindow -Wait -PassThru -ArgumentList @(
            'install', '--id', $id, '--exact', '--source', 'winget', '--silent',
            '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'
        )
        if ($process.ExitCode -eq 0) { $added.Add($id) }
        else {
            $failed.Add("$id (winget exit code $($process.ExitCode))")
            Write-Information "    $id failed (winget exit code $($process.ExitCode))"
        }
    }
    Write-Progress -Activity 'Installing packages' -Completed
    if ($added.Count) { Update-SessionPath }

    if ($failed.Count) {
        $detail = "Could not install: $($failed -join ', ')"
        if ($added.Count) { $detail += "; installed: $($added -join ', ')" }
        New-DevEnvResult Packages Failed $detail
    }
    elseif ($added.Count) { New-DevEnvResult Packages Updated "Installed: $($added -join ', ')" }
    else { New-DevEnvResult Packages NeedsUpdate "Missing: $($missing -join ', ')" }
}

function Remove-DevEnvPackages {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary]$Config
    )
    New-DevEnvResult Packages Skipped 'Apps are left installed'
}
