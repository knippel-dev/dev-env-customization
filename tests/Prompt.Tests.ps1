# Renders the PowerShell and bash prompts in separate processes, from a copy of the scripts in a temporary
# folder, and checks the colors they use. bash runs in Git Bash.
# Variables set in BeforeAll are used in the It blocks, which the analyzer can't see
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

BeforeAll {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $RepoRoot 'DevEnv') -Force

    # A copy of the prompt scripts and the default manifest, without any generated config
    $copy = Join-Path $TestDrive 'repo'
    foreach ($folder in 'powershell', 'bash', 'manifests') {
        New-Item -ItemType Directory (Join-Path $copy $folder) | Out-Null
        Get-ChildItem (Join-Path $RepoRoot $folder) -File | Where-Object Name -notlike '*.config.*' |
            Copy-Item -Destination (Join-Path $copy $folder)
    }
    $plainDir = New-Item -ItemType Directory (Join-Path $TestDrive 'plain')
    $dockerDir = New-Item -ItemType Directory (Join-Path $TestDrive 'docker')
    New-Item -ItemType File (Join-Path $dockerDir 'Dockerfile') | Out-Null

    # Background escape codes of the default palette, by name
    $bg = @{
        section0 = '48;2;6;22;33m'; section1 = '48;2;11;41;61m'; section2 = '48;2;34;87;122m'
        section3 = '48;2;56;163;165m'; section4 = '48;2;87;204;153m'; section5 = '48;2;128;237;153m'
    }
    $chevronColor = '38;2;128;237;153m'
    $errorColor = '38;2;231;72;86m'
    $dockerBlock = '38;2;0;0;0m '   # dark text, then the docker icon
    # bash wraps escape codes in \[ \] so it can tell how wide the prompt is
    $bashDockerBlock = '38;2;0;0;0m\] '

    function Invoke-PowerShellPrompt([string]$Dir, [string]$Variant = 'Default', [switch]$Fail) {
        $failFirst = if ($Fail) { 'cmd /c exit 3; ' }
        $out = pwsh -NoProfile -Command ". '$copy\powershell\dualline-prompt.ps1' -Variant $Variant; Set-Location '$Dir'; $failFirst prompt"
        $lines = @($out)
        @{ Line1 = $lines[0]; Line2 = $lines[-1] }
    }

    $gitBash = 'C:\Program Files\Git\bin\bash.exe'
    function Invoke-BashPrompt([string]$Dir, [switch]$VSCode, [switch]$Fail) {
        $cygpath = 'C:\Program Files\Git\usr\bin\cygpath.exe'
        $script = & $cygpath -u "$copy\bash\dualline-prompt.sh"
        $folder = & $cygpath -u $Dir
        $previous = $env:TERM_PROGRAM
        $env:TERM_PROGRAM = if ($VSCode) { 'vscode' } else { $null }
        try {
            $failFirst = if ($Fail) { 'false; ' }
            $out = & $gitBash --noprofile --norc -c "source '$script'; cd '$folder'; ${failFirst}_dl_prompt; printf '%s' `"`$PS1`""
        }
        finally { $env:TERM_PROGRAM = $previous }
        $parts = ($out -join "`n") -split '\\n', 2
        @{ Line1 = $parts[0]; Line2 = $parts[1] }
    }

    function Get-Position([string]$Text, [string]$Code) { $Text.IndexOf($Code) }
}

AfterAll {
    Remove-Module DevEnv -ErrorAction SilentlyContinue
}

Describe 'PowerShell prompt' {
    It 'draws the segments on section0 to section5, in order' {
        $line = (Invoke-PowerShellPrompt $plainDir).Line1
        $positions = 0..5 | ForEach-Object { Get-Position $line $bg["section$_"] }
        $positions | Should -Not -Contain -1
        ($positions | Sort-Object) | Should -Be $positions
    }

    It 'uses the chevron color normally and the error color after a failed command' {
        $ok = Invoke-PowerShellPrompt $plainDir
        $failed = Invoke-PowerShellPrompt $plainDir -Fail
        $ok.Line2 | Should -Match ([regex]::Escape($chevronColor))
        $failed.Line2 | Should -Match ([regex]::Escape($errorColor))
        $failed.Line1 | Should -Be $ok.Line1
    }

    It 'puts docker on section3 by default and on section4 with -Variant VSCode' {
        $env:DOCKER_CONTEXT = 'test-context'
        try {
            (Invoke-PowerShellPrompt $dockerDir).Line1 | Should -Match ([regex]::Escape($bg.section3 + "`e[" + $dockerBlock))
            (Invoke-PowerShellPrompt $dockerDir -Variant VSCode).Line1 | Should -Match ([regex]::Escape($bg.section4 + "`e[" + $dockerBlock))
        }
        finally { Remove-Item Env:DOCKER_CONTEXT }
    }
}

Describe 'bash prompt' -Skip:(-not (Test-Path 'C:\Program Files\Git\bin\bash.exe')) {
    It 'draws the segments on section0 to section5, in order' {
        $line = (Invoke-BashPrompt $plainDir).Line1
        $positions = 0..5 | ForEach-Object { Get-Position $line $bg["section$_"] }
        $positions | Should -Not -Contain -1
        ($positions | Sort-Object) | Should -Be $positions
    }

    It 'uses the chevron color normally and the error color after a failed command' {
        (Invoke-BashPrompt $plainDir).Line2 | Should -Match ([regex]::Escape($chevronColor))
        (Invoke-BashPrompt $plainDir -Fail).Line2 | Should -Match ([regex]::Escape($errorColor))
    }

    It 'puts docker on section4 in the VS Code terminal' {
        $env:DOCKER_CONTEXT = 'test-context'
        try {
            (Invoke-BashPrompt $dockerDir).Line1 | Should -Match ([regex]::Escape($bg.section3) + '.{0,20}' + [regex]::Escape($bashDockerBlock))
            (Invoke-BashPrompt $dockerDir -VSCode).Line1 | Should -Match ([regex]::Escape($bg.section4) + '.{0,20}' + [regex]::Escape($bashDockerBlock))
        }
        finally { Remove-Item Env:DOCKER_CONTEXT }
    }
}

Describe 'Generated prompt config' {
    # A personal manifest with a red first section and only two segments, time first
    BeforeAll {
        $files = InModuleScope DevEnv {
            $config = Merge-Hashtable (Get-DevEnvManifest) @{
                Prompt = @{ Palette = @{ section0 = '#FF0000' }; Segments = @('time', 'path'); VSCodeSegments = @() }
            }
            Get-PromptConfigFile $config
        }
        $paths = InModuleScope DevEnv { $script:PromptConfigPaths }
        [IO.File]::WriteAllText("$copy\powershell\dualline-prompt.config.psd1", $files[$paths.PowerShell])
        [IO.File]::WriteAllText("$copy\bash\dualline-prompt.config.sh", $files[$paths.Bash])
        $red = '48;2;255;0;0m'
    }
    AfterAll {
        Remove-Item "$copy\powershell\dualline-prompt.config.psd1", "$copy\bash\dualline-prompt.config.sh"
    }

    It 'is used by the PowerShell prompt: two segments, the first on the red section0' {
        $line = (Invoke-PowerShellPrompt $plainDir).Line1
        $line | Should -Match ([regex]::Escape($red))
        ([regex]::Matches($line, '48;2;')).Count | Should -Be 2
    }

    It 'is used by the bash prompt: two segments, the first on the red section0' -Skip:(-not (Test-Path 'C:\Program Files\Git\bin\bash.exe')) {
        $line = (Invoke-BashPrompt $plainDir).Line1
        $line | Should -Match ([regex]::Escape($red))
        ([regex]::Matches($line, '48;2;')).Count | Should -Be 2
    }
}
