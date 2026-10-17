# Dual-line prompt in plain PowerShell.
# Load it from your profile with:  . "C:\code\dev-env-customization\powershell\dualline-prompt.ps1"
# For the VS Code integrated terminal use:  . "...\dualline-prompt.ps1" -Variant VSCode
# Needs a Nerd Font in the terminal.
param(
    # VSCode moves the docker segment one section to the right
    [ValidateSet('Default', 'VSCode')]
    [string]$Variant = 'Default'
)
$script:PromptVariant = $Variant

### COLOR SCHEME ###
$script:PromptPalette = @{
    section0  = '#061621'
    section1  = '#0B293D'
    section2  = '#22577A'
    section3  = '#38A3A5'
    section4  = '#57CC99'
    section5  = '#80ED99'
    textlight = '#80ED99'
    textdark  = '#000000'
}

### SETTINGS ###
$script:PromptDirTruncationLength = 3
$script:PromptDirTruncationSymbol = [char]0x2026 + '\'   # …\
$script:PromptTimeFormat = 'HH:mm'

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

function script:Fg([string]$name) {
    $hex = $PromptPalette[$name]
    $r = [Convert]::ToInt32($hex.Substring(1, 2), 16)
    $g = [Convert]::ToInt32($hex.Substring(3, 2), 16)
    $b = [Convert]::ToInt32($hex.Substring(5, 2), 16)
    "$Esc[38;2;$r;$g;${b}m"
}

function script:Bg([string]$name) {
    $hex = $PromptPalette[$name]
    $r = [Convert]::ToInt32($hex.Substring(1, 2), 16)
    $g = [Convert]::ToInt32($hex.Substring(3, 2), 16)
    $b = [Convert]::ToInt32($hex.Substring(5, 2), 16)
    "$Esc[48;2;$r;$g;${b}m"
}

$script:Bold = "$Esc[1m"
$script:Red = "$Esc[31m"
$script:White = "$Esc[37m"

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
    $conflicted = $deleted = $renamed = $modified = $typechanged = $staged = $untracked = $false
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
                if ($x -eq 'T' -or $y -eq 'T') { $typechanged = $true }
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
    if ($typechanged) { $status += '' }
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
    $lastExit = $global:LASTEXITCODE
    $G = $script:Glyph

    $loc = $ExecutionContext.SessionState.Path.CurrentLocation
    $path = if ($loc.Provider.Name -eq 'FileSystem') { $loc.ProviderPath } else { $loc.Path }
    $gitRoot = if ($loc.Provider.Name -eq 'FileSystem') { Get-GitRoot $path } else { $null }

    $osSymbol = if ($IsLinux) { $G.Linux } else { $G.Windows }
    $isAdmin = $IsWindows -and ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $showUser = $isAdmin -or $env:SSH_CONNECTION

    $sb = [Text.StringBuilder]::new()

    # Line 1
    [void]$sb.Append((Fg section2) + $G.TopLeft)
    [void]$sb.Append((Fg section0) + $G.LeftCap)
    [void]$sb.Append($Bold + (Bg section0) + $White + "$osSymbol  " + $Reset)
    if ($showUser) {
        # Elevated shells show "Administrator" rather than the account name
        $userStyle = if ($isAdmin) { $Bold + (Bg section0) + $Red } else { (Fg textlight) + (Bg section0) }
        $userName = if ($isAdmin) { 'Administrator' } else { [Environment]::UserName }
        [void]$sb.Append($userStyle + "$userName " + $Reset)
    }

    [void]$sb.Append((Bg section1) + (Fg section0) + $G.Arrow)
    [void]$sb.Append($Bold + (Fg textlight) + " $(Get-PromptDirectory $path $gitRoot) " + $Reset)

    [void]$sb.Append((Bg section2) + (Fg section1) + $G.Arrow)
    if ($gitRoot) {
        $git = Get-PromptGit $gitRoot
        if ($git) {
            [void]$sb.Append($Bold + (Fg textdark) + " $($G.Branch) $($git.Branch) ")
            [void]$sb.Append($Red + "$($git.Status) " + $Reset)
        }
    }

    $docker = if ($loc.Provider.Name -eq 'FileSystem') { Get-PromptDockerContext $path } else { $null }
    $dockerSegment = if ($docker) { $Bold + (Bg section4) + (Fg textdark) + " $($G.Docker) $docker " + $Reset } else { '' }

    [void]$sb.Append((Bg section3) + (Fg section2) + $G.Arrow)
    if ($PromptVariant -eq 'Default') { [void]$sb.Append($dockerSegment) }
    [void]$sb.Append((Bg section4) + (Fg section3) + $G.Arrow)
    if ($PromptVariant -eq 'VSCode') { [void]$sb.Append($dockerSegment) }
    [void]$sb.Append((Bg section5) + (Fg section4) + $G.Arrow)
    [void]$sb.Append($Bold + (Fg textdark) + " $($G.Clock) $(Get-Date -Format $PromptTimeFormat) " + $Reset)
    [void]$sb.Append((Fg section5) + $G.RightCap + $Reset)

    # Line 2
    [void]$sb.Append("`n" + (Fg section2) + $G.BotLeft)
    [void]$sb.Append($Bold + (Fg section5) + "$($G.Chevron) " + $Reset)

    $global:LASTEXITCODE = $lastExit
    $sb.ToString()
}
