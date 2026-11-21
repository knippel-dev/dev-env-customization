# Terminal component: adds the manifest's color scheme to Windows Terminal and makes it and the Nerd Font
# the defaults for all profiles. Settings are merged, so anything else is left alone.

# Returns Windows Terminal's settings file, or nothing when Windows Terminal isn't installed
function Get-TerminalSettingsPath {
    $candidates = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"  # Store / built in
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"                                     # unpackaged
    )
    $existing = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($existing) { return $existing }
    # Windows Terminal writes its settings file the first time it starts
    $packageDir = Split-Path -Parent (Split-Path -Parent $candidates[0])
    if (Test-Path -LiteralPath $packageDir) { $candidates[0] }
}

# The manifest's color scheme, sorted so it's written in the same order every time
function Get-TerminalScheme([Collections.IDictionary]$Config) {
    $scheme = [ordered]@{}
    foreach ($key in $Config.Terminal.ColorScheme.Keys | Sort-Object) { $scheme[$key] = $Config.Terminal.ColorScheme[$key] }
    $scheme
}

function Sync-DevEnvTerminal {
    # -WhatIf flows through to Update-JsonSettingsFile, which calls ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Justification = 'Delegated to Update-JsonSettingsFile')]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary]$Config,
        # Windows Terminal's settings file; found automatically when not given
        [string]$SettingsPath,
        # Only report what would change
        [switch]$Check
    )
    if (-not $SettingsPath) { $SettingsPath = Get-TerminalSettingsPath }
    if (-not $SettingsPath) { return New-DevEnvResult Terminal NotFound 'Windows Terminal is not installed' }
    $scheme = Get-TerminalScheme $Config
    $fontFace = $Config.Font.Face

    $status = Update-JsonSettingsFile -Path $SettingsPath -Check:$Check -Update {
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
    New-DevEnvResult Terminal $status "'$($scheme['name'])' color scheme and '$fontFace' font in $SettingsPath"
}

# Removes the scheme, and the default color scheme and font where they're still the manifest's
function Remove-DevEnvTerminal {
    # -WhatIf flows through to Update-JsonSettingsFile, which calls ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Justification = 'Delegated to Update-JsonSettingsFile')]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary]$Config,
        [string]$SettingsPath
    )
    if (-not $SettingsPath) { $SettingsPath = Get-TerminalSettingsPath }
    if (-not $SettingsPath) { return New-DevEnvResult Terminal NotFound 'Windows Terminal is not installed' }
    $schemeName = $Config.Terminal.ColorScheme.name
    $fontFace = $Config.Font.Face

    $status = Update-JsonSettingsFile -Path $SettingsPath -Update {
        param($settings)
        if ($settings['schemes']) {
            $settings['schemes'] = @($settings['schemes'] | Where-Object { $_ -and $_['name'] -ne $schemeName })
        }
        $defaults = if ($settings['profiles'] -is [Collections.IDictionary]) { $settings['profiles']['defaults'] }
        if ($defaults) {
            if ($defaults['colorScheme'] -eq $schemeName) { $defaults.Remove('colorScheme') }
            if ($defaults['font'] -is [Collections.IDictionary] -and $defaults['font']['face'] -eq $fontFace) {
                $defaults['font'].Remove('face')
                if (-not $defaults['font'].Count) { $defaults.Remove('font') }
            }
        }
    }
    New-DevEnvResult Terminal (ConvertTo-RemovalStatus $status) "'$schemeName' color scheme and '$fontFace' font in $SettingsPath"
}
