# Installs a Nerd Font for the current user (no admin needed) from the Nerd Fonts GitHub releases.
# Only the regular family is installed (not the Mono or Propo variants, whose icons are smaller).
# Run with:  & "$HOME\code\dev-env-customization\fonts\install.ps1"
param(
    # Name of the release zip at https://github.com/ryanoasis/nerd-fonts/releases, without .zip
    [string]$Font = 'IosevkaTerm'
)
$ErrorActionPreference = 'Stop'
# The progress bar makes Invoke-WebRequest much slower on large downloads
$ProgressPreference = 'SilentlyContinue'

$fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
$regPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
# Files in the zip look like IosevkaTermNerdFont-Bold.ttf, IosevkaTermNerdFontMono-Bold.ttf, ...
$pattern = "^$([regex]::Escape($Font))NerdFont-.+\.(ttf|otf)$"

$registered = (Get-Item -LiteralPath $regPath -ErrorAction SilentlyContinue).Property |
    Where-Object { $_ -match "^$([regex]::Escape($Font))NerdFont-" }
if ($registered) {
    Write-Host "$Font Nerd Font already installed"
    return
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) "nerd-font-$Font"
if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
New-Item -ItemType Directory -Force $tmp | Out-Null
try {
    Write-Host "Downloading $Font Nerd Font"
    $zip = Join-Path $tmp "$Font.zip"
    Invoke-WebRequest "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$Font.zip" -OutFile $zip
    Expand-Archive -LiteralPath $zip -DestinationPath $tmp

    $files = Get-ChildItem -LiteralPath $tmp -Recurse -File | Where-Object { $_.Name -match $pattern }
    if (-not $files) { throw "No font files matching $pattern were found in $Font.zip" }

    # Lets running apps see the new fonts without signing out
    Add-Type -Namespace DevEnv -Name FontApi -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern int AddFontResource(string file);
'@
    New-Item -ItemType Directory -Force $fontDir | Out-Null
    if (-not (Test-Path -LiteralPath $regPath)) { New-Item -Path $regPath -Force | Out-Null }
    foreach ($file in $files) {
        $dest = Join-Path $fontDir $file.Name
        Copy-Item -LiteralPath $file.FullName -Destination $dest -Force
        $type = if ($file.Extension -eq '.otf') { 'OpenType' } else { 'TrueType' }
        Set-ItemProperty -LiteralPath $regPath -Name "$($file.BaseName) ($type)" -Value $dest
        [DevEnv.FontApi]::AddFontResource($dest) | Out-Null
    }
    Write-Host "Installed $($files.Count) $Font Nerd Font files"
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
