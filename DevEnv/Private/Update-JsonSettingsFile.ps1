# Reads a JSON settings file as an ordered hashtable, passes it to $Update to change in place, and writes
# it back only if something changed. Returns UpToDate, Updated, or NeedsUpdate (with -Check or -WhatIf).
# Rewriting the file drops comments and trailing commas, so the original is kept as <file>.bak.
function Update-JsonSettingsFile {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        # Called with the settings hashtable as its only argument
        [Parameter(Mandatory)]
        [scriptblock]$Update,
        # Only report whether the file would change
        [switch]$Check
    )
    $settings = if (Test-Path -LiteralPath $Path) {
        Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
    }
    if (-not $settings) { $settings = [ordered]@{} }

    $before = $settings | ConvertTo-Json -Depth 20 -Compress
    $null = & $Update $settings
    if (($settings | ConvertTo-Json -Depth 20 -Compress) -eq $before) { return 'UpToDate' }
    if ($Check -or -not $PSCmdlet.ShouldProcess($Path, 'Update settings')) { return 'NeedsUpdate' }

    if (Test-Path -LiteralPath $Path) {
        Copy-Item -LiteralPath $Path -Destination "$Path.bak" -Force
        Write-Verbose "Backed up $Path to $Path.bak"
    }
    else {
        New-Item -ItemType Directory -Force (Split-Path -Parent $Path) | Out-Null
    }
    Write-FileWithRetry -Path $Path -Value ($settings | ConvertTo-Json -Depth 20)
    'Updated'
}
