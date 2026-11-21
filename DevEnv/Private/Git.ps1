# Git component: applies the manifest's global git config (git config --global <key> <value>).

# The manifest's settings as git config strings, sorted so they're applied in the same order every time
function Get-GitWantedSetting([Collections.IDictionary]$Config) {
    $wanted = [ordered]@{}
    if (-not $Config.Git) { return $wanted }
    foreach ($key in $Config.Git.Keys | Sort-Object) {
        $value = $Config.Git[$key]
        # git writes booleans in lowercase
        $wanted[$key] = if ($value -is [bool]) { "$value".ToLower() } else { [string]$value }
    }
    $wanted
}

function Get-GitGlobalSetting([string]$Key) {
    $value = git config --global --get $Key
    if ($LASTEXITCODE -eq 0) { $value }
}

function Sync-DevEnvGit {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary]$Config,
        # Only report what would change
        [switch]$Check
    )
    $wanted = Get-GitWantedSetting $Config
    if (-not $wanted.Count) { return New-DevEnvResult Git UpToDate 'No git settings in the manifest' }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return New-DevEnvResult Git NotFound 'Git is not installed' }

    $changed = @($wanted.Keys | Where-Object { (Get-GitGlobalSetting $_) -cne $wanted[$_] })
    if (-not $changed) { return New-DevEnvResult Git UpToDate "$($wanted.Count) global settings" }
    if ($Check) { return New-DevEnvResult Git NeedsUpdate ($changed -join ', ') }

    $set = foreach ($key in $changed) {
        if (-not $PSCmdlet.ShouldProcess("git config --global $key", 'Set')) { continue }
        git config --global $key $wanted[$key]
        if ($LASTEXITCODE -ne 0) { throw "git config --global $key failed (exit code $LASTEXITCODE)" }
        $key
    }
    if ($set) { New-DevEnvResult Git Updated ($set -join ', ') }
    else { New-DevEnvResult Git NeedsUpdate ($changed -join ', ') }
}

# Unsets the settings that still have the manifest's values
function Remove-DevEnvGit {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary]$Config
    )
    $wanted = Get-GitWantedSetting $Config
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return New-DevEnvResult Git NotFound 'Git is not installed' }
    $ours = @($wanted.Keys | Where-Object { (Get-GitGlobalSetting $_) -ceq $wanted[$_] })
    if (-not $ours) { return New-DevEnvResult Git NotInstalled 'No global settings with the manifest''s values' }

    $removed = foreach ($key in $ours) {
        if (-not $PSCmdlet.ShouldProcess("git config --global $key", 'Unset')) { continue }
        git config --global --unset $key
        if ($LASTEXITCODE -ne 0) { throw "git config --global --unset $key failed (exit code $LASTEXITCODE)" }
        $key
    }
    if ($removed) { New-DevEnvResult Git Removed ($removed -join ', ') }
    else { New-DevEnvResult Git WouldRemove ($ours -join ', ') }
}
