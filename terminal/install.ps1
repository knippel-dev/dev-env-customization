# Adds the color scheme in terminal/custom-color-scheme.json to Windows Terminal and makes it and the
# Nerd Font the defaults for all profiles. Settings are merged, so anything else is left alone.
# Run with:  & "$HOME\code\dev-env-customization\terminal\install.ps1"
param(
    # Windows Terminal's settings file; found automatically when not given
    [string]$SettingsPath,
    [string]$FontFace = 'IosevkaTerm Nerd Font'
)
$ErrorActionPreference = 'Stop'

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

$scheme = Get-Content -LiteralPath "$PSScriptRoot\custom-color-scheme.json" -Raw | ConvertFrom-Json -AsHashtable

$settings = if (Test-Path -LiteralPath $SettingsPath) {
    Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json -AsHashtable
}
if (-not $settings) { $settings = [ordered]@{} }
$before = $settings | ConvertTo-Json -Depth 20 -Compress

# Replace any scheme with the same name so changes to the repo's scheme are picked up
$schemes = @($settings['schemes'] | Where-Object { $_ -and $_['name'] -ne $scheme['name'] })
$settings['schemes'] = @($schemes) + $scheme

if (-not $settings['profiles']) { $settings['profiles'] = [ordered]@{} }
# profiles can also be a plain list of profiles (older settings format)
if ($settings['profiles'] -is [array]) { $settings['profiles'] = [ordered]@{ list = $settings['profiles'] } }
if (-not $settings['profiles']['defaults']) { $settings['profiles']['defaults'] = [ordered]@{} }
$defaults = $settings['profiles']['defaults']
if (-not $defaults['font']) { $defaults['font'] = [ordered]@{} }
$defaults['font']['face'] = $FontFace
$defaults['colorScheme'] = $scheme['name']

$json = $settings | ConvertTo-Json -Depth 20
if (($settings | ConvertTo-Json -Depth 20 -Compress) -eq $before) {
    Write-Host 'Windows Terminal settings already up to date'
    return
}

# Rewriting the file drops comments, so keep a backup of the original
if (Test-Path -LiteralPath $SettingsPath) {
    Copy-Item -LiteralPath $SettingsPath -Destination "$SettingsPath.bak" -Force
    Write-Host "Backed up Windows Terminal settings to $SettingsPath.bak"
}
else {
    New-Item -ItemType Directory -Force (Split-Path -Parent $SettingsPath) | Out-Null
}
# Windows Terminal can hold the file briefly while it reloads it, so retry a few times before giving up
for ($attempt = 1; ; $attempt++) {
    try { Set-Content -LiteralPath $SettingsPath -Value $json -Encoding utf8NoBOM -ErrorAction Stop; break }
    catch [IO.IOException] {
        if ($attempt -ge 5) { throw }
        Start-Sleep -Milliseconds 500
    }
}
Write-Host "Windows Terminal now uses the '$($scheme['name'])' color scheme and '$FontFace' font by default"
