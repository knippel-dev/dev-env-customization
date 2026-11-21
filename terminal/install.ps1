# Adds the manifest's color scheme to Windows Terminal and makes it and the manifest's Nerd Font the
# defaults for all profiles. Settings are merged, so anything else is left alone.
# Run with:  & "$HOME\code\dev-env-customization\terminal\install.ps1"
param(
    # Windows Terminal's settings file; found automatically when not given
    [string]$SettingsPath,
    # Personal manifest to merge over manifests/default.psd1
    [string]$Manifest
)
$ErrorActionPreference = 'Stop'
foreach ($helper in Get-ChildItem "$PSScriptRoot\..\DevEnv\Private\*.ps1") { . $helper.FullName }

$config = Get-DevEnvManifest $Manifest
$fontFace = $config.Font.Face
# Sorted so the scheme is written in the same order every time
$scheme = [ordered]@{}
foreach ($key in $config.Terminal.ColorScheme.Keys | Sort-Object) { $scheme[$key] = $config.Terminal.ColorScheme[$key] }

if (-not $SettingsPath) {
    $candidates = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"  # Store / built in
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"                                     # unpackaged
    )
    $SettingsPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $SettingsPath) {
        # Windows Terminal writes its settings file the first time it starts
        $packageDir = Split-Path -Parent (Split-Path -Parent $candidates[0])
        if (-not (Test-Path -LiteralPath $packageDir)) {
            Write-Warning 'Windows Terminal was not found, so its settings were not changed.'
            return
        }
        $SettingsPath = $candidates[0]
    }
}

$changed = Update-JsonSettingsFile -Path $SettingsPath -Update {
    param($settings)
    # Replace any scheme with the same name so changes to the manifest's scheme are picked up
    $schemes = @($settings['schemes'] | Where-Object { $_ -and $_['name'] -ne $scheme['name'] })
    $settings['schemes'] = @($schemes) + $scheme

    if (-not $settings['profiles']) { $settings['profiles'] = [ordered]@{} }
    # profiles can also be a plain list of profiles (older settings format)
    if ($settings['profiles'] -is [array]) { $settings['profiles'] = [ordered]@{ list = $settings['profiles'] } }
    if (-not $settings['profiles']['defaults']) { $settings['profiles']['defaults'] = [ordered]@{} }
    $defaults = $settings['profiles']['defaults']
    if (-not $defaults['font']) { $defaults['font'] = [ordered]@{} }
    $defaults['font']['face'] = $fontFace
    $defaults['colorScheme'] = $scheme['name']
}

if ($changed) {
    Write-Host "Windows Terminal now uses the '$($scheme['name'])' color scheme and '$fontFace' font by default"
}
else {
    Write-Host 'Windows Terminal settings already up to date'
}
