# Module registration, done by Install-DevEnv and undone by Uninstall-DevEnv: adds the repo folder to the
# user's PSModulePath, so the DevEnv commands work in any PowerShell session without Import-Module.
#
# The registry is edited directly instead of with [Environment]::SetEnvironmentVariable, which would rewrite
# the value as a plain string and expand any %VARIABLE% references in it for good.

# Under HKEY_CURRENT_USER; tests point this somewhere else
$script:EnvironmentKey = 'Environment'

function Get-UserModulePath([string]$KeyPath) {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($KeyPath)
    if (-not $key) { return }
    try { $key.GetValue('PSModulePath', $null, 'DoNotExpandEnvironmentNames') }
    finally { $key.Dispose() }
}

# Writes the value (deleting it when empty) and tells running apps the environment changed, so terminals
# opened from now on see it
function Set-UserModulePath([string]$KeyPath, [string]$Value) {
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($KeyPath)
    try {
        if ($Value) {
            $kind = if ($key.GetValueNames() -contains 'PSModulePath') { $key.GetValueKind('PSModulePath') } else { 'ExpandString' }
            $key.SetValue('PSModulePath', $Value, $kind)
        }
        else { $key.DeleteValue('PSModulePath', $false) }
    }
    finally { $key.Dispose() }

    if (-not ('DevEnv.SettingChange' -as [type])) {
        Add-Type -Namespace DevEnv -Name SettingChange -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, UIntPtr wParam, string lParam, uint flags, uint timeout, out UIntPtr result);
'@
    }
    $result = [UIntPtr]::Zero
    # HWND_BROADCAST, WM_SETTINGCHANGE, SMTO_ABORTIFHUNG
    [void][DevEnv.SettingChange]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result)
}

function Test-SamePath([string]$A, [string]$B) {
    $normalize = { [IO.Path]::TrimEndingDirectorySeparator([Environment]::ExpandEnvironmentVariables($args[0])) }
    [string]::Equals((& $normalize $A), (& $normalize $B), [StringComparison]::OrdinalIgnoreCase)
}

function Sync-DevEnvModule {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$KeyPath = $script:EnvironmentKey,
        # Only report what would change
        [switch]$Check
    )
    $entries = @((Get-UserModulePath $KeyPath) -split ';' | Where-Object { $_ })
    if ($entries | Where-Object { Test-SamePath $_ $script:RepoRoot }) {
        return New-DevEnvResult Module UpToDate "$script:RepoRoot is in your PSModulePath"
    }
    if ($Check -or -not $PSCmdlet.ShouldProcess('PSModulePath (user environment variable)', "Add $script:RepoRoot")) {
        return New-DevEnvResult Module NeedsUpdate "$script:RepoRoot is not in your PSModulePath"
    }

    Set-UserModulePath $KeyPath ((@($entries) + $script:RepoRoot) -join ';')
    # This session too, so the commands are found without opening a new terminal
    if (-not ($env:PSModulePath -split ';' | Where-Object { $_ -and (Test-SamePath $_ $script:RepoRoot) })) {
        $env:PSModulePath = "$env:PSModulePath;$script:RepoRoot"
    }
    New-DevEnvResult Module Updated "Added $script:RepoRoot to your PSModulePath"
}

function Remove-DevEnvModule {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$KeyPath = $script:EnvironmentKey
    )
    $entries = @((Get-UserModulePath $KeyPath) -split ';' | Where-Object { $_ })
    $kept = @($entries | Where-Object { -not (Test-SamePath $_ $script:RepoRoot) })
    if ($kept.Count -eq $entries.Count) { return New-DevEnvResult Module NotInstalled "$script:RepoRoot is not in your PSModulePath" }
    if (-not $PSCmdlet.ShouldProcess('PSModulePath (user environment variable)', "Remove $script:RepoRoot")) {
        return New-DevEnvResult Module WouldRemove "$script:RepoRoot from your PSModulePath"
    }

    Set-UserModulePath $KeyPath ($kept -join ';')
    $env:PSModulePath = ($env:PSModulePath -split ';' | Where-Object { $_ -and -not (Test-SamePath $_ $script:RepoRoot) }) -join ';'
    New-DevEnvResult Module Removed "$script:RepoRoot from your PSModulePath"
}
