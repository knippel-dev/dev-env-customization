# Font component: installs the manifest's Nerd Font for the current user (no admin needed) from the Nerd
# Fonts GitHub releases. Only the regular family is installed (not the Mono or Propo variants, whose icons
# are smaller).

$script:FontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
$script:FontRegistryPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'

# Lets running apps see fonts being added or removed without signing out
function Initialize-FontResourceApi {
    if ('DevEnv.FontResource' -as [type]) { return }
    Add-Type -Namespace DevEnv -Name FontResource -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern int AddFontResource(string file);
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern int RemoveFontResource(string file);
'@
}

# Registry value names of the installed font files, like 'IosevkaTermNerdFont-Bold (TrueType)'
function Get-FontRegistration([string]$Font) {
    $key = Get-Item -LiteralPath $script:FontRegistryPath -ErrorAction SilentlyContinue
    if ($key) { $key.Property | Where-Object { $_ -match "^$([regex]::Escape($Font))NerdFont-" } }
}

function Sync-DevEnvFont {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary]$Config,
        # Only report what would change
        [switch]$Check
    )
    $font = $Config.Font.Name
    if (Get-FontRegistration $font) { return New-DevEnvResult Font UpToDate "$font Nerd Font" }
    if ($Check -or -not $PSCmdlet.ShouldProcess("$font Nerd Font", 'Download and install')) {
        return New-DevEnvResult Font NeedsUpdate "$font Nerd Font is not installed"
    }

    # The progress bar makes Invoke-WebRequest much slower on large downloads
    $ProgressPreference = 'SilentlyContinue'
    # Files in the zip look like IosevkaTermNerdFont-Bold.ttf, IosevkaTermNerdFontMono-Bold.ttf, ...
    $pattern = "^$([regex]::Escape($font))NerdFont-.+\.(ttf|otf)$"
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "nerd-font-$font"
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    New-Item -ItemType Directory -Force $tmp | Out-Null
    try {
        Write-Information "    Downloading $font Nerd Font"
        $zip = Join-Path $tmp "$font.zip"
        Invoke-WebRequest "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$font.zip" -OutFile $zip
        Expand-Archive -LiteralPath $zip -DestinationPath $tmp

        $files = Get-ChildItem -LiteralPath $tmp -Recurse -File | Where-Object { $_.Name -match $pattern }
        if (-not $files) { throw "No font files matching $pattern were found in $font.zip" }

        Initialize-FontResourceApi
        New-Item -ItemType Directory -Force $script:FontDir | Out-Null
        if (-not (Test-Path -LiteralPath $script:FontRegistryPath)) { New-Item -Path $script:FontRegistryPath -Force | Out-Null }
        foreach ($file in $files) {
            $dest = Join-Path $script:FontDir $file.Name
            Copy-Item -LiteralPath $file.FullName -Destination $dest -Force
            $type = if ($file.Extension -eq '.otf') { 'OpenType' } else { 'TrueType' }
            Set-ItemProperty -LiteralPath $script:FontRegistryPath -Name "$($file.BaseName) ($type)" -Value $dest
            [void][DevEnv.FontResource]::AddFontResource($dest)
        }
        New-DevEnvResult Font Updated "Installed $($files.Count) $font Nerd Font files"
    }
    finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Remove-DevEnvFont {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary]$Config
    )
    $font = $Config.Font.Name
    $names = @(Get-FontRegistration $font)
    if (-not $names) { return New-DevEnvResult Font NotInstalled "$font Nerd Font" }
    if (-not $PSCmdlet.ShouldProcess("$font Nerd Font ($($names.Count) files)", 'Uninstall')) {
        return New-DevEnvResult Font WouldRemove "$font Nerd Font"
    }

    Initialize-FontResourceApi
    $inUse = 0
    foreach ($name in $names) {
        $file = (Get-ItemProperty -LiteralPath $script:FontRegistryPath -Name $name).$name
        # Entries can also be a bare file name, relative to the fonts folder
        if (-not [IO.Path]::IsPathRooted($file)) { $file = Join-Path $script:FontDir $file }
        [void][DevEnv.FontResource]::RemoveFontResource($file)
        try {
            if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force -ErrorAction Stop }
        }
        catch {
            # Keep the registry entry so the font still works and a later run can finish removing it
            [void][DevEnv.FontResource]::AddFontResource($file)
            $inUse++
            continue
        }
        Remove-ItemProperty -LiteralPath $script:FontRegistryPath -Name $name
    }
    if ($inUse) {
        return New-DevEnvResult Font Failed "$inUse font files are in use. Close Windows Terminal and VS Code, then run again from another terminal."
    }
    New-DevEnvResult Font Removed "$font Nerd Font"
}
