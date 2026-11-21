# Dual-line prompt in plain PowerShell.
# Load it from your profile with:  . "C:\code\dev-env-customization\powershell\dualline-prompt.ps1"
# For the VS Code integrated terminal use:  . "...\dualline-prompt.ps1" -Variant VSCode
# Needs a Nerd Font in the terminal.
#
# The palette, segments, path length and time format come from the Prompt section of the manifest:
# dualline-prompt.config.psd1 next to this script, which Sync-DevEnv generates from your manifest, or
# manifests/default.psd1 in the repo when that hasn't been generated.
param(
    # VSCode uses the manifest's VSCodeSegments (by default, the docker segment one section to the right)
    [ValidateSet('Default', 'VSCode')]
    [string]$Variant = 'Default'
)

### SETTINGS ###
$promptConfigFile = Join-Path $PSScriptRoot 'dualline-prompt.config.psd1'
$promptConfig = if (Test-Path -LiteralPath $promptConfigFile) {
    Import-PowerShellDataFile -LiteralPath $promptConfigFile
}
else {
    (Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot '..\manifests\default.psd1')).Prompt
}
$script:PromptPalette = $promptConfig.Palette
$script:PromptSegments = @(if ($Variant -eq 'VSCode' -and $promptConfig.VSCodeSegments) { $promptConfig.VSCodeSegments } else { $promptConfig.Segments })
$script:PromptDirTruncationLength = [int]$promptConfig.DirTruncationLength
$script:PromptTimeFormat = $promptConfig.TimeFormat
$script:PromptDirTruncationSymbol = [char]0x2026 + '\'   # …\
Remove-Variable promptConfigFile, promptConfig

### GLYPHS ###
$script:Glyph = @{
    LeftCap   = [char]0xE0B6
    Arrow     = [char]0xE0B0
    RightCap  = [char]0xE0B4
    Chevron   = [char]0xF054
    Windows   = [char]0xF17A
    Linux     = [char]::ConvertFromUtf32(0xF033D)
    Branch    = [char]0xF418
    Docker    = [char]0xF308
    Clock     = [char]0xF4AB
    TopLeft   = [char]0x250C
    BotLeft   = [char]0x2514
}

$script:Esc = [char]27
$script:Reset = "$Esc[0m"

# Escape sequences for each palette color, built once here instead of on every prompt
$script:PromptFg = @{}
$script:PromptBg = @{}
foreach ($name in $PromptPalette.Keys) {
    $hex = $PromptPalette[$name]
    $rgb = '{0};{1};{2}' -f [Convert]::ToInt32($hex.Substring(1, 2), 16),
        [Convert]::ToInt32($hex.Substring(3, 2), 16),
        [Convert]::ToInt32($hex.Substring(5, 2), 16)
    $script:PromptFg[$name] = "$Esc[38;2;${rgb}m"
    $script:PromptBg[$name] = "$Esc[48;2;${rgb}m"
}
Remove-Variable name, hex, rgb

$script:Bold = "$Esc[1m"
$script:Red = "$Esc[31m"
$script:White = "$Esc[37m"

# These can't change during a session, so work them out once
$script:PromptOsSymbol = if ($IsLinux) { $Glyph.Linux } else { $Glyph.Windows }
$script:PromptIsAdmin = $IsWindows -and ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$script:PromptShowUser = $PromptIsAdmin -or [bool]$env:SSH_CONNECTION

# Walk up from the current directory looking for .git, so we only spawn git inside repos.
function script:Get-GitRoot([string]$path) {
    $dir = $path
    while ($dir) {
        if (Test-Path -LiteralPath (Join-Path $dir '.git')) { return $dir }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    $null
}

function script:Get-PromptDirectory([string]$path, [string]$gitRoot) {
    $sep = [IO.Path]::DirectorySeparatorChar
    $truncated = $false

    if ($gitRoot) {
        # Like Starship's truncate_to_repo: show the path starting at the repo folder.
        $repoParent = Split-Path -Parent $gitRoot
        $display = if ($repoParent) { $path.Substring($repoParent.TrimEnd($sep).Length).TrimStart($sep) } else { $path }
        $truncated = [bool]$repoParent -and $repoParent -ne $HOME
    }
    elseif ($path -eq $HOME -or $path.StartsWith($HOME + $sep, [StringComparison]::OrdinalIgnoreCase)) {
        $display = '~' + $path.Substring($HOME.Length)
    }
    else {
        $display = $path
    }

    $parts = $display.TrimEnd($sep) -split [regex]::Escape($sep) | Where-Object { $_ }
    if ($parts.Count -gt $PromptDirTruncationLength) {
        $parts = $parts[-$PromptDirTruncationLength..-1]
        $truncated = $true
    }
    $joined = $parts -join $sep
    if ($truncated) { $PromptDirTruncationSymbol + $joined } else { $joined }
}

function script:Get-PromptGit([string]$gitRoot) {
    $lines = git --no-optional-locks status --porcelain=2 --branch 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }

    $branch = ''; $ahead = 0; $behind = 0
    $conflicted = $deleted = $renamed = $modified = $staged = $untracked = $false
    foreach ($line in $lines) {
        switch -Regex ($line) {
            '^# branch\.head (.+)$' { $branch = if ($Matches[1] -eq '(detached)') { 'HEAD' } else { $Matches[1] } }
            '^# branch\.ab \+(\d+) -(\d+)$' { $ahead = [int]$Matches[1]; $behind = [int]$Matches[2] }
            '^u ' { $conflicted = $true }
            '^\? ' { $untracked = $true }
            '^[12] (.)(.) ' {
                $x = $Matches[1]; $y = $Matches[2]
                if ($line[0] -eq '2') { $renamed = $true }
                if ($x -eq 'D' -or $y -eq 'D') { $deleted = $true }
                if ($y -eq 'M') { $modified = $true }
                if ($x -ne '.') { $staged = $true }
            }
        }
    }

    # Stash check without another git process; falls back to git for worktrees/submodules.
    $dotGit = Join-Path $gitRoot '.git'
    $stashed = if (Test-Path -LiteralPath $dotGit -PathType Container) {
        Test-Path -LiteralPath (Join-Path $dotGit 'logs\refs\stash')
    } else {
        [bool](git rev-parse --verify --quiet refs/stash 2>$null)
    }

    # Same order and default symbols as Starship's $all_status$ahead_behind.
    $status = ''
    if ($conflicted)  { $status += '=' }
    if ($stashed)     { $status += '$' }
    if ($deleted)     { $status += [char]0x2718 }   # ✘
    if ($renamed)     { $status += [char]0x00BB }   # »
    if ($modified)    { $status += '!' }
    if ($staged)      { $status += '+' }
    if ($untracked)   { $status += '?' }
    if ($ahead -gt 0 -and $behind -gt 0) { $status += [char]0x21D5 }  # ⇕
    elseif ($ahead -gt 0)  { $status += [char]0x21E1 }               # ⇡
    elseif ($behind -gt 0) { $status += [char]0x21E3 }               # ⇣

    [pscustomobject]@{ Branch = $branch; Status = $status }
}

# Starship's docker_context: only in folders with Docker files, and never for the "default" context.
function script:Get-PromptDockerContext([string]$path) {
    $files = 'docker-compose.yml', 'docker-compose.yaml', 'compose.yml', 'compose.yaml', 'Dockerfile'
    if (-not ($files | Where-Object { Test-Path -LiteralPath (Join-Path $path $_) })) { return $null }

    $context = if ($env:DOCKER_MACHINE_NAME) { $env:DOCKER_MACHINE_NAME }
    elseif ($env:DOCKER_HOST) { $env:DOCKER_HOST }
    elseif ($env:DOCKER_CONTEXT) { $env:DOCKER_CONTEXT }
    else {
        $configDir = if ($env:DOCKER_CONFIG) { $env:DOCKER_CONFIG } else { Join-Path $HOME '.docker' }
        $configFile = Join-Path $configDir 'config.json'
        if (Test-Path -LiteralPath $configFile) {
            try { (Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json).currentContext } catch { $null }
        }
    }
    if ($context -and $context -ne 'default') { $context } else { $null }
}

function global:prompt {
    # Must come first: whether the command before this prompt succeeded
    $lastSucceeded = $?
    $lastExit = $global:LASTEXITCODE
    $G = $script:Glyph

    $loc = $ExecutionContext.SessionState.Path.CurrentLocation
    $isFileSystem = $loc.Provider.Name -eq 'FileSystem'
    $path = if ($isFileSystem) { $loc.ProviderPath } else { $loc.Path }
    $gitRoot = if ($isFileSystem) { Get-GitRoot $path } else { $null }

    $sb = [Text.StringBuilder]::new()

    # Line 1: each segment sits on the next section color, joined by arrows
    [void]$sb.Append($PromptFg.frame + $G.TopLeft)
    for ($i = 0; $i -lt $PromptSegments.Count; $i++) {
        $bg = $PromptBg["section$i"]
        if ($i -eq 0) {
            [void]$sb.Append($PromptFg.section0 + $G.LeftCap)
            # The cap only sets the foreground, so start the first section's background (os sets its own)
            if ($PromptSegments[0] -ne 'os') { [void]$sb.Append($bg) }
        }
        else { [void]$sb.Append($bg + $PromptFg["section$($i - 1)"] + $G.Arrow) }

        switch ($PromptSegments[$i]) {
            'os' {
                [void]$sb.Append($Bold + $bg + $White + "$PromptOsSymbol  " + $Reset)
                if ($PromptShowUser) {
                    # Elevated shells show "Administrator" rather than the account name
                    $userStyle = if ($PromptIsAdmin) { $Bold + $bg + $Red } else { $PromptFg.textlight + $bg }
                    $userName = if ($PromptIsAdmin) { 'Administrator' } else { [Environment]::UserName }
                    [void]$sb.Append($userStyle + "$userName " + $Reset)
                }
            }
            'path' {
                [void]$sb.Append($Bold + $PromptFg.textlight + " $(Get-PromptDirectory $path $gitRoot) " + $Reset)
            }
            'git' {
                $git = if ($gitRoot) { Get-PromptGit $gitRoot }
                if ($git) {
                    [void]$sb.Append($Bold + $PromptFg.textdark + " $($G.Branch) $($git.Branch) ")
                    [void]$sb.Append($Red + "$($git.Status) " + $Reset)
                }
            }
            'docker' {
                $docker = if ($isFileSystem) { Get-PromptDockerContext $path }
                if ($docker) { [void]$sb.Append($Bold + $bg + $PromptFg.textdark + " $($G.Docker) $docker " + $Reset) }
            }
            'time' {
                [void]$sb.Append($Bold + $PromptFg.textdark + " $($G.Clock) $(Get-Date -Format $PromptTimeFormat) " + $Reset)
            }
            # 'gap' is an empty section
        }
    }
    [void]$sb.Append($PromptFg["section$($PromptSegments.Count - 1)"] + $G.RightCap + $Reset)

    # Line 2: the chevron turns to the error color after a failed command
    $chevron = if ($lastSucceeded) { $PromptFg.chevron } else { $PromptFg.error }
    [void]$sb.Append("`n" + $PromptFg.frame + $G.BotLeft)
    [void]$sb.Append($Bold + $chevron + "$($G.Chevron) " + $Reset)

    $global:LASTEXITCODE = $lastExit
    $sb.ToString()
}
