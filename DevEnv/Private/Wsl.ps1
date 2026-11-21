# Wsl component: adds a line to ~/.bashrc in WSL that loads bash/dualline-prompt.sh from this repo (through
# /mnt/c), so the bash prompt picks up changes to the repo like the PowerShell one does.

# Quotes a string for bash: 'it'\''s'
function ConvertTo-BashLiteral([string]$Value) {
    "'" + $Value.Replace("'", "'\''") + "'"
}

# The WSL distribution to use: the manifest's Wsl.Distro, or the default one. Nothing when WSL isn't
# installed or has no distributions.
function Get-WslDistro([Collections.IDictionary]$Config) {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { return }
    # wsl.exe writes UTF-16 unless asked for UTF-8. Restored by assignment rather than Remove-Item, which
    # -WhatIf would skip.
    $previous = $env:WSL_UTF8
    $env:WSL_UTF8 = '1'
    try { $distros = @(wsl.exe --list --quiet 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
    finally { $env:WSL_UTF8 = $previous }
    if ($LASTEXITCODE -ne 0 -or -not $distros) { return }
    $wanted = $Config.Wsl.Distro
    if (-not $wanted) { return $distros[0] }   # the default distribution is listed first
    if ($wanted -in $distros) { return $wanted }
    throw "WSL distribution '$wanted' from the manifest is not installed (installed: $($distros -join ', '))"
}

# Converts a Windows path to the path WSL sees it at, like /mnt/c/Users/...
function ConvertTo-WslPath([string]$Distro, [string]$Path) {
    $linux = wsl.exe --distribution $Distro --exec wslpath -u $Path
    if ($LASTEXITCODE -ne 0 -or -not $linux) { throw "wslpath could not convert $Path" }
    "$linux".Trim()
}

# Runs a bash script in WSL and returns its exit code. The script goes through a temporary file, so nothing
# has to survive Windows command line quoting.
function Invoke-WslBash([string]$Distro, [string]$Script) {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "devenv-$([guid]::NewGuid().ToString('N')).sh"
    [IO.File]::WriteAllText($tmp, ($Script -replace "`r`n", "`n"))
    try {
        $linuxTmp = ConvertTo-WslPath $Distro $tmp
        wsl.exe --distribution $Distro --exec bash $linuxTmp | ForEach-Object { Write-Verbose $_ }
        $LASTEXITCODE
    }
    finally { Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue }
}

function Sync-DevEnvWsl {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary]$Config,
        # Only report what would change
        [switch]$Check
    )
    $distro = Get-WslDistro $Config
    if (-not $distro) { return New-DevEnvResult Wsl NotFound 'WSL is not installed or has no distributions' }

    # Any line mentioning the prompt counts, including one added by hand
    if ((Invoke-WslBash $distro 'grep -qsF dualline-prompt.sh ~/.bashrc') -eq 0) {
        return New-DevEnvResult Wsl UpToDate "~/.bashrc in $distro"
    }
    if ($Check -or -not $PSCmdlet.ShouldProcess("~/.bashrc in $distro", 'Add the prompt')) {
        return New-DevEnvResult Wsl NeedsUpdate "~/.bashrc in $distro doesn't load the prompt"
    }

    $promptScript = ConvertTo-WslPath $distro (Join-Path $script:RepoRoot 'bash\dualline-prompt.sh')
    $quoted = ConvertTo-BashLiteral $promptScript
    $lines = @("$script:PromptBlockHeader (added by DevEnv)", "[ -f $quoted ] && source $quoted")
    $exit = Invoke-WslBash $distro "printf '\n%s\n%s\n' $(($lines | ForEach-Object { ConvertTo-BashLiteral $_ }) -join ' ') >> ~/.bashrc"
    if ($exit -ne 0) { throw "Adding the prompt to ~/.bashrc in $distro failed (exit code $exit)" }
    New-DevEnvResult Wsl Updated "~/.bashrc in $distro"
}

# Removes the two lines Sync-DevEnvWsl added (and the blank line before them). A line loading the prompt
# that was added by hand is left alone.
function Remove-DevEnvWsl {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary]$Config
    )
    $distro = Get-WslDistro $Config
    if (-not $distro) { return New-DevEnvResult Wsl NotFound 'WSL is not installed or has no distributions' }
    $header = ConvertTo-BashLiteral $script:PromptBlockHeader

    # Exit codes: 0 found our block, 3 no prompt at all, 4 only a hand-added line
    $state = Invoke-WslBash $distro @"
grep -qsF -- $header ~/.bashrc && exit 0
grep -qsF dualline-prompt.sh ~/.bashrc && exit 4
exit 3
"@
    if ($state -eq 3) { return New-DevEnvResult Wsl NotInstalled "~/.bashrc in $distro" }
    if ($state -eq 4) { return New-DevEnvResult Wsl Skipped "~/.bashrc in $distro loads the prompt with a line not added by DevEnv; remove it by hand" }
    if ($state -ne 0) { throw "Checking ~/.bashrc in $distro failed (exit code $state)" }
    if (-not $PSCmdlet.ShouldProcess("~/.bashrc in $distro", 'Remove the prompt')) {
        return New-DevEnvResult Wsl WouldRemove "~/.bashrc in $distro"
    }

    # Blank lines are held back one line, so the one just before our header can be dropped with it.
    # Written back with cat rather than mv, so a ~/.bashrc that's a symlink (like into a dotfiles repo) stays one.
    $exit = Invoke-WslBash $distro @"
set -e
cp ~/.bashrc ~/.bashrc.bak
awk -v h=$header '
    index(`$0, h) == 1 { skip = 1; held = 0; next }
    skip { skip = 0; next }
    { if (held) print ""; held = 0 }
    `$0 == "" { held = 1; next }
    { print }
    END { if (held) print "" }
' ~/.bashrc.bak > ~/.bashrc.devenv-tmp
cat ~/.bashrc.devenv-tmp > ~/.bashrc
rm ~/.bashrc.devenv-tmp
"@
    if ($exit -ne 0) { throw "Removing the prompt from ~/.bashrc in $distro failed (exit code $exit)" }
    New-DevEnvResult Wsl Removed "~/.bashrc in $distro (backup: ~/.bashrc.bak)"
}
