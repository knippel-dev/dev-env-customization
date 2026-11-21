# Checks on the repo itself: files that must stay compatible, and things that must stay in sync.
# Variables set in BeforeAll are used in the It blocks, which the analyzer can't see
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

BeforeAll {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $RepoRoot 'DevEnv') -Force
}

AfterAll {
    Remove-Module DevEnv -ErrorAction SilentlyContinue
}

Describe 'bootstrap.ps1' {
    It 'is plain ASCII, since Windows PowerShell 5.1 reads files without a BOM as ANSI' {
        $bytes = [IO.File]::ReadAllBytes((Join-Path $RepoRoot 'bootstrap.ps1'))
        @($bytes | Where-Object { $_ -gt 127 }).Count | Should -Be 0
    }

    It 'parses in Windows PowerShell 5.1' -Skip:(-not (Get-Command powershell.exe -ErrorAction SilentlyContinue)) {
        $path = Join-Path $RepoRoot 'bootstrap.ps1'
        $errors = powershell.exe -NoProfile -Command "`$e = `$null; [void][Management.Automation.Language.Parser]::ParseFile('$path', [ref]`$null, [ref]`$e); `$e.Count"
        $errors | Should -Be '0'
    }
}

Describe 'PowerShell files' {
    It '<Name> parses' -ForEach @(
        Get-ChildItem (Split-Path -Parent $PSScriptRoot) -Recurse -Include *.ps1, *.psm1, *.psd1 |
            Where-Object { $_.FullName -notmatch '[\\/](plan|\.git)[\\/]' } |
            ForEach-Object { @{ Name = $_.Name; Path = $_.FullName } }
    ) {
        $errors = $null
        [void][Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }
}

Describe 'Shell scripts' {
    It '<Name> has LF line endings' -ForEach @(
        Get-ChildItem (Join-Path (Split-Path -Parent $PSScriptRoot) 'bash') -Filter *.sh |
            ForEach-Object { @{ Name = $_.Name; Path = $_.FullName } }
    ) {
        [IO.File]::ReadAllText($Path) | Should -Not -Match "`r"
    }
}

Describe 'Default manifest' {
    BeforeAll {
        $manifest = Import-PowerShellDataFile (Join-Path $RepoRoot 'manifests\default.psd1')
    }

    It 'has every section the components read' {
        foreach ($section in 'Packages', 'Git', 'Wsl', 'Prompt', 'Font', 'Terminal', 'VSCode') {
            $manifest.Keys | Should -Contain $section
        }
    }

    It 'has a valid Prompt section' {
        InModuleScope DevEnv -Parameters @{ Prompt = $manifest.Prompt } {
            param($Prompt)
            # Throws, failing the test, if anything is wrong
            Test-PromptConfig $Prompt
        }
    }

    It 'loads in Windows PowerShell 5.1, which bootstrap runs on' -Skip:(-not (Get-Command powershell.exe -ErrorAction SilentlyContinue)) {
        $path = Join-Path $RepoRoot 'manifests\default.psd1'
        powershell.exe -NoProfile -Command "(Import-PowerShellDataFile '$path').Font.Name" | Should -Be $manifest.Font.Name
    }
}

Describe 'bash prompt defaults' {
    # bash uses its built-in values when Sync-DevEnv hasn't generated its config, so they must match the
    # config that would be generated from the default manifest
    BeforeAll {
        $bashScript = Get-Content (Join-Path $RepoRoot 'bash\dualline-prompt.sh') -Raw
        $generated = InModuleScope DevEnv -Parameters @{ Path = (Join-Path $RepoRoot 'manifests\default.psd1') } {
            param($Path)
            $files = Get-PromptConfigFile @{ Prompt = (Import-PowerShellDataFile $Path).Prompt }
            $files[$script:PromptConfigPaths.Bash]
        }
        $lines = $generated -split "`n" | Where-Object { $_ -and $_ -notmatch '^#' }
    }

    It 'match the default manifest: <_>' -ForEach @(
        'section0', 'section5', 'textlight', 'textdark', 'frame', 'chevron', 'error'
    ) {
        $key = $_
        $line = $lines | Where-Object { $_.StartsWith("_dl_palette[$key]=") }
        $line | Should -Not -BeNullOrEmpty
        $bashScript | Should -Match ([regex]::Escape("[$key]=" + ($line -split '=', 2)[1]))
    }

    It 'match the default manifest: segments, path length and time format' {
        foreach ($name in '_dl_segments', '_dl_vscode_segments', '_dl_dir_truncation_length', '_dl_time_format') {
            $line = $lines | Where-Object { $_ -like "$name=*" }
            $bashScript | Should -Match ("(?m)^" + [regex]::Escape($line) + '$')
        }
    }
}

Describe 'Module' {
    It 'exports the four commands' {
        (Get-Command -Module DevEnv).Name | Sort-Object | Should -Be @('Get-DevEnv', 'Install-DevEnv', 'Sync-DevEnv', 'Uninstall-DevEnv')
    }

    It 'has the version of the latest release in CHANGELOG.md' {
        $version = (Import-PowerShellDataFile (Join-Path $RepoRoot 'DevEnv\DevEnv.psd1')).ModuleVersion
        $latest = Select-String -Path (Join-Path $RepoRoot 'CHANGELOG.md') -Pattern '^## \[(\d+\.\d+\.\d+)\]' |
            Select-Object -First 1
        $latest.Matches[0].Groups[1].Value | Should -Be $version
    }
}
