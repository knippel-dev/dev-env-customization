# Tests for the DevEnv module's logic. Everything works on temporary files, a throwaway registry key and a
# temporary global git config, with winget and WSL replaced by mocks, so nothing on the machine changes.
# Variables set in BeforeAll are used in the It blocks, which the analyzer can't see
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

BeforeAll {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $RepoRoot 'DevEnv') -Force
    # An empty personal manifest, so one on this machine can't change the results
    $previousManifest = $env:DEVENV_MANIFEST
    $env:DEVENV_MANIFEST = Join-Path $TestDrive 'empty-manifest.psd1'
    '@{}' | Set-Content $env:DEVENV_MANIFEST
    $GitBash = 'C:\Program Files\Git\bin\bash.exe'
}

AfterAll {
    $env:DEVENV_MANIFEST = $previousManifest
    Remove-Module DevEnv -ErrorAction SilentlyContinue
}

Describe 'Manifest' {
    It 'loads the default manifest' {
        InModuleScope DevEnv {
            $manifest = Get-DevEnvManifest
            $manifest.Font.Name | Should -Be 'IosevkaTerm'
            $manifest.Prompt.Segments | Should -Contain 'path'
        }
    }

    It 'merges a personal manifest over the default, key by key' {
        $personal = Join-Path $TestDrive 'personal.psd1'
        "@{ Font = @{ Face = 'Other Face' }; VSCode = @{ Extensions = @('only.one') } }" | Set-Content $personal
        InModuleScope DevEnv -Parameters @{ Personal = $personal } {
            param($Personal)
            $manifest = Get-DevEnvManifest $Personal
            $manifest.Font.Face | Should -Be 'Other Face'
            $manifest.Font.Name | Should -Be 'IosevkaTerm'
            $manifest.VSCode.Extensions | Should -Be @('only.one')
        }
    }

    It 'prefers -Manifest over $env:DEVENV_MANIFEST' {
        $other = Join-Path $TestDrive 'other.psd1'
        '@{}' | Set-Content $other
        InModuleScope DevEnv -Parameters @{ Other = $other } {
            param($Other)
            Get-DevEnvManifestPath $Other | Should -Be $Other
            Get-DevEnvManifestPath | Should -Be $env:DEVENV_MANIFEST
        }
    }

    It 'fails clearly when the personal manifest is missing' {
        InModuleScope DevEnv {
            { Get-DevEnvManifest 'C:\no\such\manifest.psd1' } | Should -Throw 'Manifest not found*'
        }
    }
}

Describe 'Merge-Hashtable' {
    It 'merges nested hashtables and replaces other values, without changing its inputs' {
        InModuleScope DevEnv {
            $base = @{ A = @{ X = 1; Y = 2 }; List = @(1, 2); Keep = 'k' }
            $override = @{ A = @{ Y = 3 }; List = @(9) }
            $merged = Merge-Hashtable $base $override
            $merged.A.X | Should -Be 1
            $merged.A.Y | Should -Be 3
            $merged.List | Should -Be @(9)
            $merged.Keep | Should -Be 'k'
            $base.A.Y | Should -Be 2
        }
    }
}

Describe 'Update-JsonSettingsFile' {
    It 'creates a missing file, then reports UpToDate without rewriting it' {
        $path = Join-Path $TestDrive 'new\settings.json'
        InModuleScope DevEnv -Parameters @{ Path = $path } {
            param($Path)
            Update-JsonSettingsFile -Path $Path -Update { param($s) $s['a'] = 1 } | Should -Be 'Updated'
            $written = (Get-Item $Path).LastWriteTimeUtc
            Update-JsonSettingsFile -Path $Path -Update { param($s) $s['a'] = 1 } | Should -Be 'UpToDate'
            (Get-Item $Path).LastWriteTimeUtc | Should -Be $written
            Test-Path "$Path.bak" | Should -BeFalse
        }
    }

    It 'changes nothing with -Check or -WhatIf' {
        $path = Join-Path $TestDrive 'check.json'
        '{ "a": 1 }' | Set-Content $path
        InModuleScope DevEnv -Parameters @{ Path = $path } {
            param($Path)
            Update-JsonSettingsFile -Path $Path -Check -Update { param($s) $s['a'] = 2 } | Should -Be 'NeedsUpdate'
            Update-JsonSettingsFile -Path $Path -WhatIf -Update { param($s) $s['a'] = 2 } | Should -Be 'NeedsUpdate'
            (Get-Content $Path -Raw | ConvertFrom-Json).a | Should -Be 1
        }
    }

    It 'keeps a .bak copy of a file it changes' {
        $path = Join-Path $TestDrive 'backup.json'
        '{ "a": 1 }' | Set-Content $path
        InModuleScope DevEnv -Parameters @{ Path = $path } {
            param($Path)
            Update-JsonSettingsFile -Path $Path -Update { param($s) $s['a'] = 2 } | Should -Be 'Updated'
            (Get-Content "$Path.bak" -Raw | ConvertFrom-Json).a | Should -Be 1
            (Get-Content $Path -Raw | ConvertFrom-Json).a | Should -Be 2
        }
    }
}

Describe 'Terminal component' {
    BeforeEach {
        $path = Join-Path $TestDrive "terminal-$([guid]::NewGuid()).json"
        @'
{
    "profiles": { "defaults": { "opacity": 90 }, "list": [ { "name": "pwsh" } ] },
    "schemes": [ { "name": "Other", "background": "#111111" } ]
}
'@ | Set-Content $path
    }

    It 'adds the scheme and default font, keeping other settings, and is idempotent' {
        InModuleScope DevEnv -Parameters @{ Path = $path } {
            param($Path)
            $config = Get-DevEnvManifest
            (Sync-DevEnvTerminal -Config $config -SettingsPath $Path).Status | Should -Be 'Updated'
            $s = Get-Content $Path -Raw | ConvertFrom-Json
            $s.schemes.name | Should -Be @('Other', 'Custom')
            $s.profiles.defaults.colorScheme | Should -Be 'Custom'
            $s.profiles.defaults.font.face | Should -Be 'IosevkaTerm Nerd Font'
            $s.profiles.defaults.opacity | Should -Be 90
            $s.profiles.list.name | Should -Be 'pwsh'
            (Sync-DevEnvTerminal -Config $config -SettingsPath $Path).Status | Should -Be 'UpToDate'
        }
    }

    It 'removes only what still matches the manifest' {
        InModuleScope DevEnv -Parameters @{ Path = $path } {
            param($Path)
            $config = Get-DevEnvManifest
            Sync-DevEnvTerminal -Config $config -SettingsPath $Path | Out-Null
            $s = Get-Content $Path -Raw | ConvertFrom-Json -AsHashtable
            $s.profiles.defaults.font.face = 'My Own Font'
            $s | ConvertTo-Json -Depth 10 | Set-Content $Path

            (Remove-DevEnvTerminal -Config $config -SettingsPath $Path).Status | Should -Be 'Removed'
            $s = Get-Content $Path -Raw | ConvertFrom-Json
            $s.schemes.name | Should -Be 'Other'
            $s.profiles.defaults.PSObject.Properties.Name | Should -Not -Contain 'colorScheme'
            $s.profiles.defaults.font.face | Should -Be 'My Own Font'
        }
    }

    It 'handles profiles written as a plain list (older settings format)' {
        '{ "profiles": [ { "name": "cmd" } ] }' | Set-Content $path
        InModuleScope DevEnv -Parameters @{ Path = $path } {
            param($Path)
            Sync-DevEnvTerminal -Config (Get-DevEnvManifest) -SettingsPath $Path | Out-Null
            $s = Get-Content $Path -Raw | ConvertFrom-Json
            $s.profiles.list.name | Should -Be 'cmd'
            $s.profiles.defaults.colorScheme | Should -Be 'Custom'
        }
    }
}

Describe 'VS Code settings' {
    It 'merges the manifest settings and the font from Font.Face, keeping other settings' {
        $path = Join-Path $TestDrive 'vscode.json'
        '{ "my.own": true, "window.zoomLevel": 3 }' | Set-Content $path
        InModuleScope DevEnv -Parameters @{ Path = $path } {
            param($Path)
            $r = Sync-DevEnvVSCode -Config (Get-DevEnvManifest) -SettingsPath $Path -SkipExtensions
            $r.Status | Should -Be 'Updated'
            $s = Get-Content $Path -Raw | ConvertFrom-Json
            $s.'my.own' | Should -BeTrue
            $s.'window.zoomLevel' | Should -Be 1
            $s.'editor.fontFamily' | Should -Be "'IosevkaTerm Nerd Font'"
            $s.'terminal.integrated.fontFamily' | Should -Be 'IosevkaTerm Nerd Font'
        }
    }

    It 'removes only settings that still have the manifest values' {
        $path = Join-Path $TestDrive 'vscode-remove.json'
        InModuleScope DevEnv -Parameters @{ Path = $path } {
            param($Path)
            $config = Get-DevEnvManifest
            Sync-DevEnvVSCode -Config $config -SettingsPath $Path -SkipExtensions | Out-Null
            $s = Get-Content $Path -Raw | ConvertFrom-Json -AsHashtable
            $s['window.zoomLevel'] = 2
            $s | ConvertTo-Json | Set-Content $Path
            (Remove-DevEnvVSCode -Config $config -SettingsPath $Path -SkipExtensions).Status | Should -Be 'Removed'
            (Get-Content $Path -Raw | ConvertFrom-Json -AsHashtable).Keys | Should -Be @('window.zoomLevel')
        }
    }
}

Describe 'Prompt config' {
    It 'converts .NET time format <Format> to <Expected>' -ForEach @(
        @{ Format = 'HH:mm'; Expected = '%H:%M' }
        @{ Format = 'h:mm tt'; Expected = '%-I:%M %p' }
        @{ Format = 'H.m.s'; Expected = '%-H.%-M.%-S' }
        @{ Format = '100% hh'; Expected = '100%% %I' }
    ) {
        InModuleScope DevEnv -Parameters @{ Format = $Format } {
            param($Format)
            ConvertTo-StrftimeFormat $Format
        } | Should -BeExactly $Expected
    }

    It 'rejects <Problem>' -ForEach @(
        @{ Problem = 'an unknown segment'; Override = @{ Segments = @('os', 'bogus') }; Message = '*Unknown segment*bogus*' }
        @{ Problem = 'more segments than section colors'; Override = @{ Segments = @('os', 'path', 'git', 'docker', 'gap', 'time', 'gap') }; Message = '*needs section0 to section6*' }
        @{ Problem = 'a color that is not #RRGGBB'; Override = @{ Palette = @{ error = 'red' } }; Message = '*error*not a #RRGGBB*' }
        @{ Problem = 'a zero path length'; Override = @{ DirTruncationLength = 0 }; Message = '*DirTruncationLength*' }
    ) {
        InModuleScope DevEnv -Parameters @{ Override = $Override; Message = $Message } {
            param($Override, $Message)
            $prompt = Merge-Hashtable (Get-DevEnvManifest).Prompt $Override
            { Test-PromptConfig $prompt } | Should -Throw $Message
        }
    }

    It 'generates matching config for both shells, with LF line endings' {
        InModuleScope DevEnv {
            $files = Get-PromptConfigFile (Get-DevEnvManifest)
            $ps = $files[$script:PromptConfigPaths.PowerShell]
            $sh = $files[$script:PromptConfigPaths.Bash]
            $ps | Should -Match "Segments\s+= @\('os', 'path', 'git', 'docker', 'gap', 'time'\)"
            $sh | Should -Match '(?m)^_dl_segments=\(os path git docker gap time\)$'
            $sh | Should -Match "(?m)^_dl_time_format='%H:%M'$"
            $sh | Should -Not -Match "`r"
        }
    }

    It 'uses Segments in VS Code when VSCodeSegments is empty' {
        InModuleScope DevEnv {
            $config = Merge-Hashtable (Get-DevEnvManifest) @{ Prompt = @{ Segments = @('time', 'path'); VSCodeSegments = @() } }
            $sh = (Get-PromptConfigFile $config)[$script:PromptConfigPaths.Bash]
            $sh | Should -Match '(?m)^_dl_vscode_segments=\(time path\)$'
        }
    }

    It 'writes the files, then reports UpToDate, and removes them' {
        $dir = Join-Path $TestDrive 'prompt-config'
        New-Item -ItemType Directory $dir | Out-Null
        InModuleScope DevEnv -Parameters @{ Dir = $dir } {
            param($Dir)
            $saved = $script:PromptConfigPaths
            $script:PromptConfigPaths = @{ PowerShell = "$Dir\config.psd1"; Bash = "$Dir\config.sh" }
            try {
                $config = Get-DevEnvManifest
                (Sync-PromptConfig -Config $config -WhatIf).Status | Should -Be 'NeedsUpdate'
                Test-Path "$Dir\config.psd1" | Should -BeFalse
                (Sync-PromptConfig -Config $config).Status | Should -Be 'Updated'
                (Import-PowerShellDataFile "$Dir\config.psd1").Segments | Should -Be @('os', 'path', 'git', 'docker', 'gap', 'time')
                (Sync-PromptConfig -Config $config).Status | Should -Be 'UpToDate'
                (Remove-PromptConfig).Status | Should -Be 'Removed'
                Test-Path "$Dir\config.sh" | Should -BeFalse
            }
            finally { $script:PromptConfigPaths = $saved }
        }
    }
}

Describe 'Prompt profile' {
    It 'adds the block once, and removing it restores the profile exactly' {
        $path = Join-Path $TestDrive 'profile.ps1'
        [IO.File]::WriteAllText($path, "Set-Alias ll Get-ChildItem`r`n")
        $original = [IO.File]::ReadAllText($path)
        InModuleScope DevEnv -Parameters @{ Path = $path } {
            param($Path)
            (Sync-PromptProfile -ProfilePath $Path -Check).Status | Should -Be 'NeedsUpdate'
            (Sync-PromptProfile -ProfilePath $Path).Status | Should -Be 'Updated'
            (Sync-PromptProfile -ProfilePath $Path).Status | Should -Be 'UpToDate'
            (Remove-PromptProfile -ProfilePath $Path).Status | Should -Be 'Removed'
        }
        [IO.File]::ReadAllText($path) | Should -BeExactly $original
    }

    It 'leaves a line added by hand alone' {
        $path = Join-Path $TestDrive 'profile-by-hand.ps1'
        '. C:\code\dev-env-customization\powershell\dualline-prompt.ps1' | Set-Content $path
        InModuleScope DevEnv -Parameters @{ Path = $path } {
            param($Path)
            (Remove-PromptProfile -ProfilePath $Path).Status | Should -Be 'Skipped'
        }
    }
}

Describe 'Git component' {
    BeforeAll {
        $previousGitConfig = $env:GIT_CONFIG_GLOBAL
        $env:GIT_CONFIG_GLOBAL = Join-Path $TestDrive 'gitconfig'
        "[user]`n`tname = Someone Else" | Set-Content $env:GIT_CONFIG_GLOBAL
        $personal = Join-Path $TestDrive 'git-manifest.psd1'
        "@{ Git = @{ 'user.name' = 'Test User'; 'core.autocrlf' = `$true } }" | Set-Content $personal
    }
    AfterAll { $env:GIT_CONFIG_GLOBAL = $previousGitConfig }

    It 'sets the settings, writing booleans in lowercase, then reports UpToDate' {
        InModuleScope DevEnv -Parameters @{ Personal = $personal } {
            param($Personal)
            $config = Get-DevEnvManifest $Personal
            (Sync-DevEnvGit -Config $config -WhatIf).Status | Should -Be 'NeedsUpdate'
            git config --global --get user.name | Should -Be 'Someone Else'
            (Sync-DevEnvGit -Config $config).Status | Should -Be 'Updated'
            git config --global --get user.name | Should -Be 'Test User'
            git config --global --get core.autocrlf | Should -Be 'true'
            (Sync-DevEnvGit -Config $config).Status | Should -Be 'UpToDate'
        }
    }

    It 'unsets only settings that still have the manifest values' {
        InModuleScope DevEnv -Parameters @{ Personal = $personal } {
            param($Personal)
            $config = Get-DevEnvManifest $Personal
            Sync-DevEnvGit -Config $config | Out-Null
            git config --global init.defaultBranch develop
            (Remove-DevEnvGit -Config $config).Status | Should -Be 'Removed'
            git config --global --get user.name | Should -BeNullOrEmpty
            git config --global --get init.defaultBranch | Should -Be 'develop'
        }
    }
}

Describe 'Packages component' {
    BeforeAll {
        Mock -ModuleName DevEnv Get-Command { [pscustomobject]@{ Source = 'C:\fake\winget.exe' } } -ParameterFilter { $Name -eq 'winget' }
        Mock -ModuleName DevEnv Test-WingetPackage { $Id -eq 'Git.Git' }
        Mock -ModuleName DevEnv Sync-SessionPath { }
        Mock -ModuleName DevEnv Write-Progress { }
    }

    It 'installs only the missing packages' {
        Mock -ModuleName DevEnv Start-Process { [pscustomobject]@{ ExitCode = 0 } }
        InModuleScope DevEnv {
            $r = Sync-DevEnvPackages -Config @{ Packages = @('Git.Git', 'Some.App') } -InformationAction SilentlyContinue
            $r.Status | Should -Be 'Updated'
            $r.Detail | Should -Be 'Installed: Some.App'
        }
        Should -Invoke -ModuleName DevEnv Start-Process -Times 1 -Exactly -ParameterFilter { $ArgumentList -contains 'Some.App' }
    }

    It 'installs nothing with -WhatIf' {
        Mock -ModuleName DevEnv Start-Process { [pscustomobject]@{ ExitCode = 0 } }
        InModuleScope DevEnv {
            (Sync-DevEnvPackages -Config @{ Packages = @('Some.App') } -WhatIf -InformationAction SilentlyContinue).Status | Should -Be 'NeedsUpdate'
        }
        Should -Invoke -ModuleName DevEnv Start-Process -Times 0 -Exactly
    }

    It 'reports a failed install with its exit code, and what did install' {
        Mock -ModuleName DevEnv Start-Process { [pscustomobject]@{ ExitCode = $(if ($ArgumentList -contains 'Bad.App') { 5 } else { 0 }) } }
        InModuleScope DevEnv {
            $r = Sync-DevEnvPackages -Config @{ Packages = @('Bad.App', 'Good.App') } -InformationAction SilentlyContinue
            $r.Status | Should -Be 'Failed'
            $r.Detail | Should -Be 'Could not install: Bad.App (winget exit code 5); installed: Good.App'
        }
    }

    It 'leaves apps installed on uninstall' {
        InModuleScope DevEnv { (Remove-DevEnvPackages -Config @{}).Status | Should -Be 'Skipped' }
    }
}

Describe 'Module registration' {
    BeforeAll {
        $keyPath = "Software\DevEnvTests-$([guid]::NewGuid().ToString('N'))\Environment"
        $previousModulePath = $env:PSModulePath
    }
    AfterAll {
        [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree((Split-Path -Parent $keyPath), $false)
        $env:PSModulePath = $previousModulePath
    }

    It 'adds the repo once and removes it, deleting the value when empty' {
        InModuleScope DevEnv -Parameters @{ KeyPath = $keyPath } {
            param($KeyPath)
            (Sync-DevEnvModule -KeyPath $KeyPath -Check).Status | Should -Be 'NeedsUpdate'
            (Sync-DevEnvModule -KeyPath $KeyPath).Status | Should -Be 'Updated'
            Get-UserModulePath $KeyPath | Should -Be $script:RepoRoot
            (Sync-DevEnvModule -KeyPath $KeyPath).Status | Should -Be 'UpToDate'
            (Remove-DevEnvModule -KeyPath $KeyPath).Status | Should -Be 'Removed'
            Get-UserModulePath $KeyPath | Should -BeNullOrEmpty
        }
    }

    It 'keeps other entries, unexpanded, and the value type' {
        $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($keyPath)
        $key.SetValue('PSModulePath', '%USERPROFILE%\Modules', 'ExpandString'); $key.Dispose()
        InModuleScope DevEnv -Parameters @{ KeyPath = $keyPath } {
            param($KeyPath)
            Sync-DevEnvModule -KeyPath $KeyPath | Out-Null
            Get-UserModulePath $KeyPath | Should -Be "%USERPROFILE%\Modules;$script:RepoRoot"
            Remove-DevEnvModule -KeyPath $KeyPath | Out-Null
            Get-UserModulePath $KeyPath | Should -Be '%USERPROFILE%\Modules'
        }
        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($keyPath)
        $key.GetValueKind('PSModulePath') | Should -Be 'ExpandString'
        $key.Dispose()
    }
}

Describe 'Wsl component' -Skip:(-not (Test-Path 'C:\Program Files\Git\bin\bash.exe')) {
    # WSL is replaced by Git Bash, running the same scripts with HOME in a temporary folder
    BeforeAll {
        $wslHome = Join-Path $TestDrive 'wsl-home'
        New-Item -ItemType Directory $wslHome | Out-Null
        Mock -ModuleName DevEnv Get-WslDistro { 'Test' }
        Mock -ModuleName DevEnv ConvertTo-WslPath { & 'C:\Program Files\Git\usr\bin\cygpath.exe' -u $Path }
        Mock -ModuleName DevEnv Invoke-WslBash {
            $tmp = Join-Path $wslHome 'script.sh'
            [IO.File]::WriteAllText($tmp, ($Script -replace "`r`n", "`n"))
            $previousHome = $env:HOME
            $env:HOME = & 'C:\Program Files\Git\usr\bin\cygpath.exe' -u $wslHome
            try { & 'C:\Program Files\Git\bin\bash.exe' --noprofile --norc $tmp | Out-Null; $LASTEXITCODE }
            finally { $env:HOME = $previousHome }
        }
    }

    It 'quotes strings for bash' {
        InModuleScope DevEnv { ConvertTo-BashLiteral "it's" } | Should -BeExactly "'it'\''s'"
    }

    It 'adds the source line once, and removing it restores ~/.bashrc exactly' {
        $rc = Join-Path $wslHome '.bashrc'
        [IO.File]::WriteAllText($rc, "alias ll='ls -l'`n`nexport FOO=1`n")
        $original = [IO.File]::ReadAllText($rc)
        InModuleScope DevEnv {
            (Sync-DevEnvWsl -Config @{ Wsl = @{} } -WhatIf).Status | Should -Be 'NeedsUpdate'
            (Sync-DevEnvWsl -Config @{ Wsl = @{} }).Status | Should -Be 'Updated'
            (Sync-DevEnvWsl -Config @{ Wsl = @{} }).Status | Should -Be 'UpToDate'
        }
        [IO.File]::ReadAllText($rc) | Should -Match 'source .*/bash/dualline-prompt\.sh'
        InModuleScope DevEnv { (Remove-DevEnvWsl -Config @{ Wsl = @{} }).Status | Should -Be 'Removed' }
        [IO.File]::ReadAllText($rc) | Should -BeExactly $original
        InModuleScope DevEnv { (Remove-DevEnvWsl -Config @{ Wsl = @{} }).Status | Should -Be 'NotInstalled' }
    }
}

Describe 'Running components' {
    It 'reports a component that throws as Failed and still runs the others' {
        Mock -ModuleName DevEnv Sync-DevEnvFont { throw 'font broke' }
        # Mocks run outside the module, so this builds the result itself
        Mock -ModuleName DevEnv Sync-DevEnvGit { [pscustomobject]@{ Component = 'Git'; Status = 'UpToDate'; Detail = 'fine' } }
        InModuleScope DevEnv {
            $r = Invoke-DevEnvComponent -Verb Sync -Component Font, Git
            $r.Component | Should -Be @('Font', 'Git')
            $r[0].Status | Should -Be 'Failed'
            $r[0].Detail | Should -Be 'font broke'
            $r[1].Status | Should -Be 'UpToDate'
        }
    }
}
