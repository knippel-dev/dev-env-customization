# Prompt component: adds a block to the PowerShell 7 'Current User, All Hosts' profile that loads
# powershell/dualline-prompt.ps1, using the VSCode variant inside the VS Code integrated terminal.

$script:PromptBlockHeader = '# Dual line prompt from dev-env-customization'

function Sync-DevEnvPrompt {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary]$Config,
        [string]$ProfilePath = $PROFILE.CurrentUserAllHosts,
        # Only report what would change
        [switch]$Check
    )
    if ((Test-Path -LiteralPath $ProfilePath) -and
        (Select-String -LiteralPath $ProfilePath -Pattern 'dualline-prompt\.ps1' -Quiet)) {
        return New-DevEnvResult Prompt UpToDate $ProfilePath
    }
    if ($Check -or -not $PSCmdlet.ShouldProcess($ProfilePath, 'Add the prompt to the profile')) {
        return New-DevEnvResult Prompt NeedsUpdate "$ProfilePath doesn't load the prompt"
    }

    # Write the path relative to $HOME when possible, so a profile synced to another machine (for example
    # through OneDrive) still works there
    $promptScript = Join-Path $script:RepoRoot 'powershell\dualline-prompt.ps1'
    $pathText = if ($promptScript.StartsWith("$HOME\", [StringComparison]::OrdinalIgnoreCase)) {
        '$HOME' + $promptScript.Substring($HOME.Length)
    }
    else { $promptScript }

    $block = @"

$script:PromptBlockHeader (added by DevEnv)
`$devEnvPrompt = "$pathText"
if (Test-Path -LiteralPath `$devEnvPrompt) {
    . `$devEnvPrompt -Variant `$(if (`$env:TERM_PROGRAM -eq 'vscode') { 'VSCode' } else { 'Default' })
}
Remove-Variable devEnvPrompt
"@

    New-Item -ItemType Directory -Force (Split-Path -Parent $ProfilePath) | Out-Null
    Add-Content -LiteralPath $ProfilePath -Value $block -Encoding utf8NoBOM
    New-DevEnvResult Prompt Updated $ProfilePath
}

# Removes the block Sync-DevEnvPrompt added. A line loading the prompt that was added by hand is left alone.
function Remove-DevEnvPrompt {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary]$Config,
        [string]$ProfilePath = $PROFILE.CurrentUserAllHosts
    )
    $text = if (Test-Path -LiteralPath $ProfilePath) { Get-Content -LiteralPath $ProfilePath -Raw }
    if (-not $text) { return New-DevEnvResult Prompt NotInstalled $ProfilePath }

    # From the header comment (and the blank line before it) to the closing Remove-Variable line
    $pattern = '(?ms)(\r?\n)?^' + [regex]::Escape($script:PromptBlockHeader) + '.*?^Remove-Variable devEnvPrompt[^\r\n]*(\r?\n)?'
    $newText = [regex]::Replace($text, $pattern, '')
    $byHand = 'loads the prompt with a line not added by DevEnv; remove it by hand'

    if ($newText -eq $text) {
        if ($text -match 'dualline-prompt\.ps1') { return New-DevEnvResult Prompt Skipped "$ProfilePath $byHand" }
        return New-DevEnvResult Prompt NotInstalled $ProfilePath
    }
    if (-not $PSCmdlet.ShouldProcess($ProfilePath, 'Remove the prompt from the profile')) {
        return New-DevEnvResult Prompt WouldRemove $ProfilePath
    }

    Copy-Item -LiteralPath $ProfilePath -Destination "$ProfilePath.bak" -Force
    Write-Verbose "Backed up $ProfilePath to $ProfilePath.bak"
    Write-FileWithRetry -Path $ProfilePath -Value $newText -NoNewline
    if ($newText -match 'dualline-prompt\.ps1') { Write-Warning "$ProfilePath still $byHand" }
    New-DevEnvResult Prompt Removed $ProfilePath
}
