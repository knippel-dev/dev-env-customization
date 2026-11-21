# Applies the manifest's VS Code settings, installs the Dualline Dark theme from vscode/theme and
# installs the manifest's extensions. Settings are merged, so any other settings you have are left alone.
# Run with:  & "$HOME\code\dev-env-customization\vscode\install.ps1"
param(
    # VS Code's user settings file to merge into
    [string]$SettingsPath = "$env:APPDATA\Code\User\settings.json",
    # Skips installing the theme and extensions, so only settings are applied
    [switch]$SkipExtensions,
    # Personal manifest to merge over manifests/default.psd1
    [string]$Manifest
)
$ErrorActionPreference = 'Stop'
foreach ($helper in Get-ChildItem "$PSScriptRoot\..\DevEnv\Private\*.ps1") { . $helper.FullName }

$config = Get-DevEnvManifest $Manifest

# The editor font is a CSS font list, so the name is quoted; the terminal font is a plain name
$fontSettings = @{
    'editor.fontFamily'              = "'$($config.Font.Face)'"
    'terminal.integrated.fontFamily' = $config.Font.Face
}
$manifestSettings = Merge-Hashtable $fontSettings $config.VSCode.Settings
# Sorted so new settings are added in the same order every time
$wantedSettings = [ordered]@{}
foreach ($key in $manifestSettings.Keys | Sort-Object) { $wantedSettings[$key] = $manifestSettings[$key] }

$changedKeys = [Collections.Generic.List[string]]::new()
$changed = Update-JsonSettingsFile -Path $SettingsPath -Update {
    param($settings)
    foreach ($key in $wantedSettings.Keys) {
        $new = $wantedSettings[$key]
        # Compare as JSON so nested settings (like color customizations) are compared by content
        $same = $settings.Contains($key) -and
            ($settings[$key] | ConvertTo-Json -Depth 20 -Compress) -eq ($new | ConvertTo-Json -Depth 20 -Compress)
        if (-not $same) {
            $settings[$key] = $new
            $changedKeys.Add($key)
        }
    }
}

if ($changed) { Write-Host "Updated settings: $($changedKeys -join ', ')" }
else { Write-Host 'Settings already up to date' }

if ($SkipExtensions) { return }

if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    Write-Warning "The 'code' command was not found, so extensions were not installed. Add VS Code to PATH and run again."
    return
}

# Packages vscode/theme as a .vsix (a zip with a manifest) so it can be installed without Node or vsce
function New-ThemeVsix([string]$themeDir, [string]$vsixPath) {
    $pkg = Get-Content -LiteralPath "$themeDir\package.json" -Raw | ConvertFrom-Json
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
    if (Test-Path -LiteralPath $vsixPath) { Remove-Item -LiteralPath $vsixPath }
    $zip = [IO.Compression.ZipFile]::Open($vsixPath, 'Create')
    try {
        foreach ($entry in @{ 'extension.vsixmanifest' = $manifest; '[Content_Types].xml' = $contentTypes }.GetEnumerator()) {
            $writer = [IO.StreamWriter]::new($zip.CreateEntry($entry.Key).Open())
            $writer.Write($entry.Value); $writer.Dispose()
        }
        foreach ($file in Get-ChildItem -LiteralPath $themeDir -Recurse -File) {
            $relative = [IO.Path]::GetRelativePath($themeDir, $file.FullName).Replace('\', '/')
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, "extension/$relative") | Out-Null
        }
    }
    finally { $zip.Dispose() }
    "$($pkg.publisher).$($pkg.name)@$($pkg.version)"
}

$installed = code --list-extensions --show-versions
$vsix = Join-Path ([IO.Path]::GetTempPath()) 'dualline-theme.vsix'
$theme = New-ThemeVsix "$PSScriptRoot\theme" $vsix
# Reinstall when the theme file changed, even if the version in package.json wasn't bumped
$themeFile = 'themes\dualline-dark-color-theme.json'
$installedFile = Join-Path "$HOME\.vscode\extensions\$($theme.Replace('@', '-'))" $themeFile
$themeChanged = -not (Test-Path -LiteralPath $installedFile) -or
    (Get-FileHash -LiteralPath $installedFile).Hash -ne (Get-FileHash -LiteralPath "$PSScriptRoot\theme\$themeFile").Hash
if ($theme -in $installed -and -not $themeChanged) {
    Write-Host 'Theme already installed'
}
else {
    Write-Host "Installing theme $theme"
    code --install-extension $vsix --force | Out-Null
}
Remove-Item -LiteralPath $vsix

$installed = $installed | ForEach-Object { ($_ -split '@')[0] }
$missing = $config.VSCode.Extensions | Where-Object { $_ -notin $installed }

foreach ($ext in $missing) {
    Write-Host "Installing $ext"
    code --install-extension $ext | Out-Null
}
if (-not $missing) { Write-Host 'Extensions already installed' }
