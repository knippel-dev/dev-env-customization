# VS Code component: merges the manifest's settings into VS Code's user settings, installs the Dualline
# Dark theme from vscode/theme and installs the manifest's extensions.

$script:ThemeDir = Join-Path $script:RepoRoot 'vscode\theme'
$script:VSCodeSettingsPath = "$env:APPDATA\Code\User\settings.json"

# The manifest's settings plus the font settings from Font.Face, sorted so new settings are added in the
# same order every time
function Get-VSCodeWantedSetting([Collections.IDictionary]$Config) {
    # The editor font is a CSS font list, so the name is quoted; the terminal font is a plain name
    $fontSettings = @{
        'editor.fontFamily'              = "'$($Config.Font.Face)'"
        'terminal.integrated.fontFamily' = $Config.Font.Face
    }
    $merged = Merge-Hashtable $fontSettings $Config.VSCode.Settings
    $wanted = [ordered]@{}
    foreach ($key in $merged.Keys | Sort-Object) { $wanted[$key] = $merged[$key] }
    $wanted
}

# Compares settings as JSON, so nested settings (like color customizations) are compared by content
function Test-SameSetting($a, $b) {
    ($a | ConvertTo-Json -Depth 20 -Compress) -eq ($b | ConvertTo-Json -Depth 20 -Compress)
}

function Get-ThemeInfo {
    $pkg = Get-Content -LiteralPath (Join-Path $script:ThemeDir 'package.json') -Raw | ConvertFrom-Json
    $id = "$($pkg.publisher).$($pkg.name)"
    [pscustomobject]@{
        Id              = $id
        Version         = $pkg.version
        Package         = $pkg
        # Where VS Code unpacks it
        InstalledFolder = Join-Path $HOME ".vscode\extensions\$id-$($pkg.version)"
    }
}

# True when this theme version is installed and its theme files match the repo's, so a changed color is
# picked up even if the version in package.json wasn't bumped
function Test-ThemeCurrent($Theme, [string[]]$InstalledExtensions) {
    if ("$($Theme.Id)@$($Theme.Version)" -notin $InstalledExtensions) { return $false }
    # Only the theme files: VS Code rewrites the installed package.json
    $themesDir = Join-Path $script:ThemeDir 'themes'
    foreach ($file in Get-ChildItem -LiteralPath $themesDir -Recurse -File) {
        $installed = Join-Path $Theme.InstalledFolder ([IO.Path]::GetRelativePath($script:ThemeDir, $file.FullName))
        if (-not (Test-Path -LiteralPath $installed)) { return $false }
        if ((Get-FileHash -LiteralPath $installed).Hash -ne (Get-FileHash -LiteralPath $file.FullName).Hash) { return $false }
    }
    $true
}

# Packages vscode/theme as a .vsix (a zip with a manifest) so it can be installed without Node or vsce
function Build-ThemeVsix($Theme, [string]$VsixPath) {
    $pkg = $Theme.Package
    $manifest = @"
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Language="en-US" Id="$($pkg.name)" Version="$($pkg.version)" Publisher="$($pkg.publisher)" />
    <DisplayName>$($pkg.displayName)</DisplayName>
    <Description xml:space="preserve">$($pkg.description)</Description>
    <Categories>Themes</Categories>
    <Properties>
      <Property Id="Microsoft.VisualStudio.Code.Engine" Value="$($pkg.engines.vscode)" />
    </Properties>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Code" />
  </Installation>
  <Dependencies />
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true" />
  </Assets>
</PackageManifest>
"@
    $contentTypes = @'
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension=".json" ContentType="application/json" />
  <Default Extension=".txt" ContentType="text/plain" />
  <Default Extension=".vsixmanifest" ContentType="text/xml" />
</Types>
'@

    Add-Type -AssemblyName System.IO.Compression
    if (Test-Path -LiteralPath $VsixPath) { Remove-Item -LiteralPath $VsixPath }
    $zip = [IO.Compression.ZipFile]::Open($VsixPath, 'Create')
    try {
        foreach ($entry in @{ 'extension.vsixmanifest' = $manifest; '[Content_Types].xml' = $contentTypes }.GetEnumerator()) {
            $writer = [IO.StreamWriter]::new($zip.CreateEntry($entry.Key).Open())
            $writer.Write($entry.Value); $writer.Dispose()
        }
        foreach ($file in Get-ChildItem -LiteralPath $script:ThemeDir -Recurse -File) {
            $relative = [IO.Path]::GetRelativePath($script:ThemeDir, $file.FullName).Replace('\', '/')
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, "extension/$relative") | Out-Null
        }
    }
    finally { $zip.Dispose() }
}

function Sync-DevEnvVSCode {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary]$Config,
        # VS Code's user settings file to merge into
        [string]$SettingsPath = $script:VSCodeSettingsPath,
        # Only report what would change
        [switch]$Check,
        # Only apply settings, without the theme and extensions
        [switch]$SkipExtensions
    )
    $wanted = Get-VSCodeWantedSetting $Config
    $changedKeys = [Collections.Generic.List[string]]::new()
    $status = Update-JsonSettingsFile -Path $SettingsPath -Check:$Check -Update {
        param($settings)
        foreach ($key in $wanted.Keys) {
            if (-not ($settings.Contains($key) -and (Test-SameSetting $settings[$key] $wanted[$key]))) {
                $settings[$key] = $wanted[$key]
                $changedKeys.Add($key)
            }
        }
    }
    $detail = if ($changedKeys.Count) { $changedKeys -join ', ' } else { "$($wanted.Count) settings in $SettingsPath" }
    New-DevEnvResult 'VSCode settings' $status $detail

    if ($SkipExtensions) { return }
    if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
        $notFound = "The 'code' command was not found; add VS Code to PATH"
        New-DevEnvResult 'VSCode theme' NotFound $notFound
        New-DevEnvResult 'VSCode extensions' NotFound $notFound
        return
    }
    $installed = @(code --list-extensions --show-versions)

    $theme = Get-ThemeInfo
    if (Test-ThemeCurrent $theme $installed) {
        New-DevEnvResult 'VSCode theme' UpToDate "$($theme.Id)@$($theme.Version)"
    }
    elseif ($Check -or -not $PSCmdlet.ShouldProcess("$($theme.Id)@$($theme.Version)", 'Install VS Code theme')) {
        New-DevEnvResult 'VSCode theme' NeedsUpdate "$($theme.Id)@$($theme.Version) is missing or changed"
    }
    else {
        Write-Information "    Installing theme $($theme.Id)@$($theme.Version)"
        $vsix = Join-Path ([IO.Path]::GetTempPath()) 'dualline-theme.vsix'
        Build-ThemeVsix $theme $vsix
        try {
            code --install-extension $vsix --force | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Installing the theme failed (code exit code $LASTEXITCODE)" }
        }
        finally { Remove-Item -LiteralPath $vsix -ErrorAction SilentlyContinue }
        New-DevEnvResult 'VSCode theme' Updated "$($theme.Id)@$($theme.Version)"
    }

    $installedIds = $installed | ForEach-Object { ($_ -split '@')[0] }
    $missing = @($Config.VSCode.Extensions | Where-Object { $_ -notin $installedIds })
    if (-not $missing) {
        return New-DevEnvResult 'VSCode extensions' UpToDate "$(@($Config.VSCode.Extensions).Count) extensions"
    }
    if ($Check) { return New-DevEnvResult 'VSCode extensions' NeedsUpdate "Missing: $($missing -join ', ')" }

    $added = [Collections.Generic.List[string]]::new()
    $failed = [Collections.Generic.List[string]]::new()
    foreach ($ext in $missing) {
        if (-not $PSCmdlet.ShouldProcess($ext, 'Install VS Code extension')) { continue }
        Write-Information "    Installing extension $ext"
        code --install-extension $ext | Out-Null
        if ($LASTEXITCODE -eq 0) { $added.Add($ext) } else { $failed.Add($ext) }
    }
    if ($failed.Count) { New-DevEnvResult 'VSCode extensions' Failed "Could not install: $($failed -join ', ')" }
    elseif ($added.Count) { New-DevEnvResult 'VSCode extensions' Updated "Installed: $($added -join ', ')" }
    else { New-DevEnvResult 'VSCode extensions' NeedsUpdate "Missing: $($missing -join ', ')" }
}

# Removes the settings that still have the manifest's values and uninstalls the theme. Other extensions are
# left installed, since they're general tools that may have been installed for other reasons.
function Remove-DevEnvVSCode {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary]$Config,
        [string]$SettingsPath = $script:VSCodeSettingsPath,
        [switch]$SkipExtensions
    )
    $wanted = Get-VSCodeWantedSetting $Config
    $removedKeys = [Collections.Generic.List[string]]::new()
    $status = Update-JsonSettingsFile -Path $SettingsPath -Update {
        param($settings)
        foreach ($key in $wanted.Keys) {
            if ($settings.Contains($key) -and (Test-SameSetting $settings[$key] $wanted[$key])) {
                $settings.Remove($key)
                $removedKeys.Add($key)
            }
        }
    }
    $detail = if ($removedKeys.Count) { $removedKeys -join ', ' } else { $SettingsPath }
    New-DevEnvResult 'VSCode settings' (ConvertTo-RemovalStatus $status) $detail

    if ($SkipExtensions) { return }
    if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
        return New-DevEnvResult 'VSCode theme' NotFound "The 'code' command was not found; add VS Code to PATH"
    }
    $theme = Get-ThemeInfo
    $installedIds = code --list-extensions | ForEach-Object { $_.Trim() }
    if ($theme.Id -notin $installedIds) {
        New-DevEnvResult 'VSCode theme' NotInstalled $theme.Id
    }
    elseif (-not $PSCmdlet.ShouldProcess($theme.Id, 'Uninstall VS Code theme')) {
        New-DevEnvResult 'VSCode theme' WouldRemove $theme.Id
    }
    else {
        code --uninstall-extension $theme.Id | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Uninstalling the theme failed (code exit code $LASTEXITCODE)" }
        New-DevEnvResult 'VSCode theme' Removed $theme.Id
    }
    New-DevEnvResult 'VSCode extensions' Skipped 'Extensions are left installed'
}
